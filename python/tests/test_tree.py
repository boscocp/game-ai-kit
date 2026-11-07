"""The decision tree (T113): the Python half of `spec/vectors/tree/`, and the fitting's own rules.

The vectors hold the fit -- these rows make exactly this tree -- and the
walk, which `ai_learning`'s `LearnedTree` is held to as well. A tree is
data, so the comparison is on the published dictionaries themselves.
"""

import json
import pathlib
import unittest

from gameaikit.training import model_file, tree

VECTORS = pathlib.Path(__file__).resolve().parents[2] / "spec" / "vectors" / "tree"
NAMES = ("fit-by-hand", "fit-capped", "fit-a-tie")


def load(name: str) -> dict:
    """One vector file."""
    return json.loads((VECTORS / f"{name}.json").read_text(encoding="utf-8"))


def fitted(vector: dict) -> tree.Tree:
    """The tree this side fits from the vector's rows."""
    features = vector["model"]["features"]
    rows = [(dict(zip(features, row[:-1])), row[-1]) for row in vector["rows"]]
    return tree.fit(rows, features, vector["model"]["classes"], vector["max_depth"], vector["min_leaf"])


def walk_failures(model: tree.Tree, cases: list[dict]) -> list[str]:
    """Every claim of `cases` the tree does not meet, in words."""
    failures = []
    for case in cases:
        found = {"path": model.walk(case["situation"]), "counts": model.counts(case["situation"]),
                 "likeliest": model.likeliest(case["situation"])}
        for claim, value in found.items():
            if value != case[claim]:
                failures.append(f"{case['situation']}: {claim} is {value}, not {case[claim]}")
    return failures


class TheVectors(unittest.TestCase):

    def test_each_vector_fits_to_the_tree_it_claims(self) -> None:
        for name in NAMES:
            with self.subTest(name):
                vector = load(name)
                self.assertEqual(fitted(vector).to_dict(), vector["model"])

    def test_each_walk_meets_every_claim(self) -> None:
        for name in NAMES:
            with self.subTest(name):
                vector = load(name)
                self.assertTrue(vector["cases"])
                self.assertEqual(walk_failures(tree.from_dict(vector["model"]), vector["cases"]), [])

    def test_a_wrong_claim_is_caught(self) -> None:
        # The planted case for both comparisons: a wrong path, and a wrong tree.
        vector = load("fit-by-hand")
        wrong = [dict(vector["cases"][0], path=[0, 1])]
        self.assertTrue(walk_failures(tree.from_dict(vector["model"]), wrong))
        moved = json.loads(json.dumps(vector["model"]))
        moved["nodes"][2]["at_most"] = 3.0
        self.assertNotEqual(fitted(vector).to_dict(), moved)

    def test_every_vector_is_a_model_file_the_game_would_load(self) -> None:
        for name in NAMES:
            with self.subTest(name):
                self.assertEqual(model_file.why_wrong({"models": {name: load(name)["model"]}}), "")


class TheFitting(unittest.TestCase):
    ROWS = [({"distance": "close", "health": 0}, "throw"), ({"distance": "close", "health": 1}, "throw"),
            ({"distance": "near", "health": 0}, "low"), ({"distance": "far", "health": 3}, "high")]

    def test_the_depth_cap_holds(self) -> None:
        for depth in range(4):
            model = tree.fit(self.ROWS, ["distance", "health"], ["high", "low", "throw"], depth, 1)
            self.assertLessEqual(model.depth(), depth)

    def test_no_leaf_is_smaller_than_min_leaf(self) -> None:
        model = tree.fit(self.ROWS, ["distance", "health"], ["high", "low", "throw"], 5, 2)
        sizes = [sum(node["counts"].values()) for node in model.nodes if "counts" in node]
        self.assertTrue(all(size >= 2 for size in sizes), sizes)

    def test_every_child_comes_after_its_parent(self) -> None:
        model = tree.fit(self.ROWS, ["distance", "health"], ["high", "low", "throw"], 5, 1)
        for index, node in enumerate(model.nodes):
            for child in (node.get("yes"), node.get("no")):
                if child is not None:
                    self.assertGreater(child, index)

    def test_a_tree_with_no_rows_is_refused(self) -> None:
        with self.assertRaises(ValueError):
            tree.fit([], ["distance"], ["high"], 3, 1)

    def test_a_chooser_can_be_handed_in(self) -> None:
        # What an ensemble needs: the same fitting, its tests chosen another way.
        only_health = lambda rows, _features, classes, least: tree.best_test(rows, ["health"], classes, least)
        model = tree.fit(self.ROWS, ["distance", "health"], ["high", "low", "throw"], 3, 1, only_health)
        self.assertTrue(all(node.get("feature", "health") == "health" for node in model.nodes))


if __name__ == "__main__":
    unittest.main()
