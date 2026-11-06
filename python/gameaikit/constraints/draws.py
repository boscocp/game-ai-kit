"""The seeded draws of `ai_constraints/constraint_draws.gd`, in Python.

The numbers come from `gameaikit.core.Xorshift`, the kernel's Marsaglia
xorshift, as the GDScript's come from `GakXorshift`. T95 had copied the
generator here before T109 moved it to the kernel; T135 folded the copy in.
A number and a choice among `count` are the kernel's, passed through; only
the Fisher-Yates shuffle is this addon's own. Seeded with 1, the first draw is 270369.

`ConstraintSolver` draws only to shuffle: once, before it searches, the
variables and then each domain, so that a tie between equal choices goes the
way the seed says and the same seed gives the same answer in both languages.
`WaveCollapse` (T96) also draws during the search, once for each cell it
collapses, from a second generator with the same seed.
"""

from __future__ import annotations

from gameaikit.core.xorshift import SEED_FOR_ZERO, Xorshift

__all__ = ["SEED_FOR_ZERO", "ConstraintDraws"]


class ConstraintDraws:
    """Seeded draws that `constraint_draws.gd` repeats draw for draw."""

    def __init__(self, from_seed: int = SEED_FOR_ZERO) -> None:
        self._numbers = Xorshift(from_seed)

    def next(self) -> int:
        """The next number, between 1 and 2^32 - 1, from the kernel's generator."""
        return self._numbers.next()

    def index(self, count: int) -> int:
        """One of `count` choices, by the kernel's rule: no draw for only one."""
        return self._numbers.index(count)

    def shuffle(self, items: list) -> list:
        """A copy of `items` in Fisher and Yates's order: from the last place
        down to the second, each swapped with one drawn from it and before it."""
        shuffled = list(items)
        for place in range(len(shuffled) - 1, 0, -1):
            other = self.index(place + 1)
            shuffled[place], shuffled[other] = shuffled[other], shuffled[place]
        return shuffled
