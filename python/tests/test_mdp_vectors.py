"""The MDP vectors in `spec/vectors/mdp/`, against the published files and `gameaikit.mdp`.

Each case is a maze state with its value, the four moves' Q-values and the
best move, from `derive.py`'s own value iteration. The published values
and policy in `godot/game/maze/` must agree, and so must a one-step lookahead
over the published values -- what Godot computes beside Pac-Man. The other
half is `make test-mdp-vectors`, the same file against Godot's reader.
`mdp.json`'s copies are held to `spec/maze/` byte for byte here too.
"""

import json
import pathlib
import unittest

from gameaikit.mdp import maze, measure, publish, solve

REPO = pathlib.Path(__file__).resolve().parents[2]
VECTORS = REPO / "spec" / "vectors" / "mdp" / "ten-states.json"
SPEC = REPO / "spec" / "maze" / "mdp.json"
COPIES = (REPO / "python" / "gameaikit" / "maze" / "mdp.json", REPO / "godot" / "game" / "maze" / "mdp.json")


def state_of(case: dict) -> maze.State:
    """A vector case as the MDP's state."""
    pellets = sum(maze.pellet_bit(tuple(cell)) for cell in case["pellets"])
    return (tuple(case["pacman"]), tuple(case["ghost"]), case["heading"], pellets)


class TheVectors(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.document = json.loads(VECTORS.read_text())
        published = json.loads((measure.PUBLISHED / publish.VALUES_FILE).read_text())
        scale = published["scale"]
        cls.values = [None if value is None else value / scale for row in published["values"] for value in row]
        cls.policy = measure.read_policy()

    def test_there_are_ten_cases(self):
        self.assertEqual(len(self.document["cases"]), 10)

    def test_the_published_value_and_action_are_the_vectors(self):
        for case in self.document["cases"]:
            slot = maze.index(state_of(case))
            self.assertAlmostEqual(self.values[slot], case["value"], delta=self.document["tolerance"], msg=case["name"])
            self.assertEqual(measure.WORDS[self.policy[slot]], case["action"], case["name"])

    def test_a_lookahead_over_the_published_values_finds_the_vectors_q_values(self):
        for case in self.document["cases"]:
            state = state_of(case)
            for action in maze.ACTIONS:
                worth = 0.0
                for probability, reward, after in maze.transition(state, action):
                    future = 0.0 if after is None else self.values[maze.index(after)]
                    worth += probability * (reward + maze.SPEC["discount"] * future)
                self.assertAlmostEqual(worth, case["q"][action], delta=self.document["tolerance"],
                                       msg=(case["name"], action))


class TheProof(unittest.TestCase):
    def test_from_the_start_the_published_policy_can_never_be_caught(self):
        """Over every way Blinky's dice may fall, and in every state some move is safe."""
        found = measure.catch_from_start(measure.read_policy())
        self.assertEqual(found["reached_with_a_catch_possible"], 0)
        self.assertEqual(found["states_with_no_safe_move"], 0)
        self.assertGreater(found["reached"], 600)


class TheCopies(unittest.TestCase):
    def test_every_copy_of_the_mdp_is_the_spec_byte_for_byte(self):
        for copy in COPIES:
            self.assertEqual(copy.read_bytes(), SPEC.read_bytes(), copy)


class TheSolvers(unittest.TestCase):
    def test_policy_iteration_finds_value_iterations_values_on_the_maze(self):
        """About thirty seconds: the comparison AIMA draws, on the real model."""
        mdp = maze.build()
        by_values = solve.value_iteration(mdp, maze.SPEC["epsilon"])
        by_policy = solve.policy_iteration(mdp, maze.SPEC["epsilon"])
        self.assertLess(by_policy.improvements, by_values.sweeps)
        self.assertLess(max(abs(one - other) for one, other in zip(by_values.values, by_policy.values)),
                        maze.SPEC["epsilon"])
        for state, (mine, theirs) in enumerate(zip(by_policy.policy, by_values.policy)):
            if mine != theirs:
                self.assertAlmostEqual(solve.q_value(mdp, by_values.values, state, mine),
                                       solve.q_value(mdp, by_values.values, state, theirs), delta=1e-9)


if __name__ == "__main__":
    unittest.main()
