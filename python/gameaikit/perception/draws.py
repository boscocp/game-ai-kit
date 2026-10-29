"""Marsaglia's 32-bit xorshift, as `ai_perception/particle_draws.gd` writes it.

The same dozen lines as T86's generator for Monte Carlo search, copied
rather than imported: the GDScript twin may import no other addon
(invariant 2), and this side keeps the same shape. Seeded with 1, the first draw is 270369.
"""

from __future__ import annotations

#: Every value is kept to 32 bits, as Marsaglia's generator is defined.
MASK = 0xFFFFFFFF
#: A state of zero would stay zero forever, so a seed of zero starts here.
SEED_FOR_ZERO = 1
#: One more than the largest draw: `uniform` divides by it.
SPAN = 4294967296.0


class ParticleDraws:
    """A seeded generator that `particle_draws.gd` repeats draw for draw."""

    def __init__(self, from_seed: int = SEED_FOR_ZERO) -> None:
        self._state = from_seed & MASK
        if self._state == 0:
            self._state = SEED_FOR_ZERO

    def next(self) -> int:
        """The next number, between 1 and 2^32 - 1."""
        self._state ^= (self._state << 13) & MASK
        self._state ^= self._state >> 17
        self._state ^= (self._state << 5) & MASK
        return self._state

    def index(self, count: int) -> int:
        """One of `count` choices; no draw is spent when there is only one."""
        if count <= 1:
            return 0
        return self.next() % count

    def uniform(self) -> float:
        """A number in (0, 1)."""
        return self.next() / SPAN
