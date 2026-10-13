"""Simulate, split, fit both models, and hand back everything measured.

Nothing here prints and nothing here writes a file: `report.py` does both. A
pipeline that reports as it goes cannot be called twice and compared with
itself, and comparing it with itself is how `--check` asserts that training is
deterministic.
"""

from __future__ import annotations

import dataclasses
import random

from ..dataset.rows import CAPTURE_FEATURES, COMBAT_FEATURES, Capture, Combat
from ..dataset.simulate import collect
from . import descent
from .models import PREDICTORS, Model
from .split import split_by_game

#: How many games to play. Enough rows that a quarter held back is still a few
#: hundred, and fast enough that the whole pipeline runs in about a second.
GAMES = 1500

#: One seed for the dice, another for the split. Separate on purpose -- see
#: the note in `split.py`.
DATA_SEED = 20261012
SPLIT_SEED = 70402


@dataclasses.dataclass(frozen=True)
class Fitted:
    """A model, and how it did on games it was never trained on."""

    model: Model
    score: float
    baseline: float

    #: What a lookup table of the training rows scores on the same holdout.
    #:
    #: The four features are small integers, so the feature space is small:
    #: 2937 combat rows cover 976 distinct vectors, and 83% of holdout rows
    #: have an *exact* twin in the training set. Answering with that twin's
    #: label scores 0.848 where the majority class scores 0.690 -- so the
    #: majority baseline flatters the model by about fifteen points, and this
    #: is the number that says what the fitting is really worth.
    #:
    #: It is published rather than asserted on. A four-weight model cannot
    #: memorise 976 answers, so beating the table is not required of it; a
    #: model with capacity, as in T18, would have to be read against this
    #: column rather than against the majority class.
    memoriser: float

    holdout_rows: int

    #: Which games each side of the split was drawn from. Carried so that the
    #: two can be checked for overlap afterwards: a holdout sharing games with
    #: the training set scores a model on situations it has already seen, and
    #: the shuffled-label control cannot see that happening -- measured, see
    #: `evaluate.check_no_leak`.
    #:
    #: No default. They used to default to the empty set, which made E4 -- "was
    #: this scored on a game it was trained on" -- pass without looking at
    #: anything for every `Fitted` built without them, including the one the
    #: tests build.
    training_games: frozenset
    holdout_games: frozenset

    def beats_baseline_by(self) -> float:
        """How much better than the baseline, in the score's own units."""
        return self.score - self.baseline


@dataclasses.dataclass(frozen=True)
class Training:
    """Everything one run of the pipeline produced."""

    combat: Fitted
    capture: Fitted
    games: int


def run(games: int = GAMES, shuffle_labels: bool = False) -> Training:
    """The whole pipeline, from dice to two fitted models.

    `shuffle_labels` is the control described in T5: the labels are shuffled
    against the rows before fitting, so every honest relationship is destroyed
    and the model must collapse to the baseline. Without it, an accuracy above
    chance proves nothing, because a leaked feature produces the same number.
    """
    combats, captures = collect(games, DATA_SEED)
    return Training(
        combat=_fit_combat(combats, shuffle_labels),
        capture=_fit_capture(captures, shuffle_labels),
        games=games,
    )


def _fit_combat(combats: list[Combat], shuffle_labels: bool) -> Fitted:
    """Will this attack work? Scored as accuracy against the majority class."""
    training, holdout = split_by_game(combats, SPLIT_SEED)
    rows = [row.features() for row in training]
    labels = _maybe_shuffled([1.0 if row.attacker_won else 0.0 for row in training],
                             shuffle_labels)

    model = _fit(rows, labels, "logistic", COMBAT_FEATURES)
    held_rows = [row.features() for row in holdout]
    held_labels = [1.0 if row.attacker_won else 0.0 for row in holdout]
    remembered = _memoriser(rows, labels, held_rows, _commoner_label(labels))
    return Fitted(
        model=model,
        score=_accuracy(model, held_rows, held_labels),
        baseline=_majority_share(held_labels),
        memoriser=_share_right(remembered, held_labels),
        holdout_rows=len(holdout),
        training_games=frozenset(row.game for row in training),
        holdout_games=frozenset(row.game for row in holdout),
    )


