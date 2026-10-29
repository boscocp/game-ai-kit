"""What MCTS must do, in Python, apart from agreeing with Godot (T86).

The vectors hold the two languages to one another; they would pass two
searches that were wrong the same way. These hold the search to the games:
Nim's known winning play, the dice race's obvious choices at the end, and
the shape of the tree under chance.
"""

import unittest

from gameaikit.adversarial import AdversarialGame, MonteCarloSearch, Xorshift
from gameaikit.adversarial.toy_games import DiceRace, Nim, Pile, Race


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

    def test_the_interface_has_no_body_but_outcomes(self) -> None:
        with self.assertRaises(NotImplementedError):
            AdversarialGame().to_move(None)


if __name__ == "__main__":
    unittest.main()
