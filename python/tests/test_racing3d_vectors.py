"""The Python half of the 3D driver's conformance run.

Each vector in `spec/vectors/racing3d/` is a driver -- a level, what it
knows of its car, its wander's phases -- and the snapshots it is shown one
after another, with what it must decide from each. This side decides them
with `gameaikit.racing` and checks every number against the file, never
against the GDScript side. The numbers came from neither: `derive.py`
beside the vectors is a third copy of the rules.

Both sides compute in 64-bit floats, so the tolerance is near rounding.
"""

import json
import math
import pathlib
import unittest

from gameaikit.racing import Driver, Level, View

VECTORS = pathlib.Path(__file__).resolve().parents[2] / "spec" / "vectors" / "racing3d"

#: Fewer than this and something is wrong with the directory, not the vectors.
FEWEST_VECTORS = 14

#: How far a number may stray. Shared with `godot/test/racing3d/racing3d_vector.gd`.
TOLERANCE = 1e-9

#: What each frame must decide, in the order the file writes it.
DECIDED = ["steer", "throttle", "brake", "target_speed", "braking_in", "aim_forward", "aim_left", "wanted_left"]


def answers(vector: dict) -> list[dict]:
    """What `gameaikit.racing` decides on each of the vector's frames, in turn."""
    spec = vector["driver"]
    driver = Driver(Level(**spec["level"]), spec["known"], spec["drift_phases"])
    switches = spec.get("switches", {})
    driver.full_pid = switches.get("full_pid", True)
    driver.traffic.heat_vision = switches.get("heat_vision", True)
    decided = []
    for frame in vector["frames"]:
        driver.decide(View.from_dict(frame["view"]))
        decided.append({key: getattr(driver, key) for key in DECIDED})
    return decided


def misses(vector: dict, decided: list[dict]) -> list[str]:
    """Every number this side decided that the file does not say."""
    found = []
    for index, (frame, answer) in enumerate(zip(vector["frames"], decided)):
        for key in DECIDED:
            if not math.isclose(answer[key], frame["expect"][key], rel_tol=0.0, abs_tol=TOLERANCE):
                found.append(f"{vector['name']} frame {index} {key}: {answer[key]}, the file says {frame['expect'][key]}")
    return found


def vector_files() -> list[pathlib.Path]:
    return sorted(VECTORS.glob("*.json"))


class RacingVectorTests(unittest.TestCase):
    def test_the_directory_holds_the_vectors(self) -> None:
        self.assertGreaterEqual(len(vector_files()), FEWEST_VECTORS)

    def test_every_decision_is_the_files(self) -> None:
        for path in vector_files():
            vector = json.loads(path.read_text(encoding="utf-8"))
            with self.subTest(vector=path.name):
                self.assertEqual(misses(vector, answers(vector)), [])

    def test_a_planted_wrong_decision_is_caught(self) -> None:
        # The comparison above, shown each vector's first throttle moved by
        # ten tolerances: it has to fail.
        for path in vector_files():
            vector = json.loads(path.read_text(encoding="utf-8"))
            decided = answers(vector)
            decided[0]["throttle"] += 10 * TOLERANCE
            with self.subTest(vector=path.name):
                self.assertTrue(misses(vector, decided))


if __name__ == "__main__":
    unittest.main()
