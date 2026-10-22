"""The Python half of the flood vectors in `spec/vectors/search/`.

`flood-*.json` fixes every cell a flood reaches and what it costs; both
`CostFlood` and `gameaikit.search.flood` answer them and are checked
against the file, never against each other. `derive_flood.py` beside the
files is a third copy of the rule, importing nothing from here.
"""

import json
import pathlib
import unittest

from gameaikit.search import flood

VECTORS = pathlib.Path(__file__).resolve().parents[2] / "spec" / "vectors" / "search"

#: Fewer than this and something is wrong with the directory, not the vectors.
FEWEST_VECTORS = 3


def flood_vectors() -> list[dict]:
    found = [json.loads(path.read_text()) for path in sorted(VECTORS.glob("*.json"))]
    return [each for each in found if each.get("kind") == "flood"]


class FloodVectorTest(unittest.TestCase):
    def test_there_are_enough_vectors(self):
        self.assertGreaterEqual(len(flood_vectors()), FEWEST_VECTORS)

    def test_every_vector(self):
        for vector in flood_vectors():
            with self.subTest(vector["name"]):
                reached = flood.within(vector["costs"], tuple(vector["from"]), vector["limit"])
                expected = {(x, y): cost for x, y, cost in vector["expect"]["reached"]}
                self.assertEqual(reached, expected)

    def test_a_wrong_answer_would_be_caught(self):
        # The planted case: the same flood with a limit one lower must differ
        # from some vector's file, or the comparison could not see a change.
        differs = [vector["name"] for vector in flood_vectors()
                   if flood.within(vector["costs"], tuple(vector["from"]), vector["limit"] - 1)
                   != {(x, y): cost for x, y, cost in vector["expect"]["reached"]}]
        self.assertTrue(differs)


if __name__ == "__main__":
    unittest.main()
