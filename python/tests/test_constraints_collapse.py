"""Wave function collapse on T95's solver, held to the vectors and to what it must refuse.

The vectors in `spec/vectors/constraints/collapse/` are read from both
languages, and each side checks every claim in them against the file --
never against the other side. The claims came from neither: `derive.py`, a
script importing nothing from this repository, wrote them by the README's
rules. Three planted collapses must fail them: one that takes the cell of
most entropy, one that skips propagation, one that does not see a
contradiction.
"""

import json
import pathlib
import unittest

from gameaikit.constraints import ConstraintSolver, WaveCollapse
from gameaikit.constraints.tile_grid import cell_name, grid_problem, rows_of, weights_of, why_not_a_tile_set
from gameaikit.constraints.wave_collapse import entropy_of

REPO = pathlib.Path(__file__).resolve().parents[2]
VECTORS = REPO / "spec" / "vectors" / "constraints" / "collapse"

#: Fewer than this and something is wrong with the directory, not the vectors.
FEWEST_VECTORS = 6

VECTOR_KEYS = {"description", "tiles", "width", "height", "pinned", "seed", "attempts", "map", "collapsed",
               "restarts", "contradictions"}


def collapse_of(vector: dict, collapse_class: type = WaveCollapse) -> WaveCollapse:
    """The collapse the vector describes, recording its steps."""
    problem = grid_problem({"tiles": vector["tiles"]}, vector["width"], vector["height"], vector["pinned"])
    return collapse_class(problem, weights_of({"tiles": vector["tiles"]}), seed=vector["seed"],
                          attempts=vector["attempts"], record=True)


def why_not_a_vector(vector: dict) -> str:
    """Why this is not a usable vector, or "" when it is one."""
    if set(vector) != VECTOR_KEYS:
        return f"C1 its keys are {sorted(vector)}, not {sorted(VECTOR_KEYS)}"
    wrong_tiles = why_not_a_tile_set({"tiles": vector["tiles"]})
    if wrong_tiles:
        return f"C2 its tiles are not a tile set: {wrong_tiles}"
    names = {cell_name(x, y) for x in range(vector["width"]) for y in range(vector["height"])}
    if any(name not in names or not set(tiles) <= {t["tile"] for t in vector["tiles"]}
           for name, tiles in vector["pinned"].items()):
        return "C3 it pins a cell off the map, or to a tile not in its set"
    if len(vector["contradictions"]) != vector["restarts"]:
        return "C4 its restarts do not count the contradictions it names"
    if vector["map"] is not None and vector["restarts"] >= vector["attempts"]:
        return "C5 it has a map and no attempt left"
    if vector["map"] is not None and len(vector["collapsed"]) != len(names):
        return "C6 its map was finished without collapsing every cell"
    return ""


def wrong_claims(vector: dict, collapse: WaveCollapse) -> list[str]:
    """Every claim of the vector that `collapse` does not reproduce."""
    found = collapse.solve()
    drawn = rows_of(found, vector["width"], vector["height"]) if found is not None else None
    collapsed = collapse.chosen() if found is not None else []
    claims = [("map", drawn, vector["map"]), ("collapsed", collapsed, vector["collapsed"]),
              ("restarts", collapse.restarts, vector["restarts"]),
              ("contradictions", collapse.contradictions, vector["contradictions"])]
    return [f"{name}: {got!r}, the vector says {want!r}" for name, got, want in claims if got != want]


def vectors() -> dict[str, dict]:
    """Every vector in the directory, by file name."""
    return {path.name: json.loads(path.read_text(encoding="utf-8")) for path in sorted(VECTORS.glob("*.json"))}


class MostEntropyFirst(WaveCollapse):
    """A planted collapse: the cell of most entropy, not least."""

    def _select(self) -> str:
        unassigned = [name for name in self._order if name not in self.assignment]
        return max(unassigned, key=lambda name: (self.entropy(name), -unassigned.index(name)))


class NoPropagation(WaveCollapse):
    """A planted collapse: a tile chosen, and nothing crossed out round it."""

    def _ac3(self, arcs: list) -> bool:
        return True


class BlindToContradictions(WaveCollapse):
    """A planted collapse: a cell emptied, and the search carries on as the solver would."""

    def _revise(self, index: int, target: str) -> bool:
        return ConstraintSolver._revise(self, index, target)


