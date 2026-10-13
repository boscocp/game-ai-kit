"""Fuzzy logic: membership functions, a rule base, and defuzzification.

The tier-1 half of `ai_fuzzy`, standard library only. The GDScript addon is
the same three pieces and nothing more; `spec/vectors/fuzzy/` holds the two
to the same numbers.

    from gameaikit.fuzzy import read_fcl
    guard = read_fcl(open("spec/vectors/fuzzy/the-guard.fcl").read())
    guard.evaluate({"distance": 5.0, "light": 0.8})   # {"alertness": ...}

Read `membership.py`, then `rules.py`, then `defuzzify.py`: that is the order
an evaluation runs in. `python -m gameaikit.fuzzy.plot` draws one controller's
curve in the terminal.
"""

from .defuzzify import centroid
from .fcl import read_fcl
from .loading import from_dictionary
from .membership import FuzzyError, FuzzySet, Variable
from .rules import Rule, RuleBase

__all__ = [
    "FuzzyError",
    "FuzzySet",
    "Rule",
    "RuleBase",
    "Variable",
    "centroid",
    "from_dictionary",
    "read_fcl",
]
