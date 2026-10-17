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

    def test_the_counter_helps_whoever_it_favours(self) -> None:
        favoured = fights(2000, 13, counter=1)
        even = fights(2000, 13)
        disfavoured = fights(2000, 13, counter=-1)

        self.assertGreater(favoured, even)
        self.assertGreater(even, disfavoured)

    def test_a_reinforcement_only_helps_if_it_arrives_in_time(self) -> None:
        # The one feature whose usefulness comes from a rule somebody chose,
        # rather than from arithmetic everybody would expect.
        self.assertGreater(fights(500, 7, reinforcement_distance=1),
                           fights(500, 7, reinforcement_distance=9))


class TheRulesAFightObeys(unittest.TestCase):
    def test_the_attacker_swings_first(self) -> None:
        # Both on their last point of health and the weakest possible blow is
        # one, so whoever swings first wins. That is what starting the fight
        # buys, and swapping the order was green across the whole suite while
        # the attacker's win rate fell from 75 to 44 in 248 fights.
        won = combat.resolve(attacker_health=1, defender_health=1, numeric_advantage=0,
                             defender_terrain=1, reinforcement_distance=9,
                             rng=random.Random(3))

        self.assertTrue(won)

    def test_the_loser_of_a_fight_dies(self) -> None:
        # Wounding the loser instead doubled the dataset with near-copies of
        # rows already in it -- the exact failure the rule exists to prevent --
        # and nothing objected.
        attacker = Unit(0, 0, 1, 1, 14)
        defender = Unit(1, 1, 2, 1, 14)
        board = Board(7, 5, [[1] * 7 for _ in range(5)], [attacker, defender], (3, 2))
        logged: list = []

        simulate._fight(board, attacker, defender, 0, logged, random.Random(5))

        self.assertEqual(len(logged), 1)
        self.assertEqual(sorted([attacker.is_alive(), defender.is_alive()]), [False, True])


class TheHoldOnTheNode(unittest.TestCase):
    def test_holding_it_two_turns_running_counts_twice(self) -> None:
        held = {0: 0, 1: 0}
        simulate._count_the_hold(held, 0)
        simulate._count_the_hold(held, 0)

        self.assertEqual(held, {0: 2, 1: 0})

    def test_letting_go_of_it_starts_the_count_again(self) -> None:
        # Never resetting was green, and it quietly changed how every game
        # ended: a faction that stood on the node once could finish the capture
        # turns later from anywhere on the board.
        held = {0: 2, 1: 0}
        simulate._count_the_hold(held, None)

        self.assertEqual(held, {0: 0, 1: 0})

    def test_the_other_side_taking_it_resets_yours(self) -> None:
        held = {0: 2, 1: 0}
        simulate._count_the_hold(held, 1)

        self.assertEqual(held, {0: 0, 1: 1})


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
        # The rough cell comes *first*, so entering it spends the whole turn's
        # movement and the three cheap cells behind it stay out of reach. The
        # first version put the rough cell second, where a unit that paid 1 per
        # cell regardless stopped in the same place and the mutation was green.
        board = Board(5, 1, [[1, 3, 1, 1, 1]], [Unit(0, 0, 0, 0, 10)], (4, 0))
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


