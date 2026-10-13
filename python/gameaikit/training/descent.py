"""Gradient descent, written out, because `.fit()` hides the lesson.

The two models in this kit differ in one line. Logistic regression squashes
`w·x + b` through a sigmoid and is asked a yes-or-no question; linear
regression uses `w·x + b` as it stands and is asked for a number. Everything
else -- including **the update rule** -- is identical:

    gradient = mean over rows of (prediction - label) * feature

That is not a coincidence and it is worth a minute. Squared error through a
linear prediction and log loss through a sigmoid have the same derivative with
respect to the weights, which is why one `fit` below serves both and why the
two models are not two files.

Features are standardised before fitting and the scaling is folded back into
the weights afterwards, so what comes out applies to raw game numbers and the
game needs no scaler. See `unstandardise`.

When not to use it: anything with more features than rows, anything needing
regularisation, anything where the data does not fit in memory. This is a few
thousand rows and four features, and at that size the readable version is also
the fast enough one.
"""

from __future__ import annotations

import math

#: How many passes over the data. Fixed rather than "until it converges",
#: because a fixed number is reproducible and a convergence test is one more
#: thing that can be subtly wrong.
#:
#: Two thousand because **the accuracy converges long before the weights do**,
#: and here the weights are the deliverable. Measured on the combat set: 100
#: steps already scores 0.878 on the holdout, which is the same score 4000
#: steps gets -- and its weights are [+1.07, +0.66, -0.62, -0.36] against the
#: settled [+2.29, +1.42, -1.34, -0.62]. Every effect understated by half, in a
#: model whose whole point is to be read. Stopping when the score stops moving
#: would have published those.
STEPS = 2000

#: How far to move along the gradient each pass.
RATE = 0.1


def sigmoid(value: float) -> float:
    """The logistic squash, written so it cannot overflow.

    `1 / (1 + exp(-value))` raises OverflowError for a value around -746, and a
    training run that dies two thousand steps in because one row was unusual is
    a bad afternoon. The two branches are the same function.
    """
    if value >= 0.0:
        return 1.0 / (1.0 + math.exp(-value))
    swung = math.exp(value)
    return swung / (1.0 + swung)


def linear_prediction(weights: list[float], bias: float, row: list[float]) -> float:
    """`w·x + b`, the number itself."""
    return bias + sum(weight * value for weight, value in zip(weights, row))


def logistic_prediction(weights: list[float], bias: float, row: list[float]) -> float:
    """`w·x + b`, squashed into a probability."""
    return sigmoid(linear_prediction(weights, bias, row))


def fit(rows: list[list[float]], labels: list[float], predict,
        steps: int | None = None, rate: float | None = None) -> tuple[list[float], float]:
    """Fit weights and a bias by gradient descent, and return them.

    Full batch: every row contributes to every step, in the order they were
    given. Nothing is shuffled and nothing is sampled, so two runs of this
    function on the same rows return bit-for-bit the same weights -- which is
    what makes `report.py --check` able to assert determinism at all.
    """
    if not rows:
        raise ValueError("fitting needs rows, and none were given")
    # Resolved here rather than as `steps: int = STEPS` in the signature. A
    # default argument is evaluated once, when this module is imported, so a
    # caller that changes `descent.STEPS` to measure the effect of the knob
    # gets no effect at all -- which is exactly what happened while this file
    # was being written, and the measurement that came back was of 4000 steps
    # five times over.
    steps = STEPS if steps is None else steps
    rate = RATE if rate is None else rate

    weights = [0.0] * len(rows[0])
    bias = 0.0

    for _step in range(steps):
        gradient, bias_gradient = _gradient(rows, labels, weights, bias, predict)
        for index in range(len(weights)):
            weights[index] -= rate * gradient[index]
        bias -= rate * bias_gradient
    return weights, bias


def _gradient(rows: list[list[float]], labels: list[float], weights: list[float],
              bias: float, predict) -> tuple[list[float], float]:
    """The mean of `(prediction - label) * feature` over every row.

    The same expression for both models, which is the thing worth noticing in
    this file.
    """
    gradient = [0.0] * len(weights)
    bias_gradient = 0.0
    for row, label in zip(rows, labels):
        error = predict(weights, bias, row) - label
        for index, value in enumerate(row):
            gradient[index] += error * value
        bias_gradient += error
    count = float(len(rows))
    return [value / count for value in gradient], bias_gradient / count


def standardise(rows: list[list[float]]) -> tuple[list[float], list[float]]:
    """The mean and standard deviation of each column.

    Descent on raw game numbers crawls: health difference runs to ±10 and
    terrain to 3, so one weight needs a step size the other cannot survive.
    A column that never varies gets a standard deviation of 1, which leaves it
    centred and harmless rather than dividing by zero.
    """
    columns = list(zip(*rows))
    means = [sum(column) / len(column) for column in columns]
    deviations = []
    for column, mean in zip(columns, means):
        spread = sum((value - mean) ** 2 for value in column) / len(column)
        deviations.append(math.sqrt(spread) if spread > 0.0 else 1.0)
    return means, deviations


def apply_standardisation(rows: list[list[float]], means: list[float],
                          deviations: list[float]) -> list[list[float]]:
    """Every row, centred and scaled by the given column statistics."""
    return [
        [(value - mean) / deviation
         for value, mean, deviation in zip(row, means, deviations)]
        for row in rows
    ]


def unstandardise(weights: list[float], bias: float, means: list[float],
                  deviations: list[float]) -> tuple[list[float], float]:
    """Fold the scaling back into the weights, so they apply to raw numbers.

    The alternative is to publish the means and deviations and make every
    caller standardise before predicting -- which puts the same three lines in
    the game, in the evaluation, and in whatever reads the weights next, and
    makes a disagreement between them a silent wrong answer rather than a
    failure. One substitution here instead:

        w·((x - mean) / sd) + b  ==  (w/sd)·x + (b - sum(w * mean / sd))
    """
    raw = [weight / deviation for weight, deviation in zip(weights, deviations)]
    shift = sum(weight * mean / deviation
                for weight, mean, deviation in zip(weights, means, deviations))
    return raw, bias - shift
