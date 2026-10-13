"""Hold some games back, and never look at them while fitting.

The split is **by game, not by row**. Several fights come out of one game, and
they share a board, a set of units and a run of dice -- so a split that put
three of a game's fights in training and the fourth in the holdout would be
scoring the model on a situation it had already half seen, and the number that
came out would be too high for a reason nobody could see in it.

The seed is fixed, so the same games are held back on every run and two
measurements are comparable. It is a different seed from the one that generated
the data: sharing one would tie which games exist to which games are hidden,
and changing the dataset size would then quietly change the split as well.
"""

from __future__ import annotations

import random

#: The share of games kept out of training. A quarter of a thousand-odd games
#: is a few hundred rows to be scored on, which is enough for an accuracy to
#: mean something without starving the fit.
HOLDOUT_SHARE = 0.25


def split_by_game(rows: list, seed: int,
                  share: float = HOLDOUT_SHARE) -> tuple[list, list]:
    """Split rows into (training, holdout) with whole games on one side.

    Rows are matched to games through their `game` field, so this works for
    both row types without knowing anything else about either.
    """
    games = sorted({row.game for row in rows})
    if not games:
        raise ValueError("splitting needs rows, and none were given")

    rng = random.Random(seed)
    shuffled = list(games)
    rng.shuffle(shuffled)
    held_back = set(shuffled[:max(1, int(len(shuffled) * share))])

    training = [row for row in rows if row.game not in held_back]
    holdout = [row for row in rows if row.game in held_back]
    return training, holdout
