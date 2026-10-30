"""What MCTS must do, in Python, apart from agreeing with Godot (T86).

The vectors hold the two languages to one another; they would pass two
searches that were wrong the same way. These hold the search to the games:
Nim's known winning play, the dice race's obvious choices at the end, and
the shape of the tree under chance.
"""

import math
import unittest

from gameaikit.adversarial import AdversarialGame, MonteCarloSearch, Xorshift
from gameaikit.adversarial.mcts import EXPLORATION
from gameaikit.adversarial.toy_games import DiceRace, Nim, Pile, Race

#: The seed whose first draw is exactly 2^31, found by running the three
#: steps of `Xorshift.next` backwards from it.
BOUNDARY_SEED = 2281717760


class SharedLeaves(AdversarialGame):
    """Two plies, not zero-sum: a state is the moves made so far."""

    LEAVES = {("a", "x"): (1.0, 1.0), ("a", "y"): (0.0, 0.0), ("b",): (0.5, 0.5)}
    MOVES = {(): ["a", "b"], ("a",): ["x", "y"]}

    def to_move(self, state):
        return len(state) % 2

    def actions(self, state):
        return self.MOVES.get(state, [])

    def result(self, state, action):
        return state + (action,)

    def is_terminal(self, state):
        return state in self.LEAVES

    def evaluate(self, state, player):
        return self.LEAVES.get(state, (0.0, 0.0))[player]


