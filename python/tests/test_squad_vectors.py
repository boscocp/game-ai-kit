"""The squad vectors in `spec/vectors/squad/`, against `gameaikit.squad.shot`.

Each vector is a map, a shooter, a target and a die; the Python shot must
come to the cover, the flank, the chance and the health the vector wrote
down by hand. The other half is `make test-squad-vectors`, the same files
against `godot/game/squad/`. The rules' copies are held to
`spec/squad/rules.json` byte for byte here, the package's and the game's,
because a copy that drifted would be a third set of rules.
"""

import json
import pathlib
import unittest

from gameaikit.squad import shot

REPO = pathlib.Path(__file__).resolve().parents[2]
VECTORS = REPO / "spec" / "vectors" / "squad"
SPEC = REPO / "spec" / "squad" / "rules.json"
COPIES = (REPO / "python" / "gameaikit" / "squad" / "rules.json", REPO / "godot" / "game" / "squad" / "rules.json")
FEWEST_VECTORS = 12


def outcome(vector: dict) -> dict:
    """What the Python shot makes of one vector, in the vector's own fields."""
    shooter, target = vector["shooter"], vector["target"]
    covered = shot.cover_of(vector["map"], tuple(shooter["cell"]), tuple(target["cell"]))
    inputs = shot.inputs_for(shooter["type"], target["type"], covered["cover"], target["health"])
    fired = shot.shot(inputs, vector["roll"])
    return {**covered, **fired}


class TheVectors(unittest.TestCase):
    def test_there_are_vectors_to_check(self):
        self.assertGreaterEqual(len(list(VECTORS.glob("*.json"))), FEWEST_VECTORS)

    def test_every_shot_is_the_vectors(self):
        for path in sorted(VECTORS.glob("*.json")):
            vector = json.loads(path.read_text())
            self.assertEqual(outcome(vector), vector["expected"], path.name)


class TheRules(unittest.TestCase):
    def test_the_chance_is_clamped_both_ways(self):
        self.assertEqual(shot.hit_chance(30, 20, 40), 0)
        self.assertEqual(shot.hit_chance(150, 0, 0), 100)

    def test_a_die_equal_to_the_chance_misses(self):
        fired = shot.shot({"aim": 50, "defence": 0, "cover": 0, "damage": 3, "target_health": 5}, 50)
        self.assertFalse(fired["hit"])

    def test_the_cover_numbers_are_ufopaedias(self):
        self.assertEqual(shot.RULES["cover"], {"half": 20, "full": 40})


class TheCopies(unittest.TestCase):
    def test_every_copy_is_the_spec_byte_for_byte(self):
        for copy in COPIES:
            self.assertEqual(copy.read_bytes(), SPEC.read_bytes(), copy)


if __name__ == "__main__":
    unittest.main()
