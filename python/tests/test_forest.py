"""The random forest (T114): the Python half of `spec/vectors/forest/`, and the fitting's own rules.

The vectors hold the fit -- these rows and this seed make exactly these
trees -- and the vote, which `ai_learning`'s `LearnedForest` is held to as
well. A forest is data, so the comparison is on the published dictionaries.
"""

import json
import pathlib
import unittest

from gameaikit.core.xorshift import Xorshift
from gameaikit.training import forest, model_file

VECTORS = pathlib.Path(__file__).resolve().parents[2] / "spec" / "vectors" / "forest"
NAMES = ("three-trees", "a-tied-vote")


def load(name: str) -> dict:
    """One vector file."""
    return json.loads((VECTORS / f"{name}.json").read_text(encoding="utf-8"))


def fitted(vector: dict, seed: int | None = None) -> forest.Forest:
    """The forest this side fits from the vector's rows, with its seed unless another is given."""
    features = vector["model"]["features"]
    rows = [(dict(zip(features, row[:-1])), row[-1]) for row in vector["rows"]]
    return forest.fit(rows, features, vector["model"]["classes"], vector["trees"], vector["max_depth"],
                      vector["min_leaf"], vector["seed"] if seed is None else seed)


def vote_failures(model: forest.Forest, cases: list[dict]) -> list[str]:
    """Every claim of `cases` the forest does not meet, in words."""
    failures = []
    for case in cases:
        found = {"votes": model.votes(case["situation"]), "tally": model.tally(case["situation"]),
                 "likeliest": model.likeliest(case["situation"])}
        for claim, value in found.items():
            if value != case[claim]:
                failures.append(f"{case['situation']}: {claim} is {value}, not {case[claim]}")
    return failures


class TheVectors(unittest.TestCase):

    def test_each_vector_fits_to_the_forest_it_claims(self) -> None:
        for name in NAMES:
            with self.subTest(name):
                vector = load(name)
                self.assertEqual(fitted(vector).to_dict(), vector["model"])

    def test_each_vote_meets_every_claim(self) -> None:
        for name in NAMES:
            with self.subTest(name):
                vector = load(name)
                self.assertTrue(vector["cases"])
                self.assertEqual(vote_failures(forest.from_dict(vector["model"]), vector["cases"]), [])

    def test_a_wrong_claim_is_caught(self) -> None:
        # The planted case for both comparisons: a vote changed, a tie
        # settled by the first vote rather than by `classes`, and a forest
        # fitted from another seed.
        vector = load("a-tied-vote")
        read = forest.from_dict(vector["model"])
        wrong_vote = [dict(vector["cases"][1], votes=["low", "low", "low", "high"])]
        first_voter = [dict(vector["cases"][0], likeliest=vector["cases"][0]["votes"][0])]
        self.assertTrue(vote_failures(read, wrong_vote))
        self.assertTrue(vote_failures(read, first_voter))
        self.assertNotEqual(fitted(vector, seed=vector["seed"] + 1).to_dict(), vector["model"])

    def test_every_vector_is_a_model_file_the_game_would_load(self) -> None:
        for name in NAMES:
            with self.subTest(name):
                self.assertEqual(model_file.why_wrong({"models": {name: load(name)["model"]}}), "")


class TheFitting(unittest.TestCase):
    ROWS = [({"distance": "close", "health": 0, "corner": "no"}, "throw"),
            ({"distance": "close", "health": 1, "corner": "yes"}, "throw"),
            ({"distance": "near", "health": 0, "corner": "no"}, "low"),
            ({"distance": "far", "health": 3, "corner": "no"}, "high")]
    FEATURES = ["distance", "health", "corner"]
    CLASSES = ["high", "low", "throw"]

    def test_the_same_seed_fits_the_same_forest(self) -> None:
        one = forest.fit(self.ROWS, self.FEATURES, self.CLASSES, 6, 3, 1, 9)
        two = forest.fit(self.ROWS, self.FEATURES, self.CLASSES, 6, 3, 1, 9)
        self.assertEqual(one.to_dict(), two.to_dict())
        self.assertEqual(len(one.trees), 6)

    def test_a_bootstrap_has_as_many_rows_and_only_rows_it_was_given(self) -> None:
        sample = forest.bootstrap(self.ROWS, Xorshift(4))
        self.assertEqual(len(sample), len(self.ROWS))
        self.assertTrue(all(row in self.ROWS for row in sample))

    def test_a_node_looks_at_the_square_root_of_the_features(self) -> None:
        self.assertEqual(forest.subset_size(["a"]), 1)
        self.assertEqual(forest.subset_size(self.FEATURES), 1)
        self.assertEqual(forest.subset_size(["a", "b", "c", "d", "e", "f"]), 2)

    def test_the_drawn_features_keep_their_order(self) -> None:
        # So a tie between two features goes to the first, as in one tree.
        asked = []
        choose = forest.subset_chooser(Xorshift(2), 2)
        spy = lambda rows, features, classes, least: asked.append(features)
        original, forest.tree.best_test = forest.tree.best_test, spy
        try:
            for _ in range(10):
                choose(self.ROWS, ["a", "b", "c", "d"], self.CLASSES, 1)
        finally:
            forest.tree.best_test = original
        for drawn in asked:
            self.assertEqual(len(drawn), 2)
            self.assertEqual(drawn, sorted(drawn, key=["a", "b", "c", "d"].index))

    def test_every_tree_abstaining_answers_nothing(self) -> None:
        # A word where a number is asked and a number where a word is: no
        # tree of the vector can read its root, and the forest guesses nothing.
        model = forest.from_dict(load("three-trees")["model"])
        unreadable = {"distance": 7, "health": "low"}
        self.assertEqual(model.votes(unreadable), ["", "", ""])
        self.assertEqual(model.likeliest(unreadable), "")
        self.assertEqual(model.probabilities(unreadable), {})

    def test_a_forest_with_no_rows_or_no_trees_is_refused(self) -> None:
        with self.assertRaises(ValueError):
            forest.fit([], self.FEATURES, self.CLASSES, 3, 3, 1, 1)
        with self.assertRaises(ValueError):
            forest.fit(self.ROWS, self.FEATURES, self.CLASSES, 0, 3, 1, 1)


if __name__ == "__main__":
    unittest.main()
