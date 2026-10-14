"""Fit the evaluation's three weights to game results, and play the result.

After Samuel, not Samuel. His 1959 program adjusted its coefficients towards
the score a deeper search backed up, during play, with the piece-advantage
term held fixed by the experimenter. This fits every weight at once, offline,
to who won the game each position came from -- logistic regression with
T5's trainer (`gameaikit.training.descent`), because that is the trainer the
kit has. docs/concepts/learned-evaluation.md says which is which.

The fitted weights are logits: how much each count moves the odds that the
side to move wins. The bias is fitted and published but not used to score:
the search compares positions for one player, and a constant added to every
leaf changes no choice.

Beside the fit, a control: the same rows with their labels shuffled. Weights
fitted to noise must play no better than chance against the hand-written
ones. If they did, the match would be measuring something other than what
the weights learned.

Nothing here prints or writes; `report.py` does both.
"""

from __future__ import annotations

import dataclasses
import random

from ..training import descent
from ..training.models import Model
from . import evaluation, rules, selfplay

#: The match: each opening is played twice, the learned weights red once and
#: white once, so neither side's first-move advantage counts for either. At
#: one ply the evaluation is all there is; at two, the search starts to see a
#: reply, and what a weight gets wrong starts to cost.
MATCH_SEED = 1962
MATCH_OPENINGS = 50
MATCH_DEPTHS = (1, 2)


@dataclasses.dataclass(frozen=True)
class Record:
    """One evaluation's games against the hand-written one."""

    depth: int
    games: int
    won: int
    drawn: int
    lost: int

    def score(self) -> float:
        """Points per game, a draw half a point: 0.5 is even."""
        return (self.won + 0.5 * self.drawn) / self.games


@dataclasses.dataclass(frozen=True)
class Trained:
    """Everything the report publishes."""

    played: selfplay.Played
    learned: Model
    control: Model
    learned_matches: tuple[Record, ...]
    control_matches: tuple[Record, ...]


def fit(rows: list[list[float]], labels: list[float]) -> Model:
    """Logistic regression on the three counts: standardise, descend, and
    fold the scaling back so the weights apply to raw counts."""
    means, deviations = descent.standardise(rows)
    scaled = descent.apply_standardisation(rows, means, deviations)
    weights, bias = descent.fit(scaled, labels, descent.logistic_prediction)
    raw, raw_bias = descent.unstandardise(weights, bias, means, deviations)
    return Model(kind="logistic", features=evaluation.FEATURES, weights=tuple(raw), bias=raw_bias,
                 comparable_weights=tuple(weights), rows_trained_on=len(rows))


def shuffled(labels: list[float], seed: int) -> list[float]:
    """The labels in an order that means nothing, from a seed of their own."""
    scrambled = list(labels)
    random.Random(seed).shuffle(scrambled)
    return scrambled


def match(weights: tuple[float, ...], depth: int, openings: int = MATCH_OPENINGS,
          seed: int = MATCH_SEED) -> Record:
    """`weights` against the hand-written ones, each opening once from each side."""
    won = drawn = lost = 0
    for opening in range(openings):
        for learned_side in (rules.RED, rules.WHITE):
            red, white = ((weights, evaluation.HAND_WEIGHTS) if learned_side == rules.RED
                          else (evaluation.HAND_WEIGHTS, weights))
            _positions, won_by = selfplay.play_game(random.Random(seed + opening), red, depth, white)
            if won_by == -1:
                drawn += 1
            elif won_by == learned_side:
                won += 1
            else:
                lost += 1
    return Record(depth, openings * 2, won, drawn, lost)


def run(seed: int = selfplay.SEED) -> Trained:
    """Self-play, fit, fit the control, and play both against the hand."""
    played = selfplay.run(seed)
    learned = fit(played.rows, played.labels)
    control = fit(played.rows, shuffled(played.labels, seed + 1))
    return Trained(played, learned, control,
                   tuple(match(learned.weights, depth) for depth in MATCH_DEPTHS),
                   tuple(match(control.weights, depth) for depth in MATCH_DEPTHS))
