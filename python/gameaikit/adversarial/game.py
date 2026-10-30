"""What a game must tell an adversarial search, as `adversarial_game.gd` says it.

Read the Godot file for the why: the names are Russell & Norvig's (section
5.1), `evaluate` folds their UTILITY and EVAL together, and `to_move` is read
at every position, so a side may act several times running. `outcomes` is
the one method with a body: a game without chance never writes it.

`Game` is the port as a user's code meets it: a `typing.Protocol` (*Fluent
Python*, 2nd ed., ch. 13), so a game of theirs is accepted by its methods,
whatever it inherits. `AdversarialGame` is the same six questions as a
class to inherit, for the one default it gives -- `outcomes`.
"""

from __future__ import annotations

from typing import Any, Protocol


class Game(Protocol):
    """What `MonteCarloSearch` asks of a game; any class with these methods is one."""

    def to_move(self, state: Any) -> int: ...
    def actions(self, state: Any) -> list: ...
    def result(self, state: Any, action: Any) -> Any: ...
    def is_terminal(self, state: Any) -> bool: ...
    def evaluate(self, state: Any, player: int) -> float: ...
    def outcomes(self, state: Any, action: Any) -> list[tuple[float, Any]]: ...


class AdversarialGame:
    """The five questions a search asks a game, and the sixth, chance."""

    def to_move(self, state: Any) -> int:
        """The player whose turn it is in `state`."""
        raise NotImplementedError

    def actions(self, state: Any) -> list:
        """Every action the player to move may take, in a fixed order."""
        raise NotImplementedError

    def result(self, state: Any, action: Any) -> Any:
        """The state playing `action` leads to, as a search without chance sees it."""
        raise NotImplementedError

    def is_terminal(self, state: Any) -> bool:
        """True when the game is over in `state`."""
        raise NotImplementedError

    def evaluate(self, state: Any, player: int) -> float:
        """How good `state` is for `player`: the outcome when it is over."""
        raise NotImplementedError

    def outcomes(self, state: Any, action: Any) -> list[tuple[float, Any]]:
        """Every state `action` may lead to, with its chance, in a fixed order.

        By default one, `result`, certain -- a game with dice overrides it.
        A pair `(probability, state)` here is Godot's
        `{"probability": ..., "state": ...}`.
        """
        return [(1.0, self.result(state, action))]
