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
#: `godot/test/steering_vector.gd`.
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
    if kind == "seek":
        return Seek(vec(spec["target"]))
    if kind == "arrive":
        return Arrive(vec(spec["target"]), spec["braking_radius"], spec.get("time_to_target", 0.1))
    if kind == "pursue":
        quarry = spec["quarry"]
        return Pursue(vec(quarry["position"]), vec(quarry["velocity"]), spec.get("max_prediction", 1.0))
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
            played = replay(vector)
            for sample in vector["samples"]:
                found = played[sample["step"]]
                for label, value, expected in zip(("position", "velocity", "force"), found,
                                                  (sample["position"], sample["velocity"], sample["force"])):
                    with self.subTest(vector=path.name, step=sample["step"], value=label):
                        self.assertTrue(math.isclose(value.x, expected[0], abs_tol=TOLERANCE)
                                        and math.isclose(value.y, expected[1], abs_tol=TOLERANCE),
                                        f"{value} is not {expected}")

    def test_a_planted_wrong_number_is_caught(self) -> None:
        # The tolerance must not swallow a real difference: a sample moved by
        # ten times the tolerance has to fail.
        path = vector_files()[0]
        vector = json.loads(path.read_text(encoding="utf-8"))
        last = vector["samples"][-1]
        found = replay(vector)[last["step"]][0]
        self.assertFalse(math.isclose(found.x, last["position"][0] + 10 * TOLERANCE, abs_tol=TOLERANCE))


if __name__ == "__main__":
    unittest.main()
