"""Play MENACE against its two opponents, and keep it at several ages.

Nothing here prints or writes: `report.py` does. The same seed gives the same
games and so the same beads, which is what lets the published file be checked
against a fresh run (`check_no_training.py`, N6).
"""

from __future__ import annotations

import random

from . import board as game
from .matchbox import Menace, play_from
from .opponents import perfect_move, random_move

SEED = 1961

#: The ages the game can show it at, in games played.
SNAPSHOTS = (10, 100, 1000, 10000)

#: The games played against the random player before the perfect one takes
#: over. Against perfect play MENACE can only draw or lose, so it starts where
#: winning is possible and learns what a win looks like; then perfect play
#: teaches it where it is weak.
AGAINST_RANDOM = 5000


def play_one(menace: Menace, opponent, dice: random.Random) -> tuple[str, list[tuple[str, int]]]:
    """One game with MENACE as crosses, drawing beads. The outcome, from
    MENACE's side, and every (box, square) it drew from.
    """
    board = game.START
    used = []
    while game.winner(board) is None:
        if game.to_move(board) == game.NOUGHT:
            board = game.play(board, opponent(board, dice))
        elif board.count(game.EMPTY) == 1:
            board = game.play(board, game.moves(board)[0])
        else:
            box, _symmetry = game.canonical(board)
            square = menace.draw(box, dice.random())
            if square is None:
                return game.NOUGHT, used
            used.append((box, square))
            board = game.play(board, play_from(board, square))
    return game.winner(board), used


def run(seed: int = SEED) -> dict[int, Menace]:
    """Train from fresh beads and return MENACE as it stood at each snapshot."""
    dice = random.Random(seed)
    menace = Menace.fresh()
    snapshots = {}
    for played in range(1, max(SNAPSHOTS) + 1):
        opponent = random_move if played <= AGAINST_RANDOM else perfect_move
        outcome, used = play_one(menace, opponent, dice)
        menace.learn(used, outcome)
        if played in SNAPSHOTS:
            snapshots[played] = menace.copy()
    return snapshots


def greedy_record(menace: Menace, games: int, seed: int, opponent=random_move) -> dict[str, int]:
    """MENACE picking its most-beaded move every time, against `opponent`: how
    many games it won, drew and lost. A resignation is a loss.

    The favourite rather than a drawn bead, so that "it never loses" is a
    question a finite number of games can answer.
    """
    dice = random.Random(seed)
    record = {game.CROSS: 0, game.DRAW: 0, game.NOUGHT: 0}
    for _game in range(games):
        record[_greedy_game(menace, opponent, dice)] += 1
    return record


def _greedy_game(menace: Menace, opponent, dice: random.Random) -> str:
    """One game of the favourite bead against `opponent`, and its outcome."""
    board = game.START
    while game.winner(board) is None:
        if game.to_move(board) == game.NOUGHT:
            board = game.play(board, opponent(board, dice))
        elif board.count(game.EMPTY) == 1:
            board = game.play(board, game.moves(board)[0])
        else:
            square = menace.most_beaded(game.canonical(board)[0])
            if square is None:
                return game.NOUGHT
            board = game.play(board, play_from(board, square))
    return game.winner(board)
