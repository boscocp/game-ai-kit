"""The Python half of the adversarial conformance run (T86).

`spec/vectors/adversarial/` is read from both languages, and each side checks
every claim against the file -- never against the other side. The numbers
came from neither: `derive.py` beside them, a third MCTS importing nothing
from this repository, wrote them. What they hold is that the two searches
make the same draws in the same order, and read them the same way: the
root's visit counts after a
fixed number of iterations move if a single draw moves.
"""

import json
import math
import pathlib
import unittest

from gameaikit.adversarial import MonteCarloSearch
from gameaikit.adversarial.mcts import Branch
from gameaikit.adversarial.toy_games import DiceRace, Nim, Pile, Race
from gameaikit.core import Xorshift

VECTORS = pathlib.Path(__file__).resolve().parents[2] / "spec" / "vectors" / "adversarial"

#: The margin a mean may differ by: the same sums in the same order, so in
#: practice none.
TOLERANCE = 1e-9

SEARCH_FILES = ("mcts-nim.json", "mcts-dice-race.json")
CASE_KEYS = {"name", "state", "seed", "steps", "exploration", "playout_limit", "visits", "means", "action"}
GAMES = {"nim": Nim, "dice_race": DiceRace}


def state_of(game: str, written: dict):
    """The game's own state for the vector's `state`."""
    if game == "nim":
        return Pile(written["sticks"], written["player"])
    return Race((written["squares"][0], written["squares"][1]), written["player"])


def why_not_a_vector(vector: dict) -> str:
    """Why this is not a usable search vector, or "" when it is one."""
    if set(vector) != {"description", "game", "cases"}:
        return f"A1 its keys are {sorted(vector)}"
    if vector["game"] not in GAMES:
        return f"A2 it names a game the tests do not have: {vector['game']}"
    if not vector["cases"]:
        return "A3 it claims nothing"
    for case in vector["cases"]:
        if set(case) != CASE_KEYS:
            return f"A4 a case's keys are {sorted(case)}, not {sorted(CASE_KEYS)}"
        if len(case["visits"]) != len(case["means"]):
            return f"A5 {case['name']}: visits and means name different numbers of moves"
        if sum(case["visits"]) != sum(case["steps"]):
            return f"A6 {case['name']}: the visits do not add up to the iterations"
    return ""


def wrong_claims(vector: dict, make=MonteCarloSearch) -> list[str]:
    """Every claim in the vector the search `make` builds does not meet."""
    game = GAMES[vector["game"]]()
    wrong = []
    for case in vector["cases"]:
        search = make(game, state_of(vector["game"], case["state"]), case["seed"],
                      case["exploration"], case["playout_limit"])
        found = search.result()
        for iterations in case["steps"]:
            found = search.step(iterations)
        visits = [entry["visits"] for entry in found.considered]
        means = [entry["mean"] for entry in found.considered]
        if visits != case["visits"]:
            wrong.append(f"{case['name']}: visits {visits}, not {case['visits']}")
        elif any(abs(mine - theirs) > TOLERANCE for mine, theirs in zip(means, case["means"])):
            wrong.append(f"{case['name']}: means {means}, not {case['means']}")
        if found.action != case["action"]:
            wrong.append(f"{case['name']}: chose {found.action}, not {case['action']}")
    return wrong


class SpareDraw(MonteCarloSearch):
    """A planted twin with a spare draw: an outcome's number before every move.

    Drawn even when the move turns out to have one outcome, so on Nim it
    breaks rule 1 of the vectors' README (a draw only on a real choice), and
    on the dice race rules 1 and 5. A twin breaking rule 5 alone cannot be
    written: whether an outcome is drawn depends on the move the earlier draw
    chose. `MirroredExpansion` keeps the count instead.
    """

    def _simulate(self, state):
        played = 0
        while played < self._playout_limit and not self._game.is_terminal(state):
            early = self._random.uniform()
            actions = self._game.actions(state)
            outcomes = self._game.outcomes(state, actions[self._random.index(len(actions))])
            state = outcomes[_face(outcomes, early)][1]
            played += 1
        return state


class MirroredExpansion(MonteCarloSearch):
    """A planted twin with the same draws in the same order, one read differently.

    Expansion counts its drawn index from the other end of the untried
    moves: rule 2 broken, nothing else.
    """

    def _expand(self, leaf, descent):
        if leaf.terminal:
            return leaf
        drawn = self._random.index(len(leaf.untried))
        index = leaf.untried.pop(len(leaf.untried) - 1 - drawn)
        action = leaf.actions[index]
        branch = Branch(action, leaf.player, self._game.outcomes(leaf.state, action))
        leaf.branches[index] = branch
        descent.branches.append(branch)
        child = self._child_by_chance(branch)
        descent.nodes.append(child)
        return child


def _face(outcomes: list, drawn: float) -> int:
    reached = 0.0
    for index, (probability, _) in enumerate(outcomes):
        reached += probability
        if drawn < reached:
            return index
    return len(outcomes) - 1


class TestAdversarialVectors(unittest.TestCase):
    def read(self, name: str) -> dict:
        return json.loads((VECTORS / name).read_text(encoding="utf-8"))

    def test_every_search_vector_is_a_vector_and_every_claim_holds(self) -> None:
        for name in SEARCH_FILES:
            with self.subTest(vector=name):
                vector = self.read(name)
                self.assertEqual(why_not_a_vector(vector), "")
                self.assertGreaterEqual(len(vector["cases"]), 4)
                self.assertEqual(wrong_claims(vector), [])

    def test_the_generator_draws_what_the_vector_says(self) -> None:
        cases = self.read("xorshift.json")["cases"]
        self.assertGreaterEqual(len(cases), 3)
        for case in cases:
            generator = Xorshift(case["seed"])
            self.assertEqual([generator.next() for _ in case["draws"]], case["draws"])

    def test_twins_whose_draws_differ_fail_both_games(self) -> None:
        for twin in (SpareDraw, MirroredExpansion):
            for name in SEARCH_FILES:
                with self.subTest(twin=twin.__name__, vector=name):
                    self.assertNotEqual(wrong_claims(self.read(name), twin), [])

    def test_a_broken_vector_is_refused(self) -> None:
        vector = self.read("mcts-nim.json")
        first = vector["cases"][0]
        self.assertIn("A1", why_not_a_vector({key: vector[key] for key in vector if key != "game"}))
        self.assertIn("A2", why_not_a_vector(dict(vector, game="checkers")))
        self.assertIn("A3", why_not_a_vector(dict(vector, cases=[])))
        self.assertIn("A4", why_not_a_vector(dict(vector, cases=[dict(first, seeds=1)])))
        self.assertIn("A5", why_not_a_vector(dict(vector, cases=[dict(first, means=[])])))
        self.assertIn("A6", why_not_a_vector(dict(vector, cases=[dict(first, steps=[4])])))

    def test_a_wrong_mean_or_move_is_caught_even_when_the_visits_agree(self) -> None:
        vector = self.read("mcts-nim.json")
        first = vector["cases"][0]
        self.assertNotEqual(wrong_claims(dict(vector, cases=[dict(first, means=[0.5])])), [])
        self.assertNotEqual(wrong_claims(dict(vector, cases=[dict(first, action=2)])), [])

    def test_the_root_bound_is_infinite_only_for_a_move_never_tried(self) -> None:
        found = MonteCarloSearch(Nim(), Pile(10, 0), 1).step(2)
        never_tried = [entry for entry in found.considered if math.isinf(entry["bound"])]
        self.assertEqual([entry["visits"] for entry in never_tried], [0])


if __name__ == "__main__":
    unittest.main()
