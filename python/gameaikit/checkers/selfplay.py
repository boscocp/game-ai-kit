"""Games of checkers the hand-written evaluation plays against itself, for data.

A fixed-depth search with a fixed move order plays the same game every time,
so every game opens with `OPENING_PLIES` random moves drawn from a recorded
seed, and only then does the search take over. How many of the games came
out different is counted and published: data from one game replayed four
hundred times would teach one game.

Each position after the opening becomes a row: its three features from the
side to move, labelled 1 if that side went on to win and 0 if it lost. A
drawn game says nothing about who was ahead, and is left out -- counted, so
the report can say how many.

Self-play searches one ply. Measured on 2026-10-14 with `play_game` and
seed 1959, 60 games: at one ply 41 ended in a win, at two plies 12, at three
18, the rest drawn by the 40-move rule with kings circling. A label is a
result, so the depth that finishes games is the one that teaches.
"""

from __future__ import annotations

import dataclasses
import random

from . import evaluation, rules, search

SEED = 1959
GAMES = 400
OPENING_PLIES = 8
DEPTH = 1
#: A game still going after this many plies is called a draw. The 40-move
#: rule ends most games long before; this is the floor under a loop.
LONGEST_GAME = 300
#: One position in this many becomes a row. Neighbouring plies of one game
#: are nearly the same position with the same label; every third keeps the
#: fit to a few seconds and loses little.
EVERY = 3


@dataclasses.dataclass(frozen=True)
class Played:
    """Self-play's yield: the rows, their labels, and what the games were like."""

    rows: list[list[float]]
    labels: list[float]
    games: int
    distinct_games: int
    won_by_red: int
    won_by_white: int
    drawn: int


def play_game(dice: random.Random, weights: tuple[float, ...], depth: int,
              opponent_weights: tuple[float, ...] | None = None) -> tuple[list[rules.Board], int]:
    """One game: random opening, then each side's search. Red searches with
    `weights`, white with `opponent_weights` (the same when None). Returns the
    positions in order and the winner, -1 for a draw."""
    by_side = {rules.RED: weights, rules.WHITE: opponent_weights or weights}
    board = rules.starting()
    positions = [board]
    while not rules.is_over(board) and len(positions) <= LONGEST_GAME:
        if len(positions) <= OPENING_PLIES:
            move = dice.choice(rules.legal_moves(board))
        else:
            move = search.best_move(board, depth, by_side[board.to_move])
        board = rules.play(board, move)
        positions.append(board)
    finished = rules.is_over(board) and not rules.is_draw(board)
    return positions, rules.winner(board) if finished else -1


def run(seed: int = SEED, games: int = GAMES) -> Played:
    """Play `games` games from `seed` and turn the decisive ones into rows."""
    dice = random.Random(seed)
    rows, labels, seen = [], [], set()
    results = {rules.RED: 0, rules.WHITE: 0, -1: 0}
    for _game in range(games):
        positions, won_by = play_game(dice, evaluation.HAND_WEIGHTS, DEPTH)
        seen.add(tuple(position.squares for position in positions))
        results[won_by] += 1
        if won_by == -1:
            continue
        for board in positions[OPENING_PLIES::EVERY]:
            rows.append(evaluation.features(board, board.to_move))
            labels.append(1.0 if board.to_move == won_by else 0.0)
    return Played(rows, labels, games, len(seen), results[rules.RED], results[rules.WHITE], results[-1])
