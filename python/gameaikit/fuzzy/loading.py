"""A controller from the JSON shape the conformance vectors use.

The same shape is read by `FuzzyVector` on the GDScript side, and it is
documented once, in `spec/vectors/fuzzy/README.md`. Kept apart from the
evaluation so that `rules.py` reads as the algorithm and nothing else.
"""

from __future__ import annotations

from .membership import FuzzyError, FuzzySet, Variable
from .rules import Rule, RuleBase


def variable_from_dict(data: dict, is_output: bool) -> Variable:
    """One variable: its name, range, sets and, for an output, its samples."""
    try:
        sets = tuple(FuzzySet.from_points(name, list(points))
                     for name, points in data["sets"].items())
        return Variable(data["name"], float(data["minimum"]), float(data["maximum"]),
                        sets, int(data["samples"]) if is_output else 0)
    except (KeyError, TypeError, AttributeError) as missing:
        raise FuzzyError(f"F2 a variable is missing a field: {missing}") from missing


def rule_from_dict(data: dict) -> Rule:
    """One rule, written as `{"if": [[var, set], ...], "then": [var, set]}`."""
    try:
        conditions = tuple((variable, term) for variable, term in data["if"])
        variable, term = data["then"]
    except (KeyError, TypeError, ValueError) as missing:
        raise FuzzyError(f"F6 a rule is not IF ... THEN ...: {missing}") from missing
    return Rule(conditions, (variable, term), data.get("connective", "and"))


def from_dictionary(data: dict) -> RuleBase:
    """The whole controller, checked before it is handed back."""
    try:
        inputs, outputs, rules = data["inputs"], data["outputs"], data["rules"]
    except (KeyError, TypeError) as missing:
        raise FuzzyError(f"F5 a controller needs inputs, outputs and rules: {missing}") \
            from missing
    return RuleBase(
        tuple(variable_from_dict(entry, is_output=False) for entry in inputs),
        tuple(variable_from_dict(entry, is_output=True) for entry in outputs),
        tuple(rule_from_dict(entry) for entry in rules),
    )
