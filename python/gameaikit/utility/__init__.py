"""Utility choice: every option weighed by a score, and the highest taken.

The tier-1 half of `ai_utility`, standard library only. Each choice is a
function of numbers a game has already measured, so it can be run, and
checked, without an engine. `spec/vectors/utility/` holds this and the
GDScript addon to the same answers.

    action.py     what to do now: every action scored by its considerations
    errands.py    back for rounds, out for a power weapon, or into hiding, each a gain less its costs

Until T101 both lived in the teamwork package, though nothing in them is
about a team.
"""

from . import action, errands

__all__ = ["action", "errands"]
