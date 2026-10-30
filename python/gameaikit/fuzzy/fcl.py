"""Read a controller written as text a designer can edit.

The format is the one the original library's `FLC.txt` used (see ADR 0011),
with two additions. A whole file looks like this:

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
file from a standard FCL tool is refused, with the line it stopped on.

The original reader skipped a condition naming a set it could not find and
kept the rule, so a misspelling quietly made a rule *broader*. Here every
error is a `FuzzyError`: a mistake on a line names the line, and a missing
piece -- a variable with no block, a file with no rules -- names what is
missing. Every refusal has its own sentence, so a test can tell them apart.
"""

from __future__ import annotations

import re

from .membership import FuzzyError, FuzzySet, Variable
from .rules import Rule, RuleBase
from gameaikit.techniques import technique

#: The keyword that opens each kind of block.
BLOCKS = ("VAR_INPUT", "VAR_OUTPUT", "FUZZIFY", "DEFUZZIFY", "RULEBLOCK")

#: Words with a meaning inside a block, which a set may therefore not be named.
RESERVED = ("RANGE", "SAMPLES")

#: A name: a variable or a set. One word, so a rule can be split on spaces.
NAME_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")

#: A number as a designer writes one. Deliberately narrower than `float()`,
#: which would also read `nan`, `inf` and `1_0`.
NUMBER_RE = re.compile(r"^-?\d+(?:\.\d+)?$")

RULE_LABEL_RE = re.compile(r"^RULE\s+\d+$", re.IGNORECASE)


@technique("fuzzy-control", "a fuzzy controller read from IEC 61131-7's FCL: memberships, rules, a centroid")
def read_fcl(text: str) -> RuleBase:
    """The controller this text describes, or a `FuzzyError` naming the line."""
    found = {"VAR_INPUT": [], "VAR_OUTPUT": [], "shapes": {}, "rules": []}
    block, subject = "", ""
    for number, raw in enumerate(text.splitlines(), start=1):
        words = raw.split()
        if not words:
            continue
        if block == "":
            block, subject = _open_block(number, words, found)
        elif words[0].upper() == "END":
            _refuse_extra(number, words, 1)
            block, subject = "", ""
        elif block in ("VAR_INPUT", "VAR_OUTPUT"):
            _declare(number, words, found)
            found[block].append(words[0])
        elif block == "RULEBLOCK":
            found["rules"].append((number, _rule(number, raw.strip())))
        else:
            _shape_line(number, raw.strip(), found["shapes"][subject], block == "DEFUZZIFY")
    if block != "":
        raise FuzzyError(f"F9 the file ends inside {block} with no END")
    return _assemble(found)


def _refuse_extra(number: int, words: list[str], allowed: int) -> None:
    if len(words) != allowed:
        raise FuzzyError(f"F9 line {number}: unexpected words after "
                         f"{' '.join(words[:allowed])!r}: {' '.join(words[allowed:])!r}")


def _name(number: int, word: str, what: str) -> str:
    if not NAME_RE.match(word):
        raise FuzzyError(f"F9 line {number}: {word!r} is not a usable {what} name")
    return word


def _declare(number: int, words: list[str], found: dict) -> None:
    _refuse_extra(number, words, 1)
    name = _name(number, words[0], "variable")
    if name in found["VAR_INPUT"] or name in found["VAR_OUTPUT"]:
        raise FuzzyError(f"F4 line {number}: {name} is declared twice")


def _open_block(number: int, words: list[str], found: dict) -> tuple[str, str]:
    keyword = words[0].upper()
    if keyword not in BLOCKS:
        raise FuzzyError(f"F9 line {number}: expected a block, found {words[0]!r}")
    if keyword not in ("FUZZIFY", "DEFUZZIFY"):
        _refuse_extra(number, words, 1)
        return keyword, ""
    _refuse_extra(number, words, 2)
    names = found["VAR_INPUT" if keyword == "FUZZIFY" else "VAR_OUTPUT"]
    subject = words[1]
    if subject not in names:
        raise FuzzyError(f"F9 line {number}: {keyword} {subject} names no declared "
                         f"{'input' if keyword == 'FUZZIFY' else 'output'}")
    if subject in found["shapes"]:
        raise FuzzyError(f"F9 line {number}: {subject} already has a block")
    found["shapes"][subject] = {"sets": [], "range": None, "samples": None}
    return keyword, subject


