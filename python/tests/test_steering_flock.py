"""The flock's three rules: the Python half of its vectors, and each rule alone.

`spec/vectors/steering/flock/` holds two shapes, both written by the
`derive.py` beside them, which imports nothing from this repository: one
boid with its neighbours and the forces the three rules give it, and a small
flock flying, every boid handed the whole flock -- itself included, which
each rule must skip. `godot/test/ai_steering/flock_vector.gd` reads the same
files; both check against the file, never against each other.
"""

import json
import math
import pathlib
import unittest

from gameaikit.steering import Alignment, Cohesion, Flock, Separation, Vec, Vehicle

VECTORS = pathlib.Path(__file__).resolve().parents[2] / "spec" / "vectors" / "steering" / "flock"

#: Shared with `godot/test/ai_steering/steering_vector.gd`, sized for its 32-bit floats.
TOLERANCE = 1e-3

RULES = ("separation", "alignment", "cohesion", "flock")


def vec(pair: list) -> Vec:
    """A vector from the file's `[x, y]`."""
    return Vec(float(pair[0]), float(pair[1]))


def flock_of(vector: dict) -> Flock:
    """The flock a vector describes; a field it leaves out is the library's default."""
    defaults = Flock(1.0)
    return Flock(vector["separation_radius"], vector.get("time_to_target", defaults.alignment.time_to_target),
                 tuple(vector.get("weights", defaults.weights)))


def close(found: Vec, expected: list) -> bool:
    """Both parts within the tolerance."""
    return math.isclose(found.x, expected[0], abs_tol=TOLERANCE) and math.isclose(found.y, expected[1], abs_tol=TOLERANCE)


def forces_misses(vector: dict) -> list[str]:
    """Each of the four forces this side does not reach."""
    spec = vector["boid"]
    boid = Vehicle(vec(spec["position"]), vec(spec["velocity"]), spec["max_speed"], spec["max_force"])
    flock = flock_of(vector)
    flock.see([Vehicle(vec(other["position"]), vec(other["velocity"]), 0.0, 0.0) for other in vector["neighbours"]])
    found = flock.forces(boid) + [flock.force(boid)]
    return [f"{rule} is {value}, the file says {vector['expected'][rule]}"
            for rule, value in zip(RULES, found) if not close(value, vector["expected"][rule])]


def steps_misses(vector: dict) -> list[str]:
    """Every sampled position and velocity this side does not reach."""
    boids = [Vehicle(vec(spec["position"]), vec(spec["velocity"]), vector["max_speed"], vector["max_force"])
             for spec in vector["boids"]]
    flock = flock_of(vector)
    flock.see(boids)
    samples = {sample["step"]: sample for sample in vector["samples"]}
    found_wrong = []
    for step in range(max(samples) + 1):
        if step in samples:
            found_wrong += sample_misses(step, boids, samples[step])
        forces = [flock.force(boid) for boid in boids]
        for boid, force in zip(boids, forces):
            boid.step(force, 1.0 / vector["steps_per_second"])
    return found_wrong


def sample_misses(step: int, boids: list[Vehicle], sample: dict) -> list[str]:
    """What of one sample the boids, as they are now, miss."""
    found_wrong = []
    for index, boid in enumerate(boids):
        if not close(boid.position, sample["positions"][index]):
            found_wrong.append(f"step {step} boid {index}: position is {boid.position}")
        if not close(boid.velocity, sample["velocities"][index]):
            found_wrong.append(f"step {step} boid {index}: velocity is {boid.velocity}")
    return found_wrong


def misses(vector: dict) -> list[str]:
    """Whatever this side does not reach, of either shape."""
    return forces_misses(vector) if vector["shape"] == "forces" else steps_misses(vector)


def vectors() -> dict[str, dict]:
    """Every vector, by file name, in a fixed order."""
    return {path.name: json.loads(path.read_text(encoding="utf-8")) for path in sorted(VECTORS.glob("*.json"))}


class FlockVectorTests(unittest.TestCase):
    def test_both_shapes_are_there(self) -> None:
        shapes = {vector["shape"] for vector in vectors().values()}
        self.assertEqual(shapes, {"forces", "steps"})

    def test_every_number_is_reached(self) -> None:
        for name, vector in vectors().items():
            with self.subTest(vector=name):
                self.assertEqual(misses(vector), [])

    def test_a_planted_wrong_force_and_a_planted_wrong_position_are_caught(self) -> None:
        found = vectors()
        by_hand = found["two-neighbours-by-hand.json"]
        by_hand["expected"]["cohesion"][0] += 10 * TOLERANCE
        self.assertEqual(len(misses(by_hand)), 1)
        flying = found["four-boids-flying.json"]
        flying["samples"][-1]["positions"][2][1] += 10 * TOLERANCE
        self.assertEqual(len(misses(flying)), 1)


class EachRuleAlone(unittest.TestCase):
    def setUp(self) -> None:
        self.boid = Vehicle(Vec(0.0, 0.0), Vec(5.0, 0.0), 10.0, 20.0)

    def test_a_boid_listed_among_its_own_neighbours_is_skipped(self) -> None:
        for rule in (Separation(4.0), Alignment(), Cohesion()):
            with self.subTest(rule=type(rule).__name__):
                rule.neighbours = [self.boid]
                self.assertEqual(rule.force(self.boid), Vec(0.0, 0.0))

    def test_separation_ignores_a_neighbour_on_its_radius_and_beyond(self) -> None:
        rule = Separation(4.0, [Vehicle(Vec(4.0, 0.0), Vec(0.0, 0.0), 0.0, 0.0)])
        self.assertEqual(rule.force(self.boid), Vec(0.0, 0.0))

    def test_alignment_counts_a_slow_neighbour_as_much_as_a_fast_one(self) -> None:
        slow = Alignment(neighbours=[Vehicle(Vec(9.0, 9.0), Vec(0.0, 0.1), 0.0, 0.0)])
        fast = Alignment(neighbours=[Vehicle(Vec(9.0, 9.0), Vec(0.0, 90.0), 0.0, 0.0)])
        self.assertEqual(slow.force(self.boid), fast.force(self.boid))

    def test_a_weight_of_zero_switches_a_rule_off(self) -> None:
        flock = Flock(4.0, weights=(0.0, 0.0, 1.0))
        flock.see([Vehicle(Vec(2.0, 0.0), Vec(0.0, 8.0), 0.0, 0.0)])
        self.assertEqual(flock.force(self.boid), flock.cohesion.force(self.boid))


if __name__ == "__main__":
    unittest.main()
