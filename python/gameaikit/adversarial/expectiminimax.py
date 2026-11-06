"""Expectiminimax, the Python half of T88.

The same values as `godot/addons/ai_adversarial/expectiminimax.gd`, over the
same interface (`AdversarialGame`), so that `spec/vectors/adversarial/` can
hold the two languages to the same expected values, move for move. Read the
Godot file for the why: MAX takes the best move, MIN the worst for MAX, and
a move whose `outcomes` are several is worth their sum, each value weighed
by its probability (Russell & Norvig, *AIMA* 4th ed., section 5.5).

Written as the recursion the book gives, not as Godot's stack: the stack is
there so a search can stop between frames, and Python here only answers one
depth for the vectors and the squad's tests. Two different walks agreeing
on the same file is a stronger check than one walk written twice. Both
count positions the same way: the root, then every position reached, the
ones scored at the cutoff included.

When not to use it: a game without chance, or one whose evaluation you
cannot write -- `MonteCarloSearch` needs none.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import Any

from gameaikit.adversarial.game import Game


@dataclass
class AdversarialResult:
    """What a depth of the search found: as `adversarial_result.gd` has it.

    `considered` holds one entry per root move, in the game's order:
    `{"action", "value", "outcomes": [(probability, value), ...]}`. `value`
    is the move's expected value, the outcomes' values weighed by their
    chances.
    """

    action: Any = None
    value: float = 0.0
    considered: list[dict] = field(default_factory=list)
    positions: int = 0
    depth: int = 0


class ExpectiminimaxSearch:
    """Expectiminimax for the player to move in `state`, to a fixed depth."""

    def __init__(self, game: Game, state: Any) -> None:
        self._game = game
        self._state = state
        self._player = game.to_move(state)
        self._depth_limit = 1
        self._positions = 0

    def search_to(self, depth: int) -> AdversarialResult:
        """Every root move's expected value `depth` plies ahead, and the first of the best."""
        if self._game.is_terminal(self._state) or not self._game.actions(self._state):
            # Nothing to search: no move, no depth, as Godot's search never starts.
            return AdversarialResult(value=self._game.evaluate(self._state, self._player))
        self._depth_limit = max(depth, 1)
        self._positions = 1
        found = AdversarialResult(depth=self._depth_limit, value=-math.inf)
        for action in self._game.actions(self._state):
            outcomes = [(chance, self._value(after, 1)) for chance, after in self._game.outcomes(self._state, action)]
            expected = _weighed(outcomes)
            found.considered.append({"action": action, "value": expected, "outcomes": outcomes})
            # Strictly greater: of equal values the first, as Godot breaks ties.
            if expected > found.value:
                found.value, found.action = expected, action
        found.positions = self._positions
        return found

    def _value(self, state: Any, depth: int) -> float:
        """MAX's best or MIN's worst expected value at `state`, or its evaluation at the cutoff."""
        self._positions += 1
        actions = self._game.actions(state)
        # A position with no move is scored, as Godot scores it, not searched.
        if self._game.is_terminal(state) or not actions or depth >= self._depth_limit:
            return self._game.evaluate(state, self._player)
        values = [self._expected(state, action, depth) for action in actions]
        return max(values) if self._game.to_move(state) == self._player else min(values)

    def _expected(self, state: Any, action: Any, depth: int) -> float:
        """The chance node: each outcome's value times its probability, summed in the game's order."""
        return _weighed([(chance, self._value(after, depth + 1)) for chance, after in self._game.outcomes(state, action)])


def _weighed(outcomes: list[tuple[float, float]]) -> float:
    """Probability times value, added in order from 0 -- as Godot adds them."""
    total = 0.0
    for chance, value in outcomes:
        total += chance * value
    return total
