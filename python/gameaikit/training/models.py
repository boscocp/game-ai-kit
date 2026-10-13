"""A fitted model, in the form the game will read it back in.

Two numbers per feature, and the difference between them is the whole reason
this type exists:

* `weights` apply to **raw game numbers** -- a health difference of 7, terrain
  of 3 -- because that is what the game has and a scaler in the game is a
  second place for the arithmetic to be wrong;
* `comparable_weights` are the same model in standard deviations, and they are
  the ones to read. A raw weight is in the units of its feature, so a weight of
  0.4 on terrain and 0.1 on health difference says nothing about which matters
  more until both are put on one scale.

Printing only the first is how a model gets explained wrongly; printing only
the second is how it gets applied wrongly.
"""

from __future__ import annotations

import dataclasses

from .descent import linear_prediction, logistic_prediction

#: Decimal places kept when the weights are written out. Six is far more than
#: the data justifies and few enough that two machines agree on the text.
DIGITS = 6

#: What each kind of model does with `w·x + b`.
PREDICTORS = {
    "logistic": logistic_prediction,
    "linear": linear_prediction,
}


@dataclasses.dataclass(frozen=True)
class Model:
    """One fitted model: what it is, what it saw, and what it concluded."""

    kind: str
    features: tuple[str, ...]
    weights: tuple[float, ...]
    bias: float
    comparable_weights: tuple[float, ...]
    rows_trained_on: int

    def predict(self, row: list[float]) -> float:
        """What this model says about one row of raw game numbers."""
        return PREDICTORS[self.kind](list(self.weights), self.bias, row)

    def to_dict(self) -> dict:
        """The shape written to `weights.json`, rounded so text compares."""
        return {
            "kind": self.kind,
            "features": list(self.features),
            "weights": [round(weight, DIGITS) for weight in self.weights],
            "bias": round(self.bias, DIGITS),
            "comparable_weights": [
                round(weight, DIGITS) for weight in self.comparable_weights
            ],
            "rows_trained_on": self.rows_trained_on,
        }

    def by_importance(self) -> list[tuple[str, float, float]]:
        """Feature, raw weight and comparable weight, strongest first.

        Sorted by the size of the comparable weight, because that is the
        ordering a reader is actually asking for when they ask what the model
        learned.
        """
        together = list(zip(self.features, self.weights, self.comparable_weights))
        return sorted(together, key=lambda entry: abs(entry[2]), reverse=True)
