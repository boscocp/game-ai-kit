"""How good a checkers position looks to one player: three counts and a weight each.

The counts are the ones T27 weighted by hand, in `checkers_evaluation.gd`,
each taken as the player's minus the opponent's:

* `men`: men on the board;
* `kings`: kings on the board;
* `advancement`: rows advanced by the men, from their own back row.

A score is `weights · features`. The hand-written weights are 1, 1.5 and
0.05: a king is a man and a half -- the ratio Samuel's 1959 paper gives,
"three to two" -- and a man earns a twentieth for each row it has gone. T32
fits a second set to game results (`train.py`), and the search does not change.

Both are written out to `checkers_weights.json` and read by the Godot game,
which only multiplies (invariant 6). `spec/vectors/checkers/evaluation.json`
holds the two languages to the same features and the same score.
"""

from __future__ import annotations

from . import rules

FEATURES = ("men", "kings", "advancement")

#: T27's weights, in the order of FEATURES.
HAND_WEIGHTS = (1.0, 1.5, 0.05)


def features(board: rules.Board, player: int) -> list[float]:
    """The three counts for `player`, each theirs minus the opponent's."""
    mine = _counts(board, player)
    theirs = _counts(board, rules.opponent(player))
    return [float(own - other) for own, other in zip(mine, theirs)]


def score(board: rules.Board, player: int, weights: tuple[float, ...] = HAND_WEIGHTS) -> float:
    """`weights · features`: how good `board` looks to `player`, unsearched."""
    return sum(weight * value for weight, value in zip(weights, features(board, player)))


def _counts(board: rules.Board, player: int) -> tuple[int, int, int]:
    """One side's men, kings, and rows advanced by its men."""
    home_row = rules.SIZE - 1 - rules.crowning_row(player)
    men = kings = advanced = 0
    for column, row in board.squares_of(player):
        if rules.is_king(board.piece_at(column, row)):
            kings += 1
        else:
            men += 1
            advanced += abs(row - home_row)
    return men, kings, advanced
