"""The smallest board a fixed policy can play a game on.

This is **not** `BoardState` from `ai_core`, and the difference is deliberate
rather than an oversight. That type is the game; this is the world the training
data comes from, it lives in Python because invariant 6 says training does, and
it holds only what the features in `rows.py` need: terrain, units, and a node
worth taking.

The risk in having two of them is that they drift, so be exact about what has
to agree. **Nothing here has to match `BoardState`** -- the dataset is a
population of situations, not a replay of the game. What must agree across the
two languages is the *arithmetic of the model*, and T6 pins that with a
conformance vector rather than with a shared board.

When not to use it: anything the player sees. It has no rendering, no turn
order worth watching and no rules a person would enjoy losing to.
"""

from __future__ import annotations

import dataclasses

#: Terrain costs the simulator draws from. One is open ground; three is the
#: sort of cover a defender wants to be standing in.
CHEAPEST_GROUND = 1
DEAREST_GROUND = 3

#: The four cardinal directions, in a fixed order, so a policy that breaks ties
#: by the order it looks in behaves the same on every run.
DIRECTIONS = ((0, -1), (1, 0), (0, 1), (-1, 0))


@dataclasses.dataclass
class Unit:
    """One piece: whose it is, where it stands, and what it has left."""

    unit_id: int
    faction: int
    x: int
    y: int
    health: int

    #: Which of `combat.WALKERS` it is, or None for an untyped unit. Since
    #: T44, so a fight can be tilted by the counter table as the tactical
    #: board's fights are.
    kind: str | None = None

    def is_alive(self) -> bool:
        """True while this unit is still on the board."""
        return self.health > 0

    def cell(self) -> tuple[int, int]:
        """Where it stands, as the pair everything else passes around."""
        return (self.x, self.y)


class Board:
    """Terrain, the units on it, and the one cell both sides want."""

    def __init__(self, width: int, height: int, costs: list[list[int]],
                 units: list[Unit], node: tuple[int, int]) -> None:
        self.width = width
        self.height = height
        self.costs = costs
        self.units = units
        self.node = node

    def contains(self, cell: tuple[int, int]) -> bool:
        """True when the cell is on the board at all."""
        x, y = cell
        return 0 <= x < self.width and 0 <= y < self.height

    def cost_at(self, cell: tuple[int, int]) -> int:
        """What it costs to stand on this cell, and how much cover it gives.

        Off the board answers with the dearest ground rather than raising: a
        policy looks over the edge constantly and an exception there would be
        noise rather than information.
        """
        if not self.contains(cell):
            return DEAREST_GROUND
        x, y = cell
        return self.costs[y][x]

    def unit_at(self, cell: tuple[int, int]) -> Unit | None:
        """The living unit standing on this cell, or None."""
        for unit in self.units:
            if unit.is_alive() and unit.cell() == cell:
                return unit
        return None

    def living(self, faction: int) -> list[Unit]:
        """Every unit of a faction that is still alive."""
        return [unit for unit in self.units
            if unit.is_alive() and unit.faction == faction]

    def neighbours(self, cell: tuple[int, int]) -> list[tuple[int, int]]:
        """The cells one cardinal step away that are on the board."""
        x, y = cell
        steps = [(x + dx, y + dy) for dx, dy in DIRECTIONS]
        return [step for step in steps if self.contains(step)]


def distance(one: tuple[int, int], other: tuple[int, int]) -> int:
    """Manhattan distance, which is the only one a cardinal grid can walk."""
    return abs(one[0] - other[0]) + abs(one[1] - other[1])