class CollapseVectors(unittest.TestCase):
    def test_there_are_vectors(self) -> None:
        self.assertGreaterEqual(len(vectors()), FEWEST_VECTORS)

    def test_every_vector_is_a_vector_and_holds(self) -> None:
        for name, vector in vectors().items():
            with self.subTest(name):
                self.assertEqual(why_not_a_vector(vector), "")
                self.assertEqual(wrong_claims(vector, collapse_of(vector)), [])

    def test_a_broken_vector_is_refused_by_its_rule(self) -> None:
        sound = vectors()["three-colours-restart.json"]
        changes = [("C1", "mapp", None), ("C2", "tiles", [{"tile": "r", "weight": 0, "left_right": "", "up_down": ""}]),
                   ("C3", "pinned", {"99,0": ["r"]}), ("C4", "restarts", 2), ("C5", "attempts", 1),
                   ("C6", "collapsed", [])]
        for rule, key, value in changes:
            broken = json.loads(json.dumps(sound))
            broken[key] = value
            self.assertTrue(why_not_a_vector(broken).startswith(rule), rule)

    def test_the_cell_of_most_entropy_first_fails(self) -> None:
        vector = vectors()["squad-map-seed-1.json"]
        self.assertNotEqual(wrong_claims(vector, collapse_of(vector, MostEntropyFirst)), [])

    def test_a_collapse_that_does_not_propagate_fails(self) -> None:
        vector = vectors()["checkers-decided-by-one-cell.json"]
        self.assertNotEqual(wrong_claims(vector, collapse_of(vector, NoPropagation)), [])

    def test_a_collapse_blind_to_contradictions_fails(self) -> None:
        vector = vectors()["three-colours-restart.json"]
        self.assertNotEqual(wrong_claims(vector, collapse_of(vector, BlindToContradictions)), [])


def land() -> dict:
    """The squad's tile set, as the vectors carry it: land, river and crossings."""
    return {"tiles": vectors()["squad-map-seed-1.json"]["tiles"]}


class TileSets(unittest.TestCase):
    def test_the_land_tile_set_is_one(self) -> None:
        self.assertEqual(why_not_a_tile_set(land()), "")

    def test_adjacency_said_from_one_side_is_refused(self) -> None:
        tiles = {"tiles": [{"tile": "~", "weight": 1, "left_right": "~", "up_down": "~="},
                           {"tile": "=", "weight": 1, "left_right": "=", "up_down": ""}]}
        self.assertIn("but not", why_not_a_tile_set(tiles))

    def test_a_tile_beside_no_tile_and_a_weight_of_nothing_are_refused(self) -> None:
        self.assertIn("which is no tile", why_not_a_tile_set(
            {"tiles": [{"tile": ".", "weight": 1, "left_right": ".x", "up_down": "."}]}))
        self.assertIn("whole weight", why_not_a_tile_set(
            {"tiles": [{"tile": ".", "weight": 0, "left_right": ".", "up_down": "."}]}))
        self.assertIn("twice", why_not_a_tile_set(
            {"tiles": [{"tile": ".", "weight": 1, "left_right": ".", "up_down": "."}] * 2}))


class Entropy(unittest.TestCase):
    def test_two_equal_tiles_are_one_bit_in_nats_and_one_tile_is_none(self) -> None:
        self.assertAlmostEqual(entropy_of(["a", "b"], {"a": 1, "b": 1}), 0.6931471805599453)
        self.assertEqual(entropy_of(["a"], {"a": 5, "b": 1}), 0.0)

    def test_a_contradiction_stops_the_attempt_where_it_happened(self) -> None:
        vector = vectors()["three-colours-restart.json"]
        collapse = collapse_of(vector)
        self.assertIsNone(collapse.attempt(30))
        self.assertEqual(collapse.contradiction, "6,4")
        self.assertEqual(collapse.backtracks, 0)
        self.assertEqual([event["event"] for event in collapse.trace].count("undo"), 1)
        self.assertEqual([e["variable"] for e in collapse.trace if e["event"] == "contradiction"], ["6,4"])

    def test_a_heavier_tile_makes_a_cell_more_certain(self) -> None:
        self.assertLess(entropy_of(["a", "b"], {"a": 9, "b": 1}), entropy_of(["a", "b"], {"a": 1, "b": 1}))

    def test_the_first_collapse_is_a_cell_of_least_entropy_and_no_cell_is_undone(self) -> None:
        collapse = WaveCollapse(grid_problem(land(), 6, 4), weights_of(land()), seed=3, record=True)
        self.assertIsNotNone(collapse.solve())
        self.assertEqual(collapse.backtracks, 0)
        self.assertEqual([e for e in collapse.trace if e["event"] == "undo"], [])
        self.assertEqual(len(collapse.chosen()), 24)


if __name__ == "__main__":
    unittest.main()