class TheFeaturesReadOffABoard(unittest.TestCase):
    """The place the dataset is actually made, and the place nothing tested.

    A review flipped the sign of `numeric_advantage`, read the terrain from the
    attacker's cell instead of the defender's, and measured the reinforcement
    from the wrong unit. Every one of those changed the data and left the suite
    green, because no test had ever built a board and looked at the row.
    """

    def board_with(self, units: list[Unit], costs=None) -> Board:
        """A 7x5 board of open ground unless the test says otherwise."""
        grid = costs or [[1] * 7 for _ in range(5)]
        return Board(7, 5, grid, units, (3, 2))

    def test_health_difference_is_the_attackers_advantage_not_the_defenders(self) -> None:
        attacker = Unit(0, 0, 1, 1, 15)
        defender = Unit(1, 1, 2, 1, 9)
        seen = simulate.fight_features(self.board_with([attacker, defender]), attacker, defender)

        self.assertEqual(seen["health_difference"], 6)

    def test_terrain_is_read_from_the_cell_the_defender_stands_on(self) -> None:
        # Cover belongs to whoever is being attacked. Reading the attacker's
        # cell instead is a one-word change that nothing noticed.
        costs = [[1] * 7 for _ in range(5)]
        costs[1][1] = 3   # the attacker is in cover
        costs[1][2] = 2   # the defender is in slightly less
        attacker = Unit(0, 0, 1, 1, 10)
        defender = Unit(1, 1, 2, 1, 10)

        seen = simulate.fight_features(self.board_with([attacker, defender], costs),
                                       attacker, defender)

        self.assertEqual(seen["defender_terrain"], 2)

    def test_numeric_advantage_is_positive_when_the_attacker_brought_friends(self) -> None:
        attacker = Unit(0, 0, 1, 1, 10)
        defender = Unit(1, 1, 2, 1, 10)
        friend = Unit(2, 0, 2, 2, 10)
        seen = simulate.fight_features(
            self.board_with([attacker, defender, friend]), attacker, defender)

        self.assertEqual(seen["numeric_advantage"], 1)

    def test_numeric_advantage_is_negative_when_the_defender_did(self) -> None:
        attacker = Unit(0, 0, 1, 1, 10)
        defender = Unit(1, 1, 2, 1, 10)
        theirs = Unit(2, 1, 1, 2, 10)
        seen = simulate.fight_features(
            self.board_with([attacker, defender, theirs]), attacker, defender)

        self.assertEqual(seen["numeric_advantage"], -1)

    def test_only_units_within_reach_are_counted(self) -> None:
        # NEARBY is 2, so this friend -- three cells from the defender -- is
        # not part of this fight. It has to sit just outside the radius: the
        # first version of this test parked it eight cells away, where
        # widening NEARBY to 4 still excluded it and the mutation stayed green.
        attacker = Unit(0, 0, 1, 1, 10)
        defender = Unit(1, 1, 2, 1, 10)
        just_too_far = Unit(2, 0, 5, 1, 10)
        board = self.board_with([attacker, defender, just_too_far])

        self.assertEqual(simulate.distance(just_too_far.cell(), defender.cell()), 3)
        self.assertEqual(simulate.fight_features(board, attacker, defender)
                         ["numeric_advantage"], 0)

    def test_a_dead_friend_is_nobody_s_advantage(self) -> None:
        attacker = Unit(0, 0, 1, 1, 10)
        defender = Unit(1, 1, 2, 1, 10)
        corpse = Unit(2, 0, 2, 2, 0)
        seen = simulate.fight_features(
            self.board_with([attacker, defender, corpse]), attacker, defender)

        self.assertEqual(seen["numeric_advantage"], 0)

    def test_the_reinforcement_is_the_attackers_nearest_friend(self) -> None:
        # Measured from the attacker. Measuring it from the defender is the
        # mutation that raised the attacker's win rate from 75 to 90 in 248
        # fights, in silence.
        attacker = Unit(0, 0, 1, 1, 10)
        defender = Unit(1, 1, 2, 1, 10)
        ours_far = Unit(2, 0, 5, 1, 10)
        theirs_near = Unit(3, 1, 3, 1, 10)
        seen = simulate.fight_features(
            self.board_with([attacker, defender, ours_far, theirs_near]), attacker, defender)

        self.assertEqual(seen["reinforcement_distance"], 4)

    def test_a_unit_with_no_friends_left_reports_the_sentinel(self) -> None:
        # A fifth of real rows carry this. It is a category wearing a number,
        # and the number is out beyond every real distance on purpose.
        attacker = Unit(0, 0, 1, 1, 10)
        defender = Unit(1, 1, 2, 1, 10)
        seen = simulate.fight_features(self.board_with([attacker, defender]), attacker, defender)

        self.assertEqual(seen["reinforcement_distance"], simulate.WIDTH)

    def test_the_counter_is_the_attackers_side_of_the_table(self) -> None:
        # T44's fifth feature. A runner beats a mortar by the table, so the
        # same pair reads +1 one way round and -1 the other.
        runner = Unit(0, 0, 1, 1, 10, kind="runner")
        mortar = Unit(1, 1, 2, 1, 10, kind="mortar")
        board = self.board_with([runner, mortar])

        self.assertEqual(simulate.fight_features(board, runner, mortar)["counter"], 1)
        self.assertEqual(simulate.fight_features(board, mortar, runner)["counter"], -1)

    def test_an_untyped_unit_has_no_counter_either_way(self) -> None:
        # Every unit in the learning vectors written before T44 is untyped.
        runner = Unit(0, 0, 1, 1, 10, kind="runner")
        plain = Unit(1, 1, 2, 1, 10)
        board = self.board_with([runner, plain])

        self.assertEqual(simulate.fight_features(board, runner, plain)["counter"], 0)
        self.assertEqual(simulate.fight_features(board, plain, runner)["counter"], 0)

    def test_a_captured_node_is_described_from_the_capturing_side(self) -> None:
        # Through a whole game rather than through one function: three units of
        # faction 0 on top of the node and one of faction 1 in the far corner,
        # so only faction 0 can take it. Handing the row the other side's
        # opening position is green against every other test in this file, and
        # the rows it writes look perfectly reasonable.
        # On a full-sized board, so the lone enemy is still walking when the
        # node falls. On a small one it reached our units, died, and the game
        # ended as a wipe-out before anybody had held anything.
        ours = [Unit(0, 0, 7, 5, 18), Unit(1, 0, 7, 4, 18), Unit(2, 0, 6, 5, 18)]
        theirs = [Unit(3, 1, 14, 10, 8)]
        board = Board(15, 11, [[1] * 15 for _ in range(11)], ours + theirs, (7, 5))

        capture = simulate._play(board, 0, [], random.Random(11))

        self.assertIsNotNone(capture)
        self.assertEqual(capture.own_units, 3)
        self.assertEqual(capture.enemy_units, 1)

    def test_the_opening_shape_describes_the_faction_it_was_asked_about(self) -> None:
        # The capture row takes the *capturing* side's opening position, and
        # handing it the loser's was green across the whole suite.
        ours = [Unit(0, 0, 0, 0, 10), Unit(1, 0, 0, 1, 10)]
        theirs = [Unit(2, 1, 6, 4, 10)]
        board = self.board_with(ours + theirs)

        self.assertEqual(simulate.opening_features(board, 0)["own_units"], 2)
        self.assertEqual(simulate.opening_features(board, 0)["enemy_units"], 1)
        self.assertEqual(simulate.opening_features(board, 1)["own_units"], 1)

    def test_the_distance_to_the_node_is_from_the_nearest_unit(self) -> None:
        near = Unit(0, 0, 3, 1, 10)
        far = Unit(1, 0, 0, 0, 10)
        board = self.board_with([near, far, Unit(2, 1, 6, 4, 10)])

        self.assertEqual(simulate.opening_features(board, 0)["distance_to_node"], 1)

    def test_the_terrain_on_the_way_is_a_mean_of_the_cells_walked(self) -> None:
        costs = [[1] * 7 for _ in range(5)]
        costs[2][2] = 3   # one rough cell between the unit and the node
        board = self.board_with([Unit(0, 0, 1, 2, 10), Unit(1, 1, 6, 4, 10)], costs)

        # From (1,2) to the node at (3,2): enters (2,2) at cost 3 and (3,2) at 1.
        self.assertAlmostEqual(simulate.opening_features(board, 0)["terrain_on_the_way"], 2.0)


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

    def test_the_counter_leans_both_ways_in_the_rows(self) -> None:
        # A typed dataset (T44): without fights the table tilts each way, the
        # model has nothing to learn the fifth feature's sign from.
        leans = {row.counter for row in self.combats}
        self.assertEqual(leans, {-1, 0, 1})

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
