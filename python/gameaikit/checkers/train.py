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

Beside the fit, controls: the same rows with their labels shuffled, from
several seeds. Weights fitted to noise must play no better than chance
against the hand-written ones. But read what they are: alpha-beta only ever
compares two scores, so it ignores how *large* the weights are, only which
way they point. A fit to noise is tiny, and still points somewhere -- and
because men and advancement move together in these rows (r = 0.89), it
tends to point the way the learned weights do, men up and advancement down.
So a control is a random direction, not a chance player, and the report
publishes several to show how wide that spread is.

And an ablation: the learned weights with advancement set to zero, which
says how much of the match comes from that one weight.

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
#: How many shuffles of the labels are fitted and played. Each is a seed of
#: its own, after the self-play seed. Four, because each costs two matches.
CONTROLS = 4
#: Where advancement sits in `evaluation.FEATURES`, for the ablation.
ADVANCEMENT = evaluation.FEATURES.index("advancement")


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
    learned_matches: tuple[Record, ...]
    controls: tuple[Model, ...]
    control_matches: tuple[tuple[Record, ...], ...]
    without_advancement: tuple[float, ...]
    without_advancement_matches: tuple[Record, ...]


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
    """Self-play, fit, fit the controls and the ablation, and play them all
    against the hand."""
    played = selfplay.run(seed)
    learned = fit(played.rows, played.labels)
    controls = tuple(fit(played.rows, shuffled(played.labels, seed + offset)) for offset in range(1, CONTROLS + 1))
    ablated = without(learned.weights, ADVANCEMENT)
    return Trained(played, learned, matches(learned.weights), controls,
                   tuple(matches(control.weights) for control in controls),
                   ablated, matches(ablated))


def matches(weights: tuple[float, ...]) -> tuple[Record, ...]:
    """`weights` against the hand at every depth the report publishes."""
    return tuple(match(weights, depth) for depth in MATCH_DEPTHS)


def without(weights: tuple[float, ...], index: int) -> tuple[float, ...]:
    """`weights` with one of them set to zero."""
    return tuple(0.0 if position == index else weight for position, weight in enumerate(weights))
