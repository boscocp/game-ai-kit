"""Checkers with a learned evaluation (T32): the rules agree with Godot's, the
evaluation agrees with Godot's, and what the published file says about the
match is true.

The published file is what the game reads. Re-running the whole pipeline
(self-play and both fits) is `check_no_training.py`'s N7, about forty
seconds; here the match alone is replayed from the published weights and its
seed, which is the claim a reader of the panel is asked to believe.
"""

import json
import pathlib
import random
import unittest

from gameaikit.checkers import evaluation, report, rules, selfplay, train

ROOT = pathlib.Path(__file__).resolve().parents[2]
VECTORS = ROOT / "spec" / "vectors" / "checkers"
PUBLISHED = ROOT / "godot" / "game" / "checkers" / report.FILE_NAME
SIDES = {"red": rules.RED, "white": rules.WHITE}

#: Chance against the hand-written evaluation is half a point a game. A
#: hundred games score within about 0.05 of a true value one time in three,
#: so "no better than chance" is held as no better than two of those above.
CHANCE = 0.5
NOISE = 0.1


def _cases(name: str) -> list[dict]:
    cases = json.loads((VECTORS / name).read_text(encoding="utf-8"))["cases"]
    if not cases:
        raise AssertionError(f"{name} has no cases: a vector that checks nothing passes")
    return cases


class TheRulesVector(unittest.TestCase):
    def test_every_position_has_exactly_the_legal_moves_listed_in_order(self):
        for case in _cases("rules.json"):
            board = rules.from_rows(case["rows"], SIDES[case["to_move"]])
            with self.subTest(case["name"]):
                self.assertEqual([move.notation() for move in rules.legal_moves(board)], case["moves"])

    def test_a_crowned_man_is_a_king_and_the_other_side_moves(self):
        board = rules.from_rows(["........", "..w.w...", ".r......"] + ["........"] * 5, rules.RED)
        after = rules.play(board, rules.legal_moves(board)[0])
        self.assertEqual(after.piece_at(3, 0), rules.RED_KING)
        self.assertEqual(after.to_move, rules.WHITE)
        self.assertEqual(after.piece_at(2, 1), rules.EMPTY)


class TheEvaluationVector(unittest.TestCase):
    def test_the_counts_and_the_score_are_the_vector_s(self):
        for case in _cases("evaluation.json"):
            board = rules.from_rows(case["rows"], rules.RED)
            player = SIDES[case["player"]]
            with self.subTest(case["name"]):
                self.assertEqual(evaluation.features(board, player), case["features"])
                self.assertAlmostEqual(evaluation.score(board, player, tuple(case["weights"])), case["score"],
                                       places=9)


class SelfPlay(unittest.TestCase):
    def test_random_openings_make_different_games(self):
        played = selfplay.run(games=20)
        self.assertGreater(played.distinct_games, 15)

    def test_the_same_seed_plays_the_same_games(self):
        first = selfplay.run(games=10)
        second = selfplay.run(games=10)
        self.assertEqual((first.rows, first.labels), (second.rows, second.labels))

    def test_a_label_is_whether_the_side_to_move_went_on_to_win(self):
        positions, won_by = selfplay.play_game(random.Random(4), evaluation.HAND_WEIGHTS, 1)
        self.assertNotEqual(won_by, -1, "seed 4 should give a decisive game; pick another if the rules change")
        self.assertEqual(rules.winner(positions[-1]), won_by)


class ThePublishedFile(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.published = json.loads(PUBLISHED.read_text(encoding="utf-8"))

    def test_it_names_the_evaluation_s_features_in_order(self):
        self.assertEqual(self.published["features"], list(evaluation.FEATURES))
        self.assertEqual(self.published["hand"]["weights"], list(evaluation.HAND_WEIGHTS))

    def test_the_match_is_reproduced_from_its_seed(self):
        weights = tuple(self.published["learned"]["weights"])
        for record in self.published["learned_against_hand"]:
            with self.subTest(depth=record["depth"]):
                replayed = train.match(weights, record["depth"], seed=self.published["match_seed"])
                self.assertEqual(report._record(replayed), record)

    def test_the_shuffled_labels_control_does_no_better_than_chance(self):
        weights = tuple(self.published["control"]["weights"])
        for record in self.published["control_against_hand"]:
            with self.subTest(depth=record["depth"]):
                replayed = train.match(weights, record["depth"], seed=self.published["match_seed"])
                self.assertEqual(report._record(replayed), record)
                self.assertLessEqual(replayed.score(), CHANCE + NOISE)


if __name__ == "__main__":
    unittest.main()
