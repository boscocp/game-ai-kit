"""The squad's evaluation for expectiminimax (T88), as `squad_evaluated_game.gd` writes it.

Read the Godot file for the why. Before the game is over a position scores
the weighed sum of three terms, each in [-1, 1], the weights in
`rules.json`'s `evaluation`: the health left, the side's less the other's
over a full squad's; the cover its pieces hold against the enemy's, less
the enemy's against its own; and the share of the enemy's pieces it could
shoot with no cover between, less the share of its own the enemy could.
Written by hand; nothing is fitted.

`expected_values` searches one entry of `spec/squad/duel.json` with
`ExpectiminimaxSearch`, the twin of what `godot/test/squad/` checks: the
expected value of every answer at the root, equal in both languages.

When not to use it: for MCTS's playouts, which `SquadSearchGame` scores on
health alone.
"""

from __future__ import annotations

from gameaikit.adversarial.expectiminimax import AdversarialResult, ExpectiminimaxSearch
from gameaikit.squad.search_game import SIDES, Board, Position, SquadSearchGame, described, full_health, health_left, position_from
from gameaikit.squad.shot import RULES, cover_of

TERMS = ("health", "cover", "flanked")


class SquadEvaluatedGame(SquadSearchGame):
    """`SquadSearchGame`, scored by the hand-written evaluation until the game is over."""

    def evaluate(self, state: Position, player: int) -> float:
        if self.is_terminal(state):
            return super().evaluate(state, player)
        terms = self.terms_for(state.board, player)
        score = 0.0
        for term in TERMS:
            score += float(RULES["evaluation"][term]) * terms[term]
        return score

    def terms_for(self, board: Board, player: int) -> dict[str, float]:
        """The three terms for `player`, unweighed."""
        other = SIDES - 1 - player
        health = float(health_left(board, player) - health_left(board, other)) / full_health()
        return {"health": health, "cover": self.covered(board, player) - self.covered(board, other),
                "flanked": self.exposed(board, other) - self.exposed(board, player)}

    def covered(self, board: Board, side: int) -> float:
        """The cover `side`'s pieces hold against the enemy's, over every pair, in [0, 1]."""
        full = float(RULES["cover"]["full"])
        total, pairs = 0.0, 0
        for piece in board.of(side):
            for enemy in board.of(SIDES - 1 - side):
                total += cover_of(self.rows, enemy.cell, piece.cell)["cover"] / full
                pairs += 1
        return total / pairs if pairs else 0.0

    def exposed(self, board: Board, side: int) -> float:
        """The share of `side`'s pieces an enemy could shoot with no cover facing it."""
        pieces = board.of(side)
        if not pieces:
            return 0.0
        enemies = board.of(SIDES - 1 - side)
        count = sum(1 for piece in pieces if any(
            self.reaches(enemy, piece.cell) and cover_of(self.rows, enemy.cell, piece.cell)["cover"] == 0
            for enemy in enemies))
        return float(count) / len(pieces)


def expected_values(rows: list[str], written: dict, depth: int) -> AdversarialResult:
    """The entry's root searched by expectiminimax to `depth`, with the hand-written evaluation."""
    plain, root = position_from(rows, written)
    game = SquadEvaluatedGame(plain.rows)
    return ExpectiminimaxSearch(game, root).search_to(depth)


def root_values(found: AdversarialResult) -> list[list]:
    """`[answer, expected value]` for every answer at the root, in the game's order."""
    return [[described(entry["action"]), entry["value"]] for entry in found.considered]
