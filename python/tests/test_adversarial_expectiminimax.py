"""Expectiminimax in Python (T88): the vectors, and the trees worked by hand.

`spec/vectors/adversarial/expectiminimax-dice-race.json` holds every root
move's expected value on the dice race at depths 2 and 3, the move, and the
positions visited. `derive.py` wrote them in exact fractions, importing
nothing from here; `make test-adversarial-vectors` reads the same file
against Godot. A planted search that sees no dice -- it takes every roll as
its first face, as minimax does -- and one a ply short must fail it.

The hand trees are `expectiminimax_test.gd`'s, so that the two languages
are held to the book as well as to each other.
"""

import json
import pathlib
import unittest

from gameaikit.adversarial import AdversarialGame
from gameaikit.adversarial.expectiminimax import AdversarialResult, ExpectiminimaxSearch
from gameaikit.adversarial.toy_games import DiceRace, Nim, Pile, Race

VECTORS = pathlib.Path(__file__).resolve().parents[2] / "spec" / "vectors" / "adversarial"
FILE = "expectiminimax-dice-race.json"
TOLERANCE = 1e-9
CASE_KEYS = {"name", "state", "depth", "values", "action", "positions"}


def why_not_a_vector(vector: dict) -> str:
    """Why this is not a usable expectiminimax vector, or "" when it is one."""
    if set(vector) != {"description", "game", "cases"}:
        return f"E1 its keys are {sorted(vector)}"
    if vector["game"] != "dice_race":
        return f"E2 it names a game other than the dice race: {vector['game']}"
    if not vector["cases"]:
        return "E3 it claims nothing"
    for case in vector["cases"]:
        if set(case) != CASE_KEYS:
            return f"E4 a case's keys are {sorted(case)}, not {sorted(CASE_KEYS)}"
        if case["depth"] < 1:
            return f"E5 {case['name']}: a depth below one searches nothing"
    return ""


def wrong_claims(vector: dict, search=lambda game, state, depth: ExpectiminimaxSearch(game, state).search_to(depth)) -> list[str]:
    """Every claim in the vector the search does not meet."""
    game, wrong = DiceRace(), []
    for case in vector["cases"]:
        state = Race(tuple(case["state"]["squares"]), case["state"]["player"])
        found: AdversarialResult = search(game, state, case["depth"])
        values = [entry["value"] for entry in found.considered]
        if len(values) != len(case["values"]) or any(
                abs(mine - theirs) > TOLERANCE for mine, theirs in zip(values, case["values"])):
            wrong.append(f"{case['name']}: values {values}, not {case['values']}")
        if found.action != case["action"]:
            wrong.append(f"{case['name']}: chose {found.action}, not {case['action']}")
        if found.positions != case["positions"]:
            wrong.append(f"{case['name']}: visited {found.positions} positions, not {case['positions']}")
    return wrong


class NoDice(DiceRace):
    """The planted search's game: every roll is its first face, nothing -- what `result` says."""

    def outcomes(self, state, action):
        return [(1.0, DiceRace.outcomes(self, state, action)[0][1])]


class ChanceTree(AdversarialGame):
    """A tree written out, as `expectiminimax_test.gd`'s: a state is the path of (move, outcome)."""

    def __init__(self, tree: dict) -> None:
        self.tree = tree

    def node(self, path: tuple):
        here = self.tree
        for move, outcome in path:
            here = here["moves"][move]
            if outcome >= 0:
                here = here["chance"][outcome][1]
        return here

    def to_move(self, state):
        here = self.node(state)
        return here["player"] if isinstance(here, dict) else 0

    def actions(self, state):
        here = self.node(state)
        return list(range(len(here["moves"]))) if isinstance(here, dict) else []

    def result(self, state, action):
        return self.outcomes(state, action)[0][1]

    def outcomes(self, state, action):
        move = self.node(state)["moves"][action]
        if isinstance(move, dict) and "chance" in move:
            return [(chance, state + ((action, index),)) for index, (chance, _) in enumerate(move["chance"])]
        return [(1.0, state + ((action, -1),))]

    def is_terminal(self, state):
        return not isinstance(self.node(state), dict)

    def evaluate(self, state, player):
        here = self.node(state)
        for_max = 0.0 if isinstance(here, dict) else float(here)
        return for_max if player == 0 else -for_max


