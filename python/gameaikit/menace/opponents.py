"""The two players MENACE learns against: one that knows nothing, and one that
knows everything.

Noughts and crosses is small enough to search to the end, so the perfect
player is exact minimax over the whole game -- the same idea T27's
`ai_adversarial` uses in Godot, with no depth limit because none is needed.
Neither player is a learner: they are the weather MENACE learns in.
"""

from __future__ import annotations

import functools
import random

from . import board as game


def random_move(board: str, dice: random.Random) -> int:
    """Any legal square, each as likely as the others."""
    return dice.choice(game.moves(board))


def perfect_move(board: str, dice: random.Random) -> int:
    """A square that keeps the best outcome minimax can guarantee, picked at
    random among the equally good ones.

    At random among them so that MENACE meets every perfect line and not one:
    a perfect player that always chose the first best square would teach it a
    single game.
    """
    player = game.to_move(board)
    scored = [(value(game.play(board, square), player), square) for square in game.moves(board)]
    best = max(score for score, _square in scored)
    return dice.choice([square for score, square in scored if score == best])


@functools.lru_cache(maxsize=None)
def value(board: str, player: str) -> int:
    """What the game is worth to `player` with both sides perfect from here:
    1 a win, 0 a draw, -1 a loss.
    """
    outcome = game.winner(board)
    if outcome == game.DRAW:
        return 0
    if outcome is not None:
        return 1 if outcome == player else -1
    children = [value(game.play(board, square), player) for square in game.moves(board)]
    return max(children) if game.to_move(board) == player else min(children)
