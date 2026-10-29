"""The MDP solvers on two grids worked out by hand, and the maze as an MDP.

The grids are small enough to solve on paper, and each docstring does it;
value iteration and policy iteration must land within epsilon of those
numbers, and on the same policy. The maze tests hold the model to the game
it was built from: every step of seeded games, played by `gameaikit.maze.
game` in the stationary regime, is one of the outcomes the model lists,
with the reward it lists.
"""

import random
import unittest

from gameaikit.maze import game, rules
from gameaikit.mdp import maze, solve
from gameaikit.mdp.model import TERMINAL, FiniteMdp

EPSILON = 1e-6
MOVES = ("up", "left", "down", "right")
STEP = {"up": (0, -1), "left": (-1, 0), "down": (0, 1), "right": (1, 0)}
SIDEWAYS = {"up": ("left", "right"), "down": ("left", "right"), "left": ("up", "down"), "right": ("up", "down")}


def corridor() -> FiniteMdp:
    """Four cells in a row, 0 to 3; entering 3 pays 1 and ends; every step costs 0.1; gamma 0.9.

    By hand, walking right: V(2) = -0.1 + 1 = 0.9; V(1) = -0.1 + 0.9 x 0.9
    = 0.71; V(0) = -0.1 + 0.9 x 0.71 = 0.539. Left from 0 bumps the wall.
    """
    def transition(cell: int, action: str) -> list:
        after = max(0, cell - 1) if action == "left" else cell + 1
        if after == 3:
            return [(1.0, -0.1 + 1.0, None)]
        return [(1.0, -0.1, after)]
    return FiniteMdp.from_model([0, 1, 2], ("left", "right"), transition, 0.9)


def slippery() -> FiniteMdp:
    """Frozen Lake in two by two: S F on top, H G below; gamma 0.9, only the goal pays.

    A move goes the intended way or to either side, 1/3 each, and off the
    ice it stays. H (the hole) and G (the goal, +1) end it. By hand: from S
    the best is *up*, into the wall -- it cannot slip into H, only stay or
    slip right to F -- so V(S) = 0.9 (2/3 V(S) + 1/3 V(F)), V(S) = 0.75 V(F).
    From F the best is *right*, into the wall again: it stays or slips down
    into G, so V(F) = 1/3 + 0.9 x 2/3 V(F), V(F) = 5/6 and V(S) = 0.625.
    Every other action is worse at those values (right from S: 0.4375).
    """
    def transition(cell: tuple[int, int], action: str) -> list:
        outcomes = []
        for direction in (action, *SIDEWAYS[action]):
            after = (cell[0] + STEP[direction][0], cell[1] + STEP[direction][1])
            if not (0 <= after[0] <= 1 and 0 <= after[1] <= 1):
                after = cell
            if after == (0, 1):
                outcomes.append((1 / 3, 0.0, None))
            elif after == (1, 1):
                outcomes.append((1 / 3, 1.0, None))
            else:
                outcomes.append((1 / 3, 0.0, after))
        return outcomes
    return FiniteMdp.from_model([(0, 0), (1, 0)], MOVES, transition, 0.9)


class TheHandWorkedGrids(unittest.TestCase):
    def test_value_iteration_finds_the_corridors_values(self):
        mdp = corridor()
        found = solve.value_iteration(mdp, EPSILON)
        for state, wanted in ((0, 0.539), (1, 0.71), (2, 0.9)):
            self.assertAlmostEqual(found.values[mdp.number_of(state)], wanted, delta=EPSILON)
        self.assertEqual([mdp.actions[action] for action in found.policy], ["right"] * 3)

    def test_value_iteration_pushes_against_the_walls_on_the_ice(self):
        mdp = slippery()
        found = solve.value_iteration(mdp, EPSILON)
        self.assertAlmostEqual(found.values[mdp.number_of((0, 0))], 0.625, delta=EPSILON)
        self.assertAlmostEqual(found.values[mdp.number_of((1, 0))], 5 / 6, delta=EPSILON)
        self.assertEqual([mdp.actions[action] for action in found.policy], ["up", "right"])

    def test_policy_iteration_agrees_in_fewer_improvements_than_value_iteration_has_sweeps(self):
        for mdp in (corridor(), slippery()):
            by_values = solve.value_iteration(mdp, EPSILON)
            by_policy = solve.policy_iteration(mdp, EPSILON)
            self.assertEqual(by_policy.policy, by_values.policy)
            for mine, theirs in zip(by_policy.values, by_values.values):
                self.assertAlmostEqual(mine, theirs, delta=2 * EPSILON)
            self.assertLessEqual(by_policy.improvements, by_values.sweeps)
        on_ice = slippery()
        self.assertLess(solve.policy_iteration(on_ice, EPSILON).improvements,
                        solve.value_iteration(on_ice, EPSILON).sweeps)

    def test_the_stopping_threshold_is_aimas(self):
        self.assertAlmostEqual(solve.stopping_threshold(0.001, 0.95), 0.001 * 0.05 / 0.95)

    def test_a_model_whose_probabilities_do_not_sum_to_one_is_refused(self):
        with self.assertRaises(ValueError):
            FiniteMdp.from_model([0], ("stay",), lambda state, action: [(0.5, 0.0, 0)], 0.9)

    def test_a_terminal_outcome_is_worth_its_reward_alone(self):
        mdp = corridor()
        self.assertEqual(mdp.outcomes[mdp.number_of(2)][1], [(1.0, 0.9, TERMINAL)])
        self.assertAlmostEqual(solve.q_value(mdp, [100.0] * 3, mdp.number_of(2), 1), 0.9)


