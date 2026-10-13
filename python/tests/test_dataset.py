"""The world the training data comes from.

Most of what can go wrong with a dataset goes wrong here rather than in the
fitting: a simulator with no variety produces rows a model cannot separate, and
a simulator with a hidden rule produces rows it separates too well. These tests
are about the data having the shape the report later claims it has.
"""

import random
import unittest

from gameaikit.dataset import combat, policy, simulate
from gameaikit.dataset.board import Board, Unit, distance
from gameaikit.dataset.rows import CAPTURE_FEATURES, COMBAT_FEATURES


def fights(trials: int, seed: int, **kwargs) -> int:
    """How many of `trials` identical fights the attacker won."""
    rng = random.Random(seed)
    base = dict(attacker_health=12, defender_health=12, numeric_advantage=0,
                defender_terrain=1, reinforcement_distance=9)
    base.update(kwargs)
    return sum(combat.resolve(rng=rng, **base) for _ in range(trials))


class TheFight(unittest.TestCase):
    def test_the_same_seed_fights_the_same_fight(self) -> None:
        self.assertEqual(fights(500, 7), fights(500, 7))

    def test_an_even_fight_is_not_a_certainty_either_way(self) -> None:
        # A combat rule with no noise in it would make every feature perfectly
        # predictive, and a model fitted to that learns the rule rather than
        # anything about the game.
        won = fights(500, 7)
        self.assertGreater(won, 50)
        self.assertLess(won, 450)

    def test_being_healthier_helps_the_attacker(self) -> None:
        self.assertGreater(fights(500, 7, attacker_health=18),
                           fights(500, 7, attacker_health=8))

    def test_cover_helps_the_defender(self) -> None:
        self.assertLess(fights(500, 7, defender_terrain=3),
                        fights(500, 7, defender_terrain=1))

    def test_numbers_help_whoever_has_them(self) -> None:
        self.assertGreater(fights(500, 7, numeric_advantage=2),
                           fights(500, 7, numeric_advantage=-2))

    def test_a_reinforcement_only_helps_if_it_arrives_in_time(self) -> None:
        # The one feature whose usefulness comes from a rule somebody chose,
        # rather than from arithmetic everybody would expect.
        self.assertGreater(fights(500, 7, reinforcement_distance=1),
                           fights(500, 7, reinforcement_distance=9))


class TheBoard(unittest.TestCase):
    def test_off_the_board_is_the_dearest_ground_rather_than_an_error(self) -> None:
        board = Board(2, 2, [[1, 1], [1, 1]], [], (0, 0))
        self.assertEqual(board.cost_at((5, 5)), 3)

    def test_a_dead_unit_is_not_standing_anywhere(self) -> None:
        dead = Unit(unit_id=0, faction=0, x=1, y=1, health=0)
        board = Board(3, 3, [[1] * 3] * 3, [dead], (0, 0))
        self.assertIsNone(board.unit_at((1, 1)))
        self.assertEqual(board.living(0), [])


class TheFixedPolicy(unittest.TestCase):
    def test_a_unit_pays_terrain_out_of_its_movement(self) -> None:
        # Three movement, a cost-1 cell and then a cost-3 cell: it takes the
        # first and cannot afford the second.
        board = Board(5, 1, [[1, 1, 3, 1, 1]], [Unit(0, 0, 0, 0, 10)], (4, 0))
        policy.walk(board, board.units[0], (4, 0))

        self.assertEqual(board.units[0].cell(), (1, 0))

    def test_a_unit_with_nowhere_better_to_stand_stays_put(self) -> None:
        board = Board(3, 1, [[1, 1, 1]], [Unit(0, 0, 1, 0, 10)], (1, 0))
        policy.walk(board, board.units[0], (1, 0))

        self.assertEqual(board.units[0].cell(), (1, 0))

    def test_a_friend_standing_next_to_you_is_not_an_enemy(self) -> None:
        friend = Unit(1, 0, 1, 0, 10)
        board = Board(3, 1, [[1, 1, 1]], [Unit(0, 0, 0, 0, 10), friend], (2, 0))

        self.assertIsNone(policy.adjacent_enemy(board, board.units[0]))

    def test_a_unit_will_not_walk_through_another_one(self) -> None:
        blocked = Board(3, 1, [[1, 1, 1]], [Unit(0, 0, 0, 0, 10), Unit(1, 0, 1, 0, 10)], (2, 0))
        policy.walk(blocked, blocked.units[0], (2, 0))

        self.assertEqual(blocked.units[0].cell(), (0, 0))


class TheRowsThatComeOut(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.combats, cls.captures = simulate.collect(120, 4242)

    def test_games_produce_both_kinds_of_row(self) -> None:
        self.assertGreater(len(self.combats), 100)
        self.assertGreater(len(self.captures), 10)

    def test_every_row_knows_which_game_it_came_from(self) -> None:
        # Without this the holdout cannot be split by game, and a split by row
        # scores the model on games it was fitted on.
        self.assertTrue(all(0 <= row.game < 120 for row in self.combats))
        self.assertEqual(len({row.game for row in self.captures}),
                         len(self.captures))

    def test_both_outcomes_happen_often_enough_to_learn_from(self) -> None:
        won = sum(1 for row in self.combats if row.attacker_won)
        share = won / len(self.combats)
        self.assertGreater(share, 0.15)
        self.assertLess(share, 0.85)

    def test_the_features_vary(self) -> None:
        # A feature that is the same number on every row teaches nothing and
        # its weight is meaningless. This is the cheapest way to notice.
        for name in COMBAT_FEATURES:
            with self.subTest(feature=name):
                self.assertGreater(len({getattr(row, name) for row in self.combats}), 2)
        for name in CAPTURE_FEATURES:
            with self.subTest(feature=name):
                self.assertGreater(len({getattr(row, name) for row in self.captures}), 2)

    def test_a_capture_takes_at_least_as_long_as_the_hold_it_needs(self) -> None:
        self.assertTrue(all(row.turns_taken >= simulate.HOLD_NEEDED
                            for row in self.captures))

    def test_the_same_seed_produces_the_same_rows(self) -> None:
        again, also = simulate.collect(120, 4242)
        self.assertEqual(self.combats, again)
        self.assertEqual(self.captures, also)

    def test_a_different_seed_produces_different_rows(self) -> None:
        other, _ = simulate.collect(120, 4243)
        self.assertNotEqual(self.combats, other)

    def test_the_feature_order_is_the_order_the_model_will_see(self) -> None:
        row = self.combats[0]
        self.assertEqual(
            row.features(),
            [float(getattr(row, name)) for name in COMBAT_FEATURES],
        )


class TheDistanceFunction(unittest.TestCase):
    def test_it_is_manhattan_because_that_is_what_the_grid_walks(self) -> None:
        self.assertEqual(distance((0, 0), (3, 4)), 7)


if __name__ == "__main__":
    unittest.main()
