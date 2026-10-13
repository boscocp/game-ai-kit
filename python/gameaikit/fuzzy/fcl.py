"""Read a controller written as text a designer can edit.

This is the one part of the original library that existed as working code
(`FuzzyReader.cs`, see ADR 0011), and the format is its format with two
additions. A whole file looks like this:

    VAR_INPUT
        distance
    END
    VAR_OUTPUT
        alertness
    END
    FUZZIFY distance
        RANGE = 0,20
        near = 0,0,3,7
    END
    DEFUZZIFY alertness
        RANGE = 0,100
        SAMPLES = 101
        calm = 0,0,10,40
    END
    RULEBLOCK
        RULE 1 = IF distance IS near THEN alertness IS calm
    END

`RANGE` and `SAMPLES` are the two additions: the original had nowhere to say
what to clamp an input into, or where to measure an output.

It is modelled on IEC 61131-7's Fuzzy Control Language and is not that
language: the standard writes a set as `TERM near := (0,0) (3,1) (7,0);`. A
file from a standard FCL tool will be refused, with the line it stopped on.

The original reader printed a message for a name it could not find and
carried on, which hands back a controller missing a rule and evaluating
perfectly. This one refuses: every error is a `FuzzyError` with a line number.
"""

from __future__ import annotations

from .membership import FuzzyError, FuzzySet, Variable
from .rules import Rule, RuleBase

#: The keyword that opens each kind of block.
BLOCKS = ("VAR_INPUT", "VAR_OUTPUT", "FUZZIFY", "DEFUZZIFY", "RULEBLOCK")


def read_fcl(text: str) -> RuleBase:
    """The controller this text describes, or a `FuzzyError` naming the line."""
    declared: dict[str, list[str]] = {"VAR_INPUT": [], "VAR_OUTPUT": []}
    shapes: dict[str, dict] = {}
    rules: list[Rule] = []
    block, subject = "", ""
    for number, raw in enumerate(text.splitlines(), start=1):
        line = raw.strip()
        if not line:
            continue
        words = line.split()
        keyword = words[0].upper()
        if block == "":
            block, subject = _open_block(number, keyword, words, declared, shapes)
        elif keyword == "END":
            block, subject = "", ""
        elif block in declared:
            declared[block].append(_one_name(number, words))
        elif block == "RULEBLOCK":
            rules.append(_rule(number, line))
        else:
            _shape_line(number, line, shapes[subject], block == "DEFUZZIFY")
    if block != "":
        raise FuzzyError(f"F9 the file ends inside {block} with no END")
    return _assemble(declared, shapes, rules)


def _open_block(number: int, keyword: str, words: list[str],
                declared: dict[str, list[str]], shapes: dict[str, dict]) -> tuple[str, str]:
    if keyword not in BLOCKS:
        raise FuzzyError(f"F9 line {number}: expected a block, found {words[0]!r}")
    if keyword not in ("FUZZIFY", "DEFUZZIFY"):
        return keyword, ""
    names = declared["VAR_INPUT" if keyword == "FUZZIFY" else "VAR_OUTPUT"]
    subject = _one_name(number, words[1:])
    if subject not in names or subject in shapes:
        raise FuzzyError(f"F9 line {number}: {keyword} {subject} is undeclared or repeated")
    shapes[subject] = {"sets": [], "range": None, "samples": 0}
    return keyword, subject


def _one_name(number: int, words: list[str]) -> str:
    if len(words) != 1:
        raise FuzzyError(f"F9 line {number}: expected one name, found {' '.join(words)!r}")
    return words[0]


def _numbers(number: int, text: str) -> list[float]:
    try:
        return [float(piece) for piece in text.split(",")]
    except ValueError:
        raise FuzzyError(f"F9 line {number}: {text.strip()!r} is not a list of numbers") \
            from None


def _shape_line(number: int, line: str, shape: dict, is_output: bool) -> None:
    name, equals, value = (piece.strip() for piece in line.partition("="))
    if not equals:
        raise FuzzyError(f"F9 line {number}: expected `name = numbers`")
    if name.upper() == "RANGE":
        shape["range"] = _numbers(number, value)
    elif name.upper() == "SAMPLES" and is_output:
        shape["samples"] = int(_numbers(number, value)[0])
    else:
        shape["sets"].append(FuzzySet.from_points(name, _numbers(number, value)))


def _rule(number: int, line: str) -> Rule:
    """`RULE n = IF a IS b (AND|OR c IS d)* THEN e IS f`, refused otherwise."""
    words = line.partition("=")[2].split()
    if len(words) < 8 or words[0].upper() != "IF" or words[-4].upper() != "THEN":
        raise FuzzyError(f"F9 line {number}: a rule reads IF ... THEN var IS set")
    clauses = words[1:-4]
    joins = {word.upper() for word in clauses[3::4]}
    triples = [clauses[index:index + 3] for index in range(0, len(clauses), 4)]
    well_formed = len(clauses) % 4 == 3 and all(triple[1].upper() == "IS" for triple in triples)
    if not well_formed or not joins <= {"AND", "OR"} or words[-2].upper() != "IS":
        raise FuzzyError(f"F9 line {number}: a condition reads `var IS set`, "
                         "joined by AND or OR")
    if len(joins) > 1:
        raise FuzzyError(f"F6 line {number}: one rule mixes AND and OR; write two rules")
    connective = joins.pop().lower() if joins else "and"
    conditions = tuple((triple[0], triple[2]) for triple in triples)
    return Rule(conditions, (words[-3], words[-1]), connective)


def _variable(name: str, shape: dict | None, is_output: bool) -> Variable:
    if shape is None or shape["range"] is None or len(shape["range"]) != 2:
        raise FuzzyError(f"F2 variable {name!r} has no block, or no RANGE = low,high")
    low, high = shape["range"]
    return Variable(name, low, high, tuple(shape["sets"]), shape["samples"])


def _assemble(declared: dict[str, list[str]], shapes: dict[str, dict],
              rules: list[Rule]) -> RuleBase:
    return RuleBase(
        tuple(_variable(name, shapes.get(name), False) for name in declared["VAR_INPUT"]),
        tuple(_variable(name, shapes.get(name), True) for name in declared["VAR_OUTPUT"]),
        tuple(rules),
    )
