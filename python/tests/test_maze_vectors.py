"""The maze vectors in `spec/vectors/maze/`, against `gameaikit.maze`.

Each vector is a seed, the ghosts and Pac-Man's moves, and the snapshot
after every step; the Python game must reproduce every snapshot. The other
half is `make test-maze-vectors`, the same files against `godot/game/maze/`.
The rules' copies are held to `spec/maze/` byte for byte here too, the
package's and the game's, because a copy that drifted would be a third
set of rules.
"""

import json
import pathlib
import unittest

from gameaikit.maze import game

REPO = pathlib.Path(__file__).resolve().parents[2]
VECTORS = REPO / "spec" / "vectors" / "maze"
SPEC = REPO / "spec" / "maze"
COPIES = (REPO / "python" / "gameaikit" / "maze", REPO / "godot" / "game" / "maze")
FEWEST_VECTORS = 8


class TheVectors(unittest.TestCase):
    def test_there_are_vectors_to_check(self):
        self.assertGreaterEqual(len(list(VECTORS.glob("*.json"))), FEWEST_VECTORS)

    def test_every_snapshot_is_the_vectors(self):
        for path in sorted(VECTORS.glob("*.json")):
            vector = json.loads(path.read_text())
            trace = json.loads(json.dumps(game.replay(vector["seed"], vector["moves"], vector["ghosts"])))
            self.assertEqual(len(trace), len(vector["trace"]), path.name)
            for index, (found, wanted) in enumerate(zip(trace, vector["trace"])):
                self.assertEqual(found, wanted, f"{path.name}, after move {index}")


class TheCopies(unittest.TestCase):
    def test_every_copy_is_the_spec_byte_for_byte(self):
        for name in ("maze.json", "rules.json"):
            for folder in COPIES:
                self.assertEqual((folder / name).read_bytes(), (SPEC / name).read_bytes(), folder / name)


if __name__ == "__main__":
    unittest.main()
