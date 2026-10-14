"""MENACE: the matchboxes, the beads, and what training buys.

The strength tests play MENACE's favourite bead rather than a random one, so
"it never loses" is a yes or a no over a finite number of games. They hold
the *published* machine, seed 1961, which is what the game plays. How far one
seed speaks for Michie's rules is `python3 -m gameaikit.menace.report --seeds
10`, quoted in docs/concepts/menace.md: against perfect play the 10,000-game
machine loses nothing on nine seeds of ten and resigns every game on the
tenth; against a random player it loses fewer than the 10-game one on all
ten, and nothing on two. The criterion changed on the owner's choice; see
tasks/T28.
"""

import json
import pathlib
import random
import unittest

from gameaikit.menace import board as game
from gameaikit.menace import matchbox, report, train
from gameaikit.menace.matchbox import Menace, play_from
from gameaikit.menace.opponents import perfect_move, random_move

VECTORS = pathlib.Path(__file__).resolve().parents[2] / "spec" / "vectors" / "menace"
FEWEST_VECTORS = 3


class TheBoxes(unittest.TestCase):
    def test_there_are_michies_304_boxes(self):
        boxes = matchbox.every_box()
        by_pieces = [sum(1 for box in boxes if 9 - box.count(".") == pieces) for pieces in (0, 2, 4, 6)]
        self.assertEqual(len(boxes), 304)
        self.assertEqual(by_pieces, [1, 12, 108, 183])

    def test_every_turn_of_a_board_folds_into_the_same_box(self):
        dice = random.Random(3)
        for _trial in range(200):
            board = game.START
            for _move in range(dice.randrange(0, 7)):
                if game.moves(board):
                    board = game.play(board, dice.choice(game.moves(board)))
            boxes = {game.canonical(game.turned(board, symmetry))[0] for symmetry in range(8)}
            self.assertEqual(len(boxes), 1, board)

    def test_a_square_of_the_box_lands_on_the_square_the_turn_put_there(self):
        board = "O.......X"
        box, symmetry = game.canonical(board)
        for square in range(9):
            self.assertEqual(box[square], board[play_from(board, square)])

    def test_the_first_box_holds_three_colours(self):
        self.assertEqual(game.representatives(game.START), [0, 1, 4])
        self.assertEqual(Menace.fresh().boxes[game.START], [4, 4, 0, 0, 4, 0, 0, 0, 0])

    def test_new_boxes_start_with_four_three_two_and_one_beads_a_move(self):
        fresh = Menace.fresh()
        for box, beads in fresh.boxes.items():
            wanted = {0: 4, 2: 3, 4: 2, 6: 1}[9 - box.count(".")]
            self.assertEqual({count for count in beads if count}, {wanted}, box)


class TheRules(unittest.TestCase):
    def test_a_win_adds_three_a_draw_one_and_a_loss_takes_one(self):
        menace = Menace.fresh()
        for outcome, change in ((game.CROSS, 3), (game.DRAW, 1), (game.NOUGHT, -1)):
            before = menace.boxes[game.START][4]
            menace.learn([(game.START, 4)], outcome)
            self.assertEqual(menace.boxes[game.START][4], before + change)

    def test_a_count_never_goes_below_nothing_and_an_empty_box_resigns(self):
        menace = Menace({game.START: [1, 0, 0, 0, 0, 0, 0, 0, 0]})
        menace.learn([(game.START, 0)], game.NOUGHT)
        menace.learn([(game.START, 0)], game.NOUGHT)
        self.assertEqual(menace.boxes[game.START][0], 0)
        self.assertIsNone(menace.draw(game.START, 0.5))
        self.assertIsNone(menace.most_beaded(game.START))

    def test_the_favourite_on_a_tie_is_the_lowest_square(self):
        self.assertEqual(Menace({game.START: [5, 5, 0, 0, 5, 0, 0, 0, 0]}).most_beaded(game.START), 0)

    def test_a_draw_at_the_very_end_takes_the_last_square_with_beads(self):
        self.assertEqual(Menace({game.START: [1, 0, 0, 0, 2, 0, 0, 0, 0]}).draw(game.START, 1.0), 4)

    def test_an_empty_box_in_training_is_a_resignation_and_a_loss(self):
        menace = Menace({box: [0] * 9 for box in matchbox.every_box()})
        outcome, used = train.play_one(menace, random_move, random.Random(1))
        self.assertEqual((outcome, used), (game.NOUGHT, []))

    def test_an_empty_box_when_measuring_is_a_loss_too(self):
        menace = Menace({box: [0] * 9 for box in matchbox.every_box()})
        record = train.greedy_record(menace, 5, 1, perfect_move)
        self.assertEqual(record[game.NOUGHT], 5)

    def test_training_twice_from_the_seed_gives_the_same_beads(self):
        self.assertEqual(report.as_json(train.run()), report.as_json(train.run()))


class WhatTrainingBuys(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.snapshots = train.run()

    def test_after_ten_thousand_games_it_loses_no_game_to_perfect_play(self):
        record = train.greedy_record(self.snapshots[10000], 1000, report.MEASURE_SEED, perfect_move)
        self.assertEqual(record[game.NOUGHT], 0, record)

    def test_after_ten_games_it_loses_to_perfect_play(self):
        record = train.greedy_record(self.snapshots[10], 1000, report.MEASURE_SEED, perfect_move)
        self.assertGreater(record[game.NOUGHT], 0, record)

    def test_against_a_random_player_it_loses_fewer_games_than_when_young(self):
        # Fewer, not a tenth: a tenth held for six seeds of ten, fewer for all.
        young = train.greedy_record(self.snapshots[10], 1000, report.MEASURE_SEED, random_move)
        old = train.greedy_record(self.snapshots[10000], 1000, report.MEASURE_SEED, random_move)
        self.assertLess(old[game.NOUGHT], young[game.NOUGHT], (young, old))

    def test_every_snapshot_has_every_box(self):
        for age, menace in self.snapshots.items():
            self.assertEqual(len(menace.boxes), 304, age)


class TheVectors(unittest.TestCase):
    def test_python_draws_the_bead_each_vector_says(self):
        files = sorted(VECTORS.glob("*.json"))
        self.assertGreaterEqual(len(files), FEWEST_VECTORS)
        for path in files:
            for case in json.loads(path.read_text(encoding="utf-8"))["cases"]:
                with self.subTest(vector=path.name, case=case["name"]):
                    self.assertEqual(game.canonical(case["board"])[0], case["box"])
                    menace = Menace({case["box"]: list(case["beads"])})
                    square = menace.draw(case["box"], case["draw"])
                    move = None if square is None else play_from(case["board"], square)
                    self.assertEqual(move, case["move"])


if __name__ == "__main__":
    unittest.main()