BOOK = {"player": 0, "moves": [{"chance": [[0.9, 2.0], [0.1, 3.0]]}, {"chance": [[0.9, 1.0], [0.1, 4.0]]}]}
BOOK_RESCALED = {"player": 0, "moves": [{"chance": [[0.9, 20.0], [0.1, 30.0]]}, {"chance": [[0.9, 1.0], [0.1, 400.0]]}]}
COIN = {"player": 0, "moves": [
    {"chance": [[0.5, {"player": 1, "moves": [3.0, 5.0]}], [0.5, {"player": 1, "moves": [-1.0, 7.0]}]]}, 0.8]}


class TheVectors(unittest.TestCase):
    def setUp(self) -> None:
        self.vector = json.loads((VECTORS / FILE).read_text(encoding="utf-8"))

    def test_every_claim_holds(self) -> None:
        self.assertEqual(why_not_a_vector(self.vector), "")
        self.assertGreaterEqual(len(self.vector["cases"]), 4)
        self.assertEqual(wrong_claims(self.vector), [])

    def test_a_search_that_sees_no_dice_fails(self) -> None:
        planted = lambda game, state, depth: ExpectiminimaxSearch(NoDice(), state).search_to(depth)
        self.assertNotEqual(wrong_claims(self.vector, planted), [])

    def test_a_search_one_ply_short_fails(self) -> None:
        planted = lambda game, state, depth: ExpectiminimaxSearch(game, state).search_to(depth - 1)
        self.assertNotEqual(wrong_claims(self.vector, planted), [])

    def test_a_broken_vector_is_refused(self) -> None:
        first = self.vector["cases"][0]
        self.assertIn("E1", why_not_a_vector({key: self.vector[key] for key in self.vector if key != "game"}))
        self.assertIn("E2", why_not_a_vector(dict(self.vector, game="nim")))
        self.assertIn("E3", why_not_a_vector(dict(self.vector, cases=[])))
        self.assertIn("E4", why_not_a_vector(dict(self.vector, cases=[dict(first, seed=1)])))
        self.assertIn("E5", why_not_a_vector(dict(self.vector, cases=[dict(first, depth=0)])))

    def test_a_wrong_value_move_or_count_is_caught(self) -> None:
        first = self.vector["cases"][0]
        nudged = [first["values"][0] + 1e-6] + first["values"][1:]
        self.assertNotEqual(wrong_claims(dict(self.vector, cases=[dict(first, values=nudged)])), [])
        self.assertNotEqual(wrong_claims(dict(self.vector, cases=[dict(first, action="walk")])), [])
        self.assertNotEqual(wrong_claims(dict(self.vector, cases=[dict(first, positions=1)])), [])


class TheHandTrees(unittest.TestCase):
    def search(self, tree: dict, depth: int) -> AdversarialResult:
        return ExpectiminimaxSearch(ChanceTree(tree), ()).search_to(depth)

    def test_the_books_example_takes_the_higher_expected_value(self) -> None:
        found = self.search(BOOK, 2)
        self.assertEqual(found.action, 0)
        self.assertAlmostEqual(found.considered[0]["value"], 2.1, places=12)
        self.assertAlmostEqual(found.considered[1]["value"], 1.3, places=12)

    def test_rescaling_the_leaves_without_reordering_them_changes_the_move(self) -> None:
        found = self.search(BOOK_RESCALED, 2)
        self.assertEqual(found.action, 1)
        self.assertAlmostEqual(found.value, 40.9, places=12)

    def test_min_chooses_under_each_outcome_and_the_outcomes_are_summed(self) -> None:
        found = self.search(COIN, 2)
        self.assertEqual((found.action, found.value), (0, 1.0))
        self.assertEqual(found.considered[0]["outcomes"], [(0.5, 3.0), (0.5, -1.0)])

    def test_one_ply_deep_the_sure_thing_wins(self) -> None:
        self.assertEqual(self.search(COIN, 1).action, 1)

    def test_a_finished_game_has_no_move(self) -> None:
        found = ExpectiminimaxSearch(Nim(), Pile(0, 0)).search_to(3)
        self.assertEqual((found.action, found.value, found.depth, found.positions), (None, -1.0, 0, 0))

    def test_nim_three_sticks_takes_all_three(self) -> None:
        found = ExpectiminimaxSearch(Nim(), Pile(3, 0)).search_to(3)
        self.assertEqual((found.action, found.value), (3, 1.0))


if __name__ == "__main__":
    unittest.main()
