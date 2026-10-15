"""The Python half of the cloning conformance run: `spec/vectors/cloning/`."""

import json
import math
import pathlib
import unittest
from collections import Counter

from gameaikit.cloning.ghost import CaseTable
from gameaikit.cloning.softmax import Softmax

VECTORS = pathlib.Path(__file__).resolve().parents[2] / "spec" / "vectors" / "cloning"
TOLERANCE = 1e-12


def table_of(features: list[str], counted: dict) -> CaseTable:
    """A case table holding exactly `counted`, built through its own constructor."""
    rows = []
    for key, counts in counted.items():
        situation = dict(zip(features, key.split(" | ")))
        rows += [(situation, action) for action, count in counts.items() for _ in range(count)]
    return CaseTable(features, rows)


class TestCloningVectors(unittest.TestCase):
    def test_the_softmax_vector(self) -> None:
        vector = json.loads((VECTORS / "softmax-by-hand.json").read_text())
        model = Softmax(**vector["model"])
        self.assertTrue(vector["cases"])
        for case in vector["cases"]:
            chances = model.probabilities(case["situation"])
            for answer, expected in case["probabilities"].items():
                self.assertTrue(math.isclose(chances[answer], expected, abs_tol=TOLERANCE), (case, answer))
            self.assertEqual(model.likeliest(case["situation"]), case["likeliest"])

    def test_the_ghost_vector(self) -> None:
        vector = json.loads((VECTORS / "ghost-by-hand.json").read_text())
        table = table_of(vector["features"], vector["table"])
        self.assertTrue(vector["cases"])
        for case in vector["cases"]:
            self.assertEqual(table.exact(case["situation"]), Counter(case["exact"]))
            distance, pooled = table.nearest(case["situation"])
            self.assertEqual((distance, pooled), (case["distance"], Counter(case["nearest"])))