class TheMazeAsAnMdp(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.states = maze.states()

    def test_the_states_are_the_ones_a_game_can_reach(self):
        self.assertEqual(len(self.states), 82160)
        self.assertEqual(len(set(map(maze.index, self.states))), len(self.states))
        self.assertTrue(all(0 <= maze.index(state) < maze.slots() for state in self.states))
        self.assertIn(self.start(), set(self.states))

    def test_every_action_is_a_distribution_and_blinkys_move_ignores_pac_mans(self):
        for state in random.Random(3).sample(self.states, 2000):
            chances = maze.ghost_chances(state)
            self.assertAlmostEqual(sum(chances.values()), 1.0)
            for action in maze.ACTIONS:
                self.assertAlmostEqual(sum(outcome[0] for outcome in maze.transition(state, action)), 1.0)

    def test_every_step_of_a_played_game_is_an_outcome_the_model_lists(self):
        seen = 0
        for seed in range(1, 401):
            played = game.Game(seed, maze.SPEC["ghosts"], maze.SPEC["schedule"])
            chooser = random.Random(seed)
            while played.outcome == game.PLAYING and played.steps < 200:
                before, move = self.state_of(played), chooser.choice(MOVES)
                eaten = len(played.pellets)
                played.step(move)
                after = None if played.outcome != game.PLAYING else self.state_of(played)
                listed = [(reward, nxt) for _, reward, nxt in maze.transition(before, move)]
                self.assertIn(after, [nxt for _, nxt in listed], (seed, before, move))
                reward = next(reward for reward, nxt in listed if nxt == after)
                self.assertAlmostEqual(reward, self.reward_of(played, eaten), msg=(seed, before, move))
                seen += 1
        self.assertGreater(seen, 3000)

    def test_walking_onto_blinky_ends_it_caught(self):
        [(probability, reward, after)] = maze.transition(((5, 3), (6, 3), "left", 15), "right")
        self.assertEqual((probability, after), (1.0, None))
        self.assertAlmostEqual(reward, -0.04 - 10.0)

    def test_the_last_pellet_ends_it_before_blinky_moves(self):
        [(probability, reward, after)] = maze.transition(((2, 1), (6, 3), "left", 0b0001), "left")
        self.assertEqual((probability, after), (1.0, None))
        self.assertAlmostEqual(reward, -0.04 + 1.0 + 10.0)

    @staticmethod
    def start() -> maze.State:
        return ((6, 7), (6, 3), "left", 15)

    @staticmethod
    def state_of(played: game.Game) -> maze.State:
        blinky = played.ghosts[0]
        return (played.pacman, blinky.cell, blinky.heading, sum(maze.pellet_bit(cell) for cell in played.pellets))

    @staticmethod
    def reward_of(played: game.Game, pellets_before: int) -> float:
        reward = maze.REWARDS["step"] + maze.REWARDS["pellet"] * (pellets_before - len(played.pellets))
        if played.outcome == game.WON:
            reward += maze.REWARDS["cleared"]
        if played.outcome == game.CAUGHT:
            reward += maze.REWARDS["caught"]
        return reward


class TheStationaryRegime(unittest.TestCase):
    def test_in_chase_for_ever_no_ghost_ever_reverses(self):
        for seed in range(1, 41):
            played = game.Game(seed, maze.SPEC["ghosts"], maze.SPEC["schedule"])
            chooser = random.Random(seed)
            for _ in range(200):
                if played.outcome != game.PLAYING:
                    break
                self.assertEqual(played.mode(), rules.CHASE)
                self.assertNotEqual(played.ghosts[0].decision["kind"], rules.REVERSAL)
                played.step(chooser.choice(MOVES))

    def test_the_arcade_schedule_is_still_the_default(self):
        self.assertEqual(game.Game(1).mode(), rules.SCATTER)
        self.assertEqual(rules.mode_at(0, maze.SPEC["schedule"]), rules.CHASE)


if __name__ == "__main__":
    unittest.main()