def _numbers(number: int, text: str) -> list[float]:
    pieces = [piece.strip() for piece in text.split(",")]
    if not all(NUMBER_RE.match(piece) for piece in pieces):
        raise FuzzyError(f"F9 line {number}: {text.strip()!r} is not a list of numbers")
    return [float(piece) for piece in pieces]


def _shape_line(number: int, line: str, shape: dict, is_output: bool) -> None:
    name, equals, value = (piece.strip() for piece in line.partition("="))
    if not equals:
        raise FuzzyError(f"F9 line {number}: expected `name = numbers`")
    keyword = name.upper()
    if keyword in RESERVED and shape[keyword.lower()] is not None:
        raise FuzzyError(f"F9 line {number}: {keyword} is given twice")
    if keyword == "RANGE":
        shape["range"] = _numbers(number, value)
    elif keyword == "SAMPLES":
        if not is_output or not value.isdigit():
            raise FuzzyError(f"F9 line {number}: SAMPLES is one whole number, "
                             "and only an output has it")
        shape["samples"] = int(value)
    else:
        try:
            shape["sets"].append(FuzzySet.from_points(_name(number, name, "set"),
                                                      _numbers(number, value)))
        except FuzzyError as refused:
            raise FuzzyError(f"{refused} (line {number})") from None


def _rule(number: int, line: str) -> Rule:
    """`RULE n = IF a IS b (AND|OR c IS d)* THEN e IS f`, refused otherwise."""
    label, _, body = line.partition("=")
    if not RULE_LABEL_RE.match(label.strip()):
        raise FuzzyError(f"F9 line {number}: a rule line starts `RULE <number> =`")
    words = body.split()
    if len(words) < 8 or words[0].upper() != "IF" or words[-4].upper() != "THEN":
        raise FuzzyError(f"F9 line {number}: a rule reads IF ... THEN var IS set")
    if words[-2].upper() != "IS":
        raise FuzzyError(f"F9 line {number}: the conclusion reads `THEN var IS set`")
    clauses = words[1:-4]
    joins = {word.upper() for word in clauses[3::4]}
    triples = [clauses[index:index + 3] for index in range(0, len(clauses), 4)]
    if len(clauses) % 4 != 3 or not all(triple[1].upper() == "IS" for triple in triples):
        raise FuzzyError(f"F9 line {number}: a condition reads `var IS set`")
    if not joins <= {"AND", "OR"}:
        raise FuzzyError(f"F9 line {number}: conditions are joined by AND or OR")
    if len(joins) > 1:
        raise FuzzyError(f"F6 line {number}: one rule mixes AND and OR; write two rules")
    connective = joins.pop().lower() if joins else "and"
    conditions = tuple((triple[0], triple[2]) for triple in triples)
    return Rule(conditions, (words[-3], words[-1]), connective)


def _variable(name: str, shape: dict | None) -> Variable:
    if shape is None or shape["range"] is None or len(shape["range"]) != 2:
        raise FuzzyError(f"F2 variable {name!r} has no block, or no RANGE = low,high")
    low, high = shape["range"]
    return Variable(name, low, high, tuple(shape["sets"]), shape["samples"] or 0)


def _check_names(number: int, rule: Rule, sets_of: dict[str, set[str]],
                 found: dict) -> None:
    """Name the line of a rule testing a set that does not exist."""
    for variable, term in rule.conditions:
        if variable not in found["VAR_INPUT"] or term not in sets_of.get(variable, ()):
            raise FuzzyError(f"F7 line {number}: {variable} IS {term} is no input's set")
    variable, term = rule.conclusion
    if variable not in found["VAR_OUTPUT"] or term not in sets_of.get(variable, ()):
        raise FuzzyError(f"F7 line {number}: {variable} IS {term} is no output's set")


def _assemble(found: dict) -> RuleBase:
    inputs = tuple(_variable(name, found["shapes"].get(name)) for name in found["VAR_INPUT"])
    outputs = tuple(_variable(name, found["shapes"].get(name)) for name in found["VAR_OUTPUT"])
    sets_of = {one.name: {each.name for each in one.sets} for one in inputs + outputs}
    for number, rule in found["rules"]:
        _check_names(number, rule, sets_of, found)
    return RuleBase(inputs, outputs, tuple(rule for _, rule in found["rules"]))