def _fit_capture(captures: list[Capture], shuffle_labels: bool) -> Fitted:
    """How long will this take?

    Scored as mean absolute error, which is lower-is-better -- so the score is
    carried negated, and every comparison in this kit stays "bigger is better"
    for both models. The minus signs below are that convention and not a slip.
    """
    training, holdout = split_by_game(captures, SPLIT_SEED)
    rows = [row.features() for row in training]
    labels = _maybe_shuffled([float(row.turns_taken) for row in training],
                             shuffle_labels)

    model = _fit(rows, labels, "linear", CAPTURE_FEATURES)
    held_rows = [row.features() for row in holdout]
    held_labels = [float(row.turns_taken) for row in holdout]
    guess = sum(labels) / len(labels)
    remembered = _memoriser(rows, labels, held_rows, guess)
    return Fitted(
        model=model,
        score=-_mean_absolute_error(model, held_rows, held_labels),
        baseline=-_mean_absolute_error(None, held_rows, held_labels, guess),
        memoriser=-_mean_absolute_difference(remembered, held_labels),
        holdout_rows=len(holdout),
        training_games=frozenset(row.game for row in training),
        holdout_games=frozenset(row.game for row in holdout),
    )


def _fit(rows: list[list[float]], labels: list[float], kind: str,
         features: tuple[str, ...]) -> Model:
    """Standardise, descend, and fold the scaling back into the weights."""
    means, deviations = descent.standardise(rows)
    scaled = descent.apply_standardisation(rows, means, deviations)
    weights, bias = descent.fit(scaled, labels, PREDICTORS[kind])
    raw, raw_bias = descent.unstandardise(weights, bias, means, deviations)
    return Model(
        kind=kind,
        features=features,
        weights=tuple(raw),
        bias=raw_bias,
        comparable_weights=tuple(weights),
        rows_trained_on=len(rows),
    )


def _maybe_shuffled(labels: list[float], shuffle: bool) -> list[float]:
    """The labels, or the labels put in an order that means nothing.

    Reversing is not shuffling and sorting would be worse; this uses a seeded
    shuffle so the control is as reproducible as the thing it controls.
    """
    if not shuffle:
        return labels
    shuffled = list(labels)
    random.Random(SPLIT_SEED + 1).shuffle(shuffled)
    return shuffled


def _memoriser(rows: list[list[float]], labels: list[float],
               held_rows: list[list[float]], fallback: float) -> list[float]:
    """What a lookup table of the training rows answers for each holdout row.

    Not a model: a dictionary from an exact feature vector to the mean label
    of the training rows that had it, falling back to the overall answer when
    a holdout row is genuinely new. It is here as a yardstick -- a score that
    beats the majority class but not this table is a score explained by the
    holdout rows having been seen before in all but name.
    """
    table: dict[tuple, list[float]] = {}
    for row, label in zip(rows, labels):
        table.setdefault(tuple(row), []).append(label)
    return [
        sum(table[tuple(row)]) / len(table[tuple(row)])
        if tuple(row) in table else fallback
        for row in held_rows
    ]


def _commoner_label(labels: list[float]) -> float:
    """Whichever of 0 and 1 turns up more often."""
    ones = sum(1 for label in labels if label >= 0.5)
    return 1.0 if ones * 2 >= len(labels) else 0.0


def _share_right(predictions: list[float], labels: list[float]) -> float:
    """The share of predictions that fall on the right side of a half."""
    right = sum(
        1 for predicted, label in zip(predictions, labels)
        if (predicted >= 0.5) == (label >= 0.5)
    )
    return right / len(labels)


def _mean_absolute_difference(predictions: list[float], labels: list[float]) -> float:
    """Mean |predicted - actual|, for predictions that came from no model."""
    return sum(abs(predicted - label)
               for predicted, label in zip(predictions, labels)) / len(labels)


def _accuracy(model: Model, rows: list[list[float]], labels: list[float]) -> float:
    """The share of rows whose outcome the model calls correctly."""
    right = sum(
        1 for row, label in zip(rows, labels)
        if (model.predict(row) >= 0.5) == (label >= 0.5)
    )
    return right / len(rows)


def _majority_share(labels: list[float]) -> float:
    """What you score by always answering with the commoner outcome."""
    ones = sum(1 for label in labels if label >= 0.5)
    return max(ones, len(labels) - ones) / len(labels)


def _mean_absolute_error(model: Model | None, rows: list[list[float]],
                         labels: list[float], guess: float = 0.0) -> float:
    """Mean |predicted - actual|, or |guess - actual| when there is no model."""
    total = 0.0
    for row, label in zip(rows, labels):
        predicted = guess if model is None else model.predict(row)
        total += abs(predicted - label)
    return total / len(rows)
