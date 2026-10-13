"""A controller from the JSON shape the conformance vectors use.

The same shape is read by `FuzzyVector` on the GDScript side, and it is
documented once, in `spec/vectors/fuzzy/README.md`. Kept apart from the
evaluation so that `rules.py` reads as the algorithm and nothing else.

Every refusal about the *shape* is `F0`, and only Python has it: the GDScript
reader answers the same mistakes with its own `V3`. Once the shape is right,
the controller's own checks run, and their codes (`F1`-`F8`) are shared.
"""

from __future__ import annotations

from .membership import FuzzyError, FuzzySet, Variable
from .rules import Rule, RuleBase


def _number(value: object, what: str) -> float:
    """A JSON number, refused when it is a string, a boolean or missing."""
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise FuzzyError(f"F0 {what} is {value!r}, not a number")
    return float(value)


def _whole_number(value: object, what: str) -> int:
    """A JSON number with nothing after the point; 11.0 is 11, 11.7 is refused."""
    number = _number(value, what)
    if not number.is_integer():
        raise FuzzyError(f"F0 {what} is {value!r}, not a whole number")
    return int(number)


def _names(value: object, what: str) -> tuple[str, str]:
    """A `[variable, set]` pair."""
    if not isinstance(value, list) or len(value) != 2 \
            or not all(isinstance(name, str) for name in value):
        raise FuzzyError(f"F0 {what} is {value!r}, not [variable, set]")
    return value[0], value[1]


def variable_from_dict(data: object, is_output: bool) -> Variable:
    """One variable: its name, range, sets and, for an output, its samples."""
    if not isinstance(data, dict) or not isinstance(data.get("name"), str) \
            or not isinstance(data.get("sets"), dict):
        raise FuzzyError(f"F0 a variable needs a name and sets: {data!r}")
    name = data["name"]
    sets = []
    for set_name, points in data["sets"].items():
        if not isinstance(points, list):
            raise FuzzyError(f"F0 set {set_name!r} of {name} is not a list of points")
        numbers = [_number(point, f"a point of {set_name!r}") for point in points]
        sets.append(FuzzySet.from_points(set_name, numbers))
    samples = _whole_number(data.get("samples"), f"{name}'s samples") if is_output else 0
    return Variable(name, _number(data.get("minimum"), f"{name}'s minimum"),
                    _number(data.get("maximum"), f"{name}'s maximum"), tuple(sets), samples)


def rule_from_dict(data: object) -> Rule:
    """One rule, written as `{"if": [[var, set], ...], "then": [var, set]}`."""
    if not isinstance(data, dict) or not isinstance(data.get("if"), list):
        raise FuzzyError(f"F0 a rule needs `if` and `then`: {data!r}")
    conditions = tuple(_names(condition, "a condition") for condition in data["if"])
    connective = data.get("connective", "and")
    if not isinstance(connective, str):
        raise FuzzyError(f"F0 a connective is {connective!r}, not a word")
    return Rule(conditions, _names(data.get("then"), "a conclusion"), connective)


def from_dictionary(data: object) -> RuleBase:
    """The whole controller, checked before it is handed back."""
    if not isinstance(data, dict) or not all(
            isinstance(data.get(part), list) for part in ("inputs", "outputs", "rules")):
        raise FuzzyError("F0 a controller is lists of inputs, outputs and rules")
    return RuleBase(
        tuple(variable_from_dict(entry, is_output=False) for entry in data["inputs"]),
        tuple(variable_from_dict(entry, is_output=True) for entry in data["outputs"]),
        tuple(rule_from_dict(entry) for entry in data["rules"]),
    )
