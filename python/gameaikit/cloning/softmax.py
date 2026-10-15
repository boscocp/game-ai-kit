"""Multinomial logistic regression -- softmax -- fitted by gradient descent.

Read `godot/addons/ai_learning/softmax_model.gd` for what the model is: a
score per action, its bias plus one weight for each word in the situation,
turned into probabilities by the softmax. This file is the half Godot never
runs, the fitting, written out:

    for every row, every action:
        error = probability the model gives the action - (1 if taken else 0)
    gradient of a weight = mean over rows of error * (1 if its word is present)

which is T5's logistic update with one row of weights per action instead of
one. Every situation has exactly one word per feature, so each row touches
six columns, and a pass is cheap even written in plain Python.

**L2 regularisation**, `PENALTY`, is not optional here. A word that always
came with the same action -- a feature seen once -- would otherwise push its
weight towards infinity, since every step makes that row a little more sure
and none says stop. The penalty pulls every weight back towards 0 in
proportion to its size, and a word seen rarely then cannot outweigh the rest.

When not to use it: answers that depend on two words together; the model
only adds. And anything big: this is a few thousand rows, on purpose.
"""

from __future__ import annotations

import math
from dataclasses import dataclass

from .rows import Situation

#: Passes over the rows, fixed rather than "until it converges": a fixed
#: number reproduces, and the published file must be what a fresh run writes.
PASSES = 300
#: How far each pass moves the weights along the gradient.
RATE = 1.0
#: How hard large weights are pulled back towards 0 (L2).
PENALTY = 0.01


def column(feature: str, word: str) -> str:
    """The column a feature's word is written as, as the game writes it."""
    return f"{feature}={word}"


@dataclass
class Softmax:
    """A fitted model: the actions, the columns, a weight row and a bias per action."""

    classes: list[str]
    columns: list[str]
    weights: list[list[float]]
    bias: list[float]

    def scores(self, situation: Situation) -> list[float]:
        """Each action's score before the softmax: bias plus present weights."""
        index_of = {name: index for index, name in enumerate(self.columns)}
        present = [index_of[c] for c in (column(f, w) for f, w in situation.items()) if c in index_of]
        return [self.bias[answer] + sum(self.weights[answer][index] for index in present)
                for answer in range(len(self.classes))]

    def probabilities(self, situation: Situation) -> dict[str, float]:
        """Each action's probability in `situation`; they sum to 1."""
        return dict(zip(self.classes, _softmax(self.scores(situation))))

    def likeliest(self, situation: Situation) -> str:
        """The likeliest action; of equal ones, the first in `classes`."""
        chances = self.probabilities(situation)
        best = self.classes[0]
        for answer in self.classes:
            if chances[answer] > chances[best]:
                best = answer
        return best

    def size(self) -> int:
        """How many numbers the model is: what the game has to load."""
        return len(self.classes) * (len(self.columns) + 1)


def _softmax(scores: list[float]) -> list[float]:
    """The scores as probabilities; the largest is taken off first so exp cannot overflow."""
    largest = max(scores)
    exponentials = [math.exp(score - largest) for score in scores]
    total = sum(exponentials)
    return [value / total for value in exponentials]


def columns_of(rows: list[tuple[Situation, str]], features: list[str]) -> list[str]:
    """Every feature=word seen in `rows`, feature by feature, words sorted."""
    seen = {column(feature, situation[feature]) for situation, _ in rows for feature in features}
    return [name for feature in features for name in sorted(seen) if name.startswith(feature + "=")]


def fit(rows: list[tuple[Situation, str]], features: list[str], classes: list[str]) -> Softmax:
    """A softmax model of `rows`, looking only at `features`, over `classes`."""
    model = Softmax(classes, columns_of(rows, features), [], [0.0] * len(classes))
    model.weights = [[0.0] * len(model.columns) for _ in classes]
    index_of = {name: index for index, name in enumerate(model.columns)}
    encoded = [([index_of[column(f, situation[f])] for f in features], classes.index(action))
               for situation, action in rows]
    for _ in range(PASSES):
        _one_pass(model, encoded)
    return model


def _one_pass(model: Softmax, encoded: list[tuple[list[int], int]]) -> None:
    """One step of gradient descent over every row, the penalty included."""
    answers = range(len(model.classes))
    weight_gradient = [[0.0] * len(model.columns) for _ in answers]
    bias_gradient = [0.0 for _ in answers]
    for present, taken in encoded:
        scores = [model.bias[answer] + sum(model.weights[answer][index] for index in present) for answer in answers]
        for answer, chance in enumerate(_softmax(scores)):
            error = chance - (1.0 if answer == taken else 0.0)
            bias_gradient[answer] += error
            for index in present:
                weight_gradient[answer][index] += error
    count = len(encoded)
    for answer in answers:
        model.bias[answer] -= RATE * bias_gradient[answer] / count
        row = model.weights[answer]
        for index in range(len(row)):
            row[index] -= RATE * (weight_gradient[answer][index] / count + PENALTY * row[index])
