"""IF distance IS near AND light IS bright THEN alertness IS alarmed.

A rule base is a handful of sentences like that one, and evaluating it takes
three steps, each in its own file:

1. **fuzzify** -- every input becomes a degree per set (`membership.py`);
2. **infer** -- every rule gets a strength: `AND` is the smallest degree of its
   conditions, `OR` the largest; and every output term takes the strongest
   rule that concludes it (this file);
3. **defuzzify** -- the terms become one number again (`defuzzify.py`).

Cost is one pass over the rules per evaluation: rules x conditions.

When not to use it: when there are more than a dozen rules, or when the inputs
are discrete. A controller with twenty overlapping rules is a system nobody
can predict -- every change moves every output a little -- and a decision tree
says the same thing about discrete inputs in a form a person can follow.
"""

from __future__ import annotations

import dataclasses

from .defuzzify import centroid
from .membership import FuzzyError, Variable

#: How a rule joins its conditions. One connective per rule: mixing them
#: without brackets has no agreed meaning, and two rules say it plainly.
CONNECTIVES = ("and", "or")


@dataclasses.dataclass(frozen=True)
class Rule:
    """One IF ... THEN ... sentence, as names rather than objects.

    Names, so a rule reads in the file the way it reads aloud, and so the
    rule base can say which name it could not find.
    """

    conditions: tuple[tuple[str, str], ...]
    conclusion: tuple[str, str]
    connective: str = "and"

    def strength(self, degrees: dict[str, dict[str, float]]) -> float:
        """How true the IF half is, given every input's degrees.

        `min` for AND and `max` for OR are Zadeh's, and the oldest choice.
        Others exist -- a product for AND is smoother -- and none is more
        right; this one is the one every textbook starts with.
        """
        truths = [degrees[variable][term] for variable, term in self.conditions]
        return min(truths) if self.connective == "and" else max(truths)


@dataclasses.dataclass(frozen=True)
class RuleBase:
    """Inputs, outputs and the rules between them: a complete controller."""

    inputs: tuple[Variable, ...]
    outputs: tuple[Variable, ...]
    rules: tuple[Rule, ...]

    def __post_init__(self) -> None:
        self.check()

    def check(self) -> None:
        """Refuse a controller before it is evaluated, rather than during.

        Every refusal here is one a rule base would otherwise answer with a
        `KeyError` from somewhere inside `strength`, or worse, with a number.
        """
        for variable in self.inputs:
            variable.check(is_output=False)
        for variable in self.outputs:
            variable.check(is_output=True)
        names = [variable.name for variable in self.inputs + self.outputs]
        if len(set(names)) != len(names):
            raise FuzzyError("F4 two variables share a name")
        if not self.rules:
            raise FuzzyError("F5 a controller with no rules concludes nothing")
        for number, rule in enumerate(self.rules, start=1):
            self._check_rule(number, rule)

    def _check_rule(self, number: int, rule: Rule) -> None:
        if rule.connective not in CONNECTIVES:
            raise FuzzyError(f"F6 rule {number} joins with {rule.connective!r}")
        if not rule.conditions:
            raise FuzzyError(f"F6 rule {number} has no conditions")
        for variable, term in rule.conditions:
            if not _names_a_set(self.inputs, variable, term):
                raise FuzzyError(f"F7 rule {number} tests {variable} IS {term}, "
                                 "which is no input's set")
        if not _names_a_set(self.outputs, *rule.conclusion):
            raise FuzzyError(f"F7 rule {number} concludes {' IS '.join(rule.conclusion)}, "
                             "which is no output's set")

    def fuzzify(self, values: dict[str, float]) -> dict[str, dict[str, float]]:
        """Every input's degrees. An input with no value is refused, not zeroed."""
        missing = [variable.name for variable in self.inputs if variable.name not in values]
        if missing:
            raise FuzzyError(f"F8 no value for {', '.join(missing)}")
        return {variable.name: variable.fuzzify(values[variable.name])
                for variable in self.inputs}

    def activations(self, values: dict[str, float]) -> dict[str, dict[str, float]]:
        """How strongly each output term is concluded: the *why* of a decision.

        Every term of every output appears, at 0 when nothing concluded it, so
        a picture drawn from this shows the terms that did not fire as well.
        """
        degrees = self.fuzzify(values)
        strengths = {output.name: {one.name: 0.0 for one in output.sets}
                     for output in self.outputs}
        for rule in self.rules:
            variable, term = rule.conclusion
            strengths[variable][term] = max(strengths[variable][term], rule.strength(degrees))
        return strengths

    def evaluate(self, values: dict[str, float]) -> dict[str, float]:
        """One crisp number per output, or NaN for an output no rule reached."""
        strengths = self.activations(values)
        return {output.name: centroid(output, strengths[output.name])
                for output in self.outputs}


def _names_a_set(variables: tuple[Variable, ...], variable: str, term: str) -> bool:
    found = next((one for one in variables if one.name == variable), None)
    return found is not None and found.set_named(term) is not None
