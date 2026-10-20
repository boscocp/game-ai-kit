"""The Python half of the steering conformance run.

The vectors in `spec/vectors/steering/` pin the trajectory a behaviour
produces from a stated start: at each sampled step, where the vehicle is,
how it moves, and the force it is about to be given. Both languages replay
them and check every number against the file, never against each other. The
numbers came from neither: `derive.py` beside them is a third copy of the
maths, importing nothing from this repository.

The tolerance is sized for the GDScript side, whose `Vector2` holds 32-bit
floats (`docs/godot/vector2-is-single-precision.md`); this side, in 64-bit
floats, lands far closer than it needs to.
"""

import json
import math
import pathlib
import unittest

from gameaikit.steering import Arrive, Avoid, Pursue, Seek, Vec, Vehicle, combined

VECTORS = pathlib.Path(__file__).resolve().parents[2] / "spec" / "vectors" / "steering"

#: Fewer than this and something is wrong with the directory, not the vectors.
FEWEST_VECTORS = 5

#: How far a number may stray, in the vector's own units. Shared with
#: `godot/test/ai_steering/steering_vector.gd`.
TOLERANCE = 1e-3

#: Every key a behaviour of each kind may carry; a misspelt one is refused
#: rather than ignored, or `"braking_raduis"` would quietly fall back to nothing.
BEHAVIOUR_KEYS = {
    "seek": {"kind", "weight", "target"},
    "arrive": {"kind", "weight", "target", "braking_radius", "time_to_target"},
    "pursue": {"kind", "weight", "quarry", "max_prediction"},
    "avoid": {"kind", "weight", "centres", "radii", "look_ahead"},
}


def vec(pair: list) -> Vec:
    """A vector from the file's `[x, y]`."""
    return Vec(float(pair[0]), float(pair[1]))


def behaviour(spec: dict):
    """The behaviour a vector names, built from its fields."""
    kind = spec["kind"]
    # A field the file leaves out goes to the library's own default, so the
    # vectors pin the default too.
    optional = {key: spec[key] for key in ("time_to_target", "max_prediction") if key in spec}
    if kind == "seek":
        return Seek(vec(spec["target"]))
    if kind == "arrive":
        return Arrive(vec(spec["target"]), spec["braking_radius"], **optional)
    if kind == "pursue":
        quarry = spec["quarry"]
        return Pursue(vec(quarry["position"]), vec(quarry["velocity"]), **optional)
    return Avoid([vec(c) for c in spec["centres"]], [float(r) for r in spec["radii"]], spec["look_ahead"])


def replay(vector: dict) -> dict[int, tuple[Vec, Vec, Vec]]:
    """Every sampled step's position, velocity and force, as this side plays it."""
    start = vector["vehicle"]
    car = Vehicle(vec(start["position"]), vec(start["velocity"]), start["max_speed"], start["max_force"])
    behaviours = [behaviour(spec) for spec in vector["behaviours"]]
    weights = [float(spec.get("weight", 1.0)) for spec in vector["behaviours"]]
    dt = 1.0 / vector["steps_per_second"]
    wanted = {sample["step"] for sample in vector["samples"]}
    played = {}
    for step in range(max(wanted) + 1):
        force = combined(car, [each.force(car) for each in behaviours], weights)
        if step in wanted:
            played[step] = (car.position, car.velocity, force)
        car.step(force, dt)
        for each in behaviours:
            if isinstance(each, Pursue):
                each.quarry_position = each.quarry_position + each.quarry_velocity * dt
    return played


def misses(vector: dict) -> list[str]:
    """Every sampled number this side does not reach, as a line saying which."""
    played = replay(vector)
    found_wrong = []
    for sample in vector["samples"]:
        found = played[sample["step"]]
        for label, value in zip(("position", "velocity", "force"), found):
            expected = sample[label]
            if not (math.isclose(value.x, expected[0], abs_tol=TOLERANCE)
                    and math.isclose(value.y, expected[1], abs_tol=TOLERANCE)):
                found_wrong.append(f"step {sample['step']}: {label} is {value}, the file says {expected}")
    return found_wrong


def vector_files() -> list[pathlib.Path]:
    """Every vector, in a fixed order."""
    return sorted(VECTORS.glob("*.json"))


class SteeringVectorTests(unittest.TestCase):
    def test_the_directory_holds_the_vectors(self) -> None:
        self.assertGreaterEqual(len(vector_files()), FEWEST_VECTORS)

    def test_every_behaviour_names_only_keys_it_knows(self) -> None:
        for path in vector_files():
            for spec in json.loads(path.read_text(encoding="utf-8"))["behaviours"]:
                with self.subTest(vector=path.name, kind=spec.get("kind")):
                    self.assertIn(spec.get("kind"), BEHAVIOUR_KEYS)
                    self.assertLessEqual(set(spec), BEHAVIOUR_KEYS[spec["kind"]])

    def test_every_sample_is_reached(self) -> None:
        for path in vector_files():
            vector = json.loads(path.read_text(encoding="utf-8"))
            with self.subTest(vector=path.name):
                self.assertEqual(misses(vector), [])

    def test_a_planted_wrong_number_is_caught(self) -> None:
        # The same comparison the test above makes, shown a sample moved by
        # ten times the tolerance: it has to fail.
        vector = json.loads(vector_files()[0].read_text(encoding="utf-8"))
        vector["samples"][-1]["position"][0] += 10 * TOLERANCE
        self.assertEqual(len(misses(vector)), 1)


if __name__ == "__main__":
    unittest.main()
