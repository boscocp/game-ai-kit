"""The Python half of the learning conformance run.

The vectors in `spec/vectors/learning/` are read from both languages and each
side checks the same two things about them: that the board produces the
feature row the vector writes down, and that the model turns that row into the
number the vector claims. Nothing here imports the GDScript side and nothing
there imports this, which is the whole point -- the file in the middle is what
they agree about.

Neither side produced the numbers in the files. The features were written by
hand off boards small enough to count, and the predictions were filled in by a
throwaway script holding a dot product and `math.exp`, so a vector cannot
confirm a mistake that both implementations share.
"""

import json
import math
import pathlib
import unittest

from gameaikit.dataset.board import Board, Unit
from gameaikit.dataset.simulate import fight_features, opening_features
from gameaikit.training import report
from gameaikit.training.descent import linear_prediction, logistic_prediction

VECTORS = pathlib.Path(__file__).resolve().parents[2] / "spec" / "vectors" / "learning"

#: Fewer than this and something has gone wrong with the directory rather than
#: with the vectors. A test that iterates over an empty glob passes by
#: inspecting nothing, which is the one way a conformance run must not pass.
FEWEST_VECTORS = 3

#: The same margin the GDScript side allows, scaled by the size of the answer.
#: Doubles agree to about 1e-16 relative; this catches a different formula and
#: never a different maths library.
TOLERANCE = 1e-9

PREDICTORS = {"logistic": logistic_prediction, "linear": linear_prediction}


def vector_files() -> list[pathlib.Path]:
    """Every vector in the directory, in a fixed order."""
    return sorted(VECTORS.glob("*.json"))


def board_of(described: dict, node: tuple[int, int]) -> Board:
    """The vector's board, as the simulator's own type.

    The node is per case rather than per board: the second vector asks about
    two nodes on one board, which is the situation the capture model exists
    for, and `opening_features` reads it off the board it is given.
    """
    units = [
        Unit(unit_id=entry["id"], faction=entry["faction"],
             x=entry["x"], y=entry["y"], health=entry["health"])
        for entry in described["units"]
    ]
    return Board(described["width"], described["height"],
                 described["costs"], units, node)


def model_name(case: dict) -> str:
    """Which model a case is about: the one it names, or its kind's."""
    if "model" in case:
        return case["model"]
    return "combat" if case["kind"] == "combat" else "capture"


def predict(model: dict, features: dict) -> float:
    """What this model says about a row, through the training code itself."""
    row = [float(features[name]) for name in model["features"]]
    return PREDICTORS[model["kind"]](list(model["weights"]), model["bias"], row)


def close_enough(one: float, other: float) -> bool:
    """Two numbers the same, allowing for the last places of a double."""
    return abs(one - other) <= TOLERANCE * max(1.0, abs(other))


def row_for(case: dict, described: dict) -> dict | None:
    """The row this case's board produces, or None when it supplies its own."""
    if case["kind"] == "combat":
        board = board_of(described, (0, 0))
        return fight_features(
            board,
            next(unit for unit in board.units if unit.unit_id == case["attacker"]),
            next(unit for unit in board.units if unit.unit_id == case["defender"]),
        )
    if case["kind"] == "capture":
        board = board_of(described, tuple(case["node"]))
        return opening_features(board, case["faction"])
    return None


class TheVectorsThemselves(unittest.TestCase):
    """The directory is readable and claims something."""

    def test_there_are_vectors_to_check(self) -> None:
        self.assertGreaterEqual(len(vector_files()), FEWEST_VECTORS)

    def test_every_vector_claims_at_least_one_thing(self) -> None:
        for path in vector_files():
            with self.subTest(vector=path.name):
                self.assertTrue(json.loads(path.read_text())["cases"])

    def test_every_vector_carries_the_conventions_the_training_publishes(self) -> None:
        # A vector with a stale radius in it would hold both languages to a
        # feature the data was never gathered with, and agree with itself
        # perfectly while doing so.
        for path in vector_files():
            with self.subTest(vector=path.name):
                carried = json.loads(path.read_text())["feature_conventions"]
                self.assertEqual(carried, report.FEATURE_CONVENTIONS)


class TheBoardsProduceTheRowsTheVectorsWriteDown(unittest.TestCase):
    """Feature extraction, which is the half that drifts without saying so."""

    def test_every_board_case_produces_its_row(self) -> None:
        checked = 0
        for path in vector_files():
            data = json.loads(path.read_text())
            for case in data["cases"]:
                produced = row_for(case, data.get("board", {}))
                if produced is None:
                    continue
                checked += 1
                with self.subTest(vector=path.name, case=case["why"]):
                    self.assertEqual(
                        sorted(produced), sorted(case["features"]),
                        "the row has different features from the vector")
                    for name, value in case["features"].items():
                        self.assertTrue(
                            close_enough(float(produced[name]), float(value)),
                            f"{name} came out {produced[name]}, vector says {value}")
        self.assertGreater(checked, 0, "no case read a board")


class TheModelsAnswerWhatTheVectorsClaim(unittest.TestCase):
    """The arithmetic, including the row that overflows the obvious spelling."""

    def test_every_case_predicts_what_it_claims(self) -> None:
        for path in vector_files():
            data = json.loads(path.read_text())
            for case in data["cases"]:
                model = data["models"][model_name(case)]
                with self.subTest(vector=path.name, case=case["why"]):
                    answered = predict(model, case["features"])
                    self.assertTrue(
                        close_enough(answered, case["prediction"]),
                        f"answered {answered!r}, vector says {case['prediction']!r}")

    def test_some_row_is_extreme_enough_to_break_the_obvious_sigmoid(self) -> None:
        # Not a restatement of the case above. It asserts that the vectors
        # still contain a row the careless spelling cannot survive: `exp`
        # overflows a double past about 709, and without a row beyond that the
        # two-branch sigmoid is being carried by every side without ever being
        # exercised. Deleting that row from the vector must fail something.
        logits = [
            abs(linear_prediction(list(model["weights"]), model["bias"],
                                  [float(case["features"][name])
                                   for name in model["features"]]))
            for data in (json.loads(path.read_text()) for path in vector_files())
            for case, model in ((one, data["models"][model_name(one)])
                                for one in data["cases"])
        ]
        self.assertTrue(any(logit > 709.0 for logit in logits),
                        f"the largest logit any vector reaches is {max(logits):.1f}")
        with self.assertRaises(OverflowError):
            math.exp(max(logits))
