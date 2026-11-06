"""Wave function collapse: the constraint solver with a different order, and no going back.

Read `godot/addons/ai_constraints/wave_collapse.gd` for the why. mxgmn's
simple tiled model is a constraint problem -- a cell a variable, a tile a
value, adjacency a binary constraint -- and `ConstraintSolver` already
propagates it with AC-3. WFC changes three of the solver's choices: the
variable is the one of least *entropy* (Shannon's, over the weights of the
tiles it may still be); its value is one tile drawn by weight; and on a
contradiction it does not backtrack but starts again from the next seed.
This file does the same steps in the same order as the GDScript, and
`spec/vectors/constraints/collapse/` holds both to the same maps.
"""

from __future__ import annotations

import math
from typing import Any

from gameaikit.constraints.draws import SEED_FOR_ZERO, ConstraintDraws
from gameaikit.constraints.problem import ConstraintProblem
from gameaikit.constraints.solver import ConstraintSolver

#: How many seeds `solve` tries before it says there is no map.
ATTEMPTS = 10


def entropy_of(left: list, weights: dict) -> float:
    """Shannon's entropy of a cell that may still be any of `left`, each as
    likely as its weight: log(sum w) - sum(w log w) / sum w. Summed in the
    order of `weights`, so the same tiles give the same bits in both
    languages. A cell down to one tile is certain, 0."""
    chances = [weights[tile] for tile in weights if tile in left]
    if len(chances) <= 1:
        return 0.0
    total = sum(chances)
    return math.log(total) - sum(weight * math.log(weight) for weight in chances) / total


class WaveCollapse(ConstraintSolver):
    """`ConstraintSolver` with the least entropy first, a weighted draw, and restarts."""

    def __init__(self, problem: ConstraintProblem, weights: dict, seed: int = SEED_FOR_ZERO,
                 attempts: int = ATTEMPTS, record: bool = False) -> None:
        super().__init__(problem, seed=seed, mrv=True, lcv=False, propagate=True, record=record)
        self.weights = dict(weights)
        self.attempts = attempts
        self.first_seed = seed
        self.restarts = 0
        self.contradictions: list[str] = []
        self.contradiction = ""
        self._picks = ConstraintDraws(seed)

    def solve(self) -> dict | None:
        """The map (cell -> tile), from the first of `attempts` seeds that
        reaches no contradiction -- `first_seed`, then the next, and so on --
        or None when none does. `restarts` counts the seeds that failed, and
        `contradictions` names the cell each ran out of tiles in. A
        contradiction before the first collapse ends it at once: only the
        tiles and the pins were in play, and no seed changes those."""
        self.restarts, self.contradictions = 0, []
        for attempt in range(self.attempts):
            found = self.attempt(self.first_seed + attempt)
            if found is not None:
                return found
            self.restarts += 1
            self.contradictions.append(self.contradiction)
            if self.assignments == 0:
                return None
        return None

    def attempt(self, seed: int) -> dict | None:
        """One collapse from `seed`, with no restart: the map, or None at the
        first contradiction, named in `contradiction`."""
        self.seed = seed
        self.contradiction = ""
        self._picks = ConstraintDraws(seed)
        return super().solve()

    def entropy(self, name: str) -> float:
        """`entropy_of` the tiles `name` may still be."""
        return entropy_of(self.domains[name], self.weights)

    def _select(self) -> str:
        """The unassigned cell of least entropy; of equal ones, the first in
        the seeded order. Never None: `_backtrack` asks only while one is left."""
        best, lowest = "", math.inf
        for name in self._order:
            if name not in self.assignment and self.entropy(name) < lowest:
                best, lowest = name, self.entropy(name)
        return best

    def _values(self, name: str) -> list:
        """One tile, drawn by weight: the weights of the tiles left, in the
        tile set's order, laid end to end and a draw landing in one. A cell
        down to one tile spends no draw. One value, so nothing to go back to.

        The draws come from a second generator with the attempt's seed, so
        they repeat the numbers the shuffle used. Harmless here -- the
        shuffle's are taken modulo the places left, these modulo a sum of
        weights, and a seed is only ever one map -- but a stream meant to be
        independent should start from a seed of its own."""
        left = [tile for tile in self.weights if tile in self.domains[name]]
        if len(left) == 1:
            return left
        draw = self._picks.index(sum(self.weights[tile] for tile in left))
        for tile in left:
            if draw < self.weights[tile]:
                return [tile]
            draw -= self.weights[tile]
        return left[-1:]

    def _revise(self, index: int, target: str) -> bool:
        """The solver's revise; a cell left with no tile is a contradiction,
        and the search stops there rather than going back."""
        removed = super()._revise(index, target)
        if not self.domains[target] and not self.contradiction:
            self.contradiction = target
            self.gave_up = True
            self._note({"event": "contradiction", "variable": target})
        return removed

    def chosen(self) -> list[Any]:
        """The tiles assigned, in the order the trace kept them: [cell, tile] each."""
        return [[event["variable"], event["value"]] for event in self.trace if event["event"] == "assign"]
