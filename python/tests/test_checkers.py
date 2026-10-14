"""Checkers with a learned evaluation (T32): the rules agree with Godot's, the
evaluation agrees with Godot's, and what the published file says about the
match is true.

The published file is what the game reads. Re-running the whole pipeline
(self-play and both fits) is `check_no_training.py`'s N7, about forty
seconds; here the match alone is replayed from the published weights and its
seed, which is the claim a reader of the panel is asked to believe.
"""

import dataclasses
import json
import pathlib
import random
import unittest

from gameaikit.checkers import evaluation, report, rules, selfplay, train

ROOT = pathlib.Path(__file__).resolve().parents[2]
VECTORS = ROOT / "spec" / "vectors" / "checkers"
PUBLISHED = ROOT / "godot" / "game" / "checkers" / report.FILE_NAME
SIDES = {"red": rules.RED, "white": rules.WHITE}

#: Chance against the hand-written evaluation is half a point a game. Over
#: these hundred games -- fifty openings, each from both sides -- the standard
#: error of a score is 0.02 to 0.03 (measured in the wave 33 review), so 0.1
#: above chance is three standard errors or more. It is a bound checked on
#: one fixed replay, not a statistical test.
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
            board = dataclasses.replace(rules.from_rows(case["rows"], SIDES[case["to_move"]]),
                                        quiet_plies=case.get("quiet_plies", 0))
            moves = rules.legal_moves(board)
            with self.subTest(case["name"]):
                self.assertEqual([move.notation() for move in moves], case["moves"])
                self.assertEqual([move.notation() for move in moves if move.crowns], case["crowns"])
                self.assertEqual([[rules.square_name(square) for square in move.captured] for move in moves],
                                 case["taken"])
                self.assertEqual(rules.is_draw(board), case["drawn"])

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

    def test_a_game_s_winner_is_the_side_its_last_position_says_won(self):
        positions, won_by = selfplay.play_game(random.Random(4), evaluation.HAND_WEIGHTS, 1)
        self.assertNotEqual(won_by, -1, "seed 4 should give a decisive game; pick another if the rules change")
        self.assertEqual(rules.winner(positions[-1]), won_by)

    def test_the_rows_are_the_decisive_games_after_their_openings_labelled_by_who_won(self):
        played = selfplay.run(games=12)
        dice = random.Random(selfplay.SEED)
        rows, labels = [], []
        for _game in range(12):
            positions, won_by = selfplay.play_game(dice, evaluation.HAND_WEIGHTS, selfplay.DEPTH)
            if won_by == -1:
                continue
            for board in positions[selfplay.OPENING_PLIES::selfplay.EVERY]:
                rows.append(evaluation.features(board, board.to_move))
                labels.append(1.0 if board.to_move == won_by else 0.0)
        self.assertGreater(played.drawn, 0, "the twelve games should include a draw, to show it is left out")
        self.assertEqual(played.rows, rows)
        self.assertEqual(played.labels, labels)

    def test_a_control_s_labels_are_the_same_labels_in_another_order(self):
        labels = [1.0] * 30 + [0.0] * 20
        scrambled = train.shuffled(labels, 7)
        self.assertEqual(sorted(scrambled), sorted(labels))
        self.assertNotEqual(scrambled, labels)


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

    def test_no_shuffled_labels_control_does_better_than_chance(self):
        # Every control's published score; the first replayed from its seed,
        # the rest left to N7, which replays the whole file.
        for records in self.published["controls_against_hand"]:
            for record in records:
                self.assertLessEqual(record["score"], CHANCE + NOISE)
        weights = tuple(self.published["controls"][0]["weights"])
        for record in self.published["controls_against_hand"][0]:
            with self.subTest(depth=record["depth"]):
                replayed = train.match(weights, record["depth"], seed=self.published["match_seed"])
                self.assertEqual(report._record(replayed), record)

    def test_the_ablation_is_the_learned_weights_with_advancement_at_zero(self):
        learned = self.published["learned"]["weights"]
        expected = [0.0 if name == "advancement" else weight
                    for name, weight in zip(self.published["features"], learned)]
        self.assertEqual(self.published["without_advancement"]["weights"], expected)


if __name__ == "__main__":
    unittest.main()
