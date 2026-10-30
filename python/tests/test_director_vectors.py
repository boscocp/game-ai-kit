"""The director vectors in `spec/vectors/director/`, against `gameaikit.director`.

Each vector is an event list and the intensity after every step, with every
phase change; the Python machine must reproduce them. The other half is
`make test-director-vectors`, the same files against Godot's `Director`.
Godot's copy of the numbers is held to `spec/director/director.json` byte
for byte here, because a copy that drifted would be a third director.
"""

import json
import pathlib
import unittest

from gameaikit.director import pacing

REPO = pathlib.Path(__file__).resolve().parents[2]
VECTORS = REPO / "spec" / "vectors" / "director"
GODOT_COPY = REPO / "godot" / "game3d" / "infiltration" / "director.json"
FEWEST_VECTORS = 6


class TheVectors(unittest.TestCase):
    def test_there_are_vectors_to_check(self):
        self.assertGreaterEqual(len(list(VECTORS.glob("*.json"))), FEWEST_VECTORS)

    def test_every_curve_and_change_is_the_vectors(self):
        spec = pacing.read_spec()
        for path in sorted(VECTORS.glob("*.json")):
            vector = json.loads(path.read_text())
            found = pacing.replay(spec, vector["steps"], vector["events"])
            self.assertEqual(found["changes"], vector["changes"], path.name)
            self.assertEqual(len(found["intensity"]), len(vector["intensity"]), path.name)
            for step, (value, wanted) in enumerate(zip(found["intensity"], vector["intensity"])):
                self.assertAlmostEqual(value, wanted, places=9, msg=f"{path.name}, step {step}")


class TheCopy(unittest.TestCase):
    def test_godots_numbers_are_the_spec_byte_for_byte(self):
        self.assertEqual(GODOT_COPY.read_bytes(), pacing.SPEC.read_bytes())


if __name__ == "__main__":
    unittest.main()
