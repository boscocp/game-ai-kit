"""The two small games the adversarial vectors are played on, in Python.

Their GDScript twins are `godot/test/ai_adversarial/nim_example.gd` and
`dice_race.gd`, in the addon's test folder, so the addon's vectors depend on
no example's rules (T86). Each is written to the same order -- the same
actions in the same order, the same outcomes in the same order -- because the
search's draws index into those lists, and a different order is a different
search.

* **Nim**: one, two or three sticks a turn; whoever takes the last one wins.
  No chance. The winning play leaves a multiple of four.
* **The dice race**: two runners, each to reach `GOAL` squares. On your turn
  walk one square, certain, or roll: half the time nothing, a quarter of
  the time two squares, a quarter of the time four squares *and you go
  again*. Chance, and a side that may move twice running.
"""

from __future__ import annotations

from typing import NamedTuple

from gameaikit.adversarial.game import AdversarialGame

#: The squares a runner must reach to win the dice race.
GOAL = 6
#: The roll's three faces, in their fixed order: (chance, squares, again).
ROLL_FACES = ((0.5, 0, False), (0.25, 2, False), (0.25, 4, True))


class Pile(NamedTuple):
    """Nim's state: the sticks left, and whose turn it is, 0 or 1."""

    sticks: int
    player: int


class Nim(AdversarialGame):
    """Nim, as `nim_example.gd` tells it to the search."""

    def to_move(self, state: Pile) -> int:
        return state.player

    def actions(self, state: Pile) -> list[int]:
        return list(range(1, min(3, state.sticks) + 1))

    def result(self, state: Pile, action: int) -> Pile:
        return Pile(state.sticks - action, 1 - state.player)

    def is_terminal(self, state: Pile) -> bool:
        return state.sticks == 0

    def evaluate(self, state: Pile, player: int) -> float:
        if state.sticks > 0:
            return 0.0
        return 1.0 if state.player != player else -1.0


class Race(NamedTuple):
    """The dice race's state: each runner's squares, and whose turn it is."""

    squares: tuple[int, int]
    player: int


class DiceRace(AdversarialGame):
    """The dice race, as `dice_race.gd` tells it to the search."""

    def to_move(self, state: Race) -> int:
        return state.player

    def actions(self, state: Race) -> list[str]:
        return [] if self.is_terminal(state) else ["walk", "roll"]

    def result(self, state: Race, action: str) -> Race:
        """Without chance, a roll is its first face: nothing."""
        return self.outcomes(state, action)[0][1]

    def outcomes(self, state: Race, action: str) -> list[tuple[float, Race]]:
        if action == "walk":
            return [(1.0, _advanced(state, 1, False))]
        return [(chance, _advanced(state, squares, again)) for chance, squares, again in ROLL_FACES]

    def is_terminal(self, state: Race) -> bool:
        return max(state.squares) >= GOAL

    def evaluate(self, state: Race, player: int) -> float:
        """Won 1, lost -1; unfinished, the lead as a share of the goal."""
        lead = state.squares[player] - state.squares[1 - player]
        if self.is_terminal(state):
            return 1.0 if lead > 0 else -1.0
        return lead / GOAL


def _advanced(state: Race, squares: int, again: bool) -> Race:
    """The race after the runner to move goes `squares` on; the turn passes unless `again`."""
    moved = list(state.squares)
    moved[state.player] += squares
    return Race((moved[0], moved[1]), state.player if again else 1 - state.player)