class TestMonteCarloSearch(unittest.TestCase):
    def test_after_a_thousand_iterations_it_leaves_a_multiple_of_four(self) -> None:
        # Measured over seeds 1-40: 1000 iterations find the winning take
        # from every pile up to 11 sticks; 13 needs about 2000.
        for sticks, iterations in ((5, 1000), (6, 1000), (7, 1000), (9, 1000), (10, 1000), (11, 1000), (13, 2000)):
            with self.subTest(sticks=sticks):
                take = MonteCarloSearch(Nim(), Pile(sticks, 0), 1).step(iterations).action
                self.assertEqual((sticks - take) % 4, 0, f"from {sticks} it took {take}")

    def test_stopped_in_two_steps_it_is_the_search_run_in_one(self) -> None:
        # Anytime: a step is a slice of one search, not a fresh one.
        sliced = MonteCarloSearch(DiceRace(), Race((0, 0), 0), 4)
        sliced.step(70)
        twice = sliced.step(130)
        once = MonteCarloSearch(DiceRace(), Race((0, 0), 0), 4).step(200)
        self.assertEqual(twice.considered, once.considered)
        self.assertEqual(twice.iterations, 200)

    def test_it_has_an_answer_at_once_and_of_equal_visits_the_first(self) -> None:
        # Anytime: before any iteration, and after one iteration per move,
        # every move is tied, and the answer is the first the game listed.
        search = MonteCarloSearch(Nim(), Pile(10, 0), 1)
        self.assertEqual(search.result().action, 1)
        self.assertEqual(search.step(3).action, 1)
        self.assertEqual([entry["visits"] for entry in search.result().considered], [1, 1, 1])

    def test_one_square_from_home_it_walks_and_behind_it_rolls(self) -> None:
        self.assertEqual(MonteCarloSearch(DiceRace(), Race((5, 0), 0), 2).step(300).action, "walk")
        # Walking to 5 hands the opponent, also on 5, a certain win; a roll
        # wins half the time.
        self.assertEqual(MonteCarloSearch(DiceRace(), Race((4, 5), 0), 2).step(300).action, "roll")

    def test_a_roll_keeps_one_child_per_face_and_a_walk_one(self) -> None:
        search = MonteCarloSearch(DiceRace(), Race((0, 0), 0), 6)
        search.step(300)
        walk, roll = search._root.branches
        self.assertEqual(sum(child is not None for child in walk.children), 1)
        self.assertEqual(sum(child is not None for child in roll.children), 3)
        self.assertEqual(roll.visits, sum(child.visits for child in roll.children))
        # A four plays again: that child is the same runner's turn.
        self.assertEqual(roll.children[2].player, 0)
        self.assertEqual(roll.children[0].player, 1)

    def test_a_visited_root_move_reports_its_ucb1_bound(self) -> None:
        # What T87 draws: mean + C * sqrt(ln(root visits) / visits), the
        # root visited once an iteration.
        found = MonteCarloSearch(DiceRace(), Race((0, 0), 0), 2).step(150)
        for entry in found.considered:
            expected = entry["mean"] + EXPLORATION * math.sqrt(math.log(found.iterations) / entry["visits"])
            self.assertAlmostEqual(entry["bound"], expected, places=12)

    def test_a_drawn_number_on_a_boundary_falls_in_the_next_outcome(self) -> None:
        # BOUNDARY_SEED draws exactly 2^31, a uniform of exactly 0.5: not
        # below the first outcome's 0.5, below the running 0.75.
        self.assertEqual(Xorshift(BOUNDARY_SEED).next(), 2 ** 31)
        search = MonteCarloSearch(DiceRace(), Race((0, 0), 0), BOUNDARY_SEED)
        self.assertEqual(search._draw_outcome(DiceRace().outcomes(Race((0, 0), 0), "roll")), 1)

    def test_each_chooser_is_credited_with_its_own_value_not_the_opposite(self) -> None:
        # Not zero-sum: after `a`, player 1 picks between a leaf worth 1 to
        # both and one worth 0 to both, and takes the 1, so `a` is worth 1
        # to player 0 -- more than `b`'s 0.5. A search that gave player 1
        # the negation of player 0's value would take the 0, and play `b`.
        self.assertEqual(MonteCarloSearch(SharedLeaves(), (), 3).step(300).action, "a")

    def test_a_finished_game_is_not_searched(self) -> None:
        found = MonteCarloSearch(Nim(), Pile(0, 1), 1).step(50)
        self.assertIsNone(found.action)
        self.assertEqual((found.considered, found.iterations), ([], 0))

    def test_a_game_without_chance_has_one_certain_outcome(self) -> None:
        self.assertEqual(Nim().outcomes(Pile(5, 0), 2), [(1.0, Pile(3, 1))])

    def test_the_generator_starts_where_marsaglia_starts_and_zero_is_one(self) -> None:
        self.assertEqual(Xorshift(1).next(), 270369)
        self.assertEqual(Xorshift(0).next(), 270369)
        drawn = Xorshift(9)
        self.assertEqual({drawn.index(1) for _ in range(5)}, {0})
        self.assertEqual(drawn.next(), Xorshift(9).next())

    def test_a_game_that_inherits_nothing_is_searched_by_its_methods(self) -> None:
        # `Game` is a Protocol (T64): a user's game need not inherit the kit's.
        rules = Nim()

        class NimOfItsOwn:
            to_move, actions, result = rules.to_move, rules.actions, rules.result
            is_terminal, evaluate = rules.is_terminal, rules.evaluate

            def outcomes(self, state: Pile, action: int) -> list:
                return [(1.0, rules.result(state, action))]

        self.assertNotIsInstance(NimOfItsOwn(), AdversarialGame)
        own = MonteCarloSearch(NimOfItsOwn(), Pile(10, 0), 1).step(300)
        kit = MonteCarloSearch(Nim(), Pile(10, 0), 1).step(300)
        self.assertEqual(own, kit)

    def test_what_it_hands_back_is_frozen(self) -> None:
        found = MonteCarloSearch(Nim(), Pile(10, 0), 1).step(10)
        with self.assertRaises(AttributeError):
            found.action = 3

    def test_the_interface_has_no_body_but_outcomes(self) -> None:
        with self.assertRaises(NotImplementedError):
            AdversarialGame().to_move(None)


if __name__ == "__main__":
    unittest.main()
