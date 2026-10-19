"""Steering's claims, held on the Python side.

The GDScript side holds the same three as properties over seeded starts
(`godot/test/steering_properties.gd`); these are the same questions asked
of `gameaikit.steering`, so a reader at tier 1 can run them.
"""

import math
import random
import unittest

from gameaikit.steering import Arrive, Avoid, Pursue, Seek, Vec, Vehicle, direction_to

DT = 1.0 / 60.0
#: At rest: under a thousandth of top speed, for a whole second.
REST_FRACTION = 0.001
REST_STEPS = 60


def random_start(dice: random.Random) -> tuple[Vehicle, Vec]:
    """A vehicle somewhere, moving any way, and a target somewhere else."""
    car = Vehicle(Vec(dice.uniform(-50, 50), dice.uniform(-50, 50)),
                  Vec(dice.uniform(-10, 10), dice.uniform(-10, 10)).limit_length(10.0), 10.0, 20.0)
    return car, Vec(dice.uniform(-50, 50), dice.uniform(-50, 50))


def longest_rest(car: Vehicle, behaviour, steps: int) -> int:
    """The longest run of steps the vehicle spent at rest."""
    longest = current = 0
    for _ in range(steps):
        car.step(behaviour.force(car), DT)
        current = current + 1 if car.speed() < REST_FRACTION * car.max_speed else 0
        longest = max(longest, current)
    return longest


class SteeringTests(unittest.TestCase):
    def test_arrive_comes_to_rest_inside_its_braking_radius(self) -> None:
        dice = random.Random(22)
        for trial in range(30):
            car, target = random_start(dice)
            arrive = Arrive(target, braking_radius=8.0)
            for _ in range(1800):
                car.step(arrive.force(car), DT)
            with self.subTest(trial=trial):
                self.assertLess(car.speed(), REST_FRACTION * car.max_speed)
                self.assertLess(car.position.distance_to(target), arrive.braking_radius)

    def test_seek_never_comes_to_rest(self) -> None:
        dice = random.Random(22)
        for trial in range(30):
            car, target = random_start(dice)
            with self.subTest(trial=trial):
                self.assertLess(longest_rest(car, Seek(target), 1800), REST_STEPS)

    def test_no_behaviour_asks_for_more_than_the_vehicle_can_give(self) -> None:
        car = Vehicle(Vec(1.0, 2.0), Vec(10.0, 0.0), 10.0, 20.0)
        places = [car.position, Vec(math.inf, 0.0), Vec(-math.inf, math.inf), Vec(1e300, -1e300), Vec(0.0, 0.0)]
        for place in places:
            behaviours = [Seek(place), Arrive(place, 8.0), Pursue(place, Vec(3.0, -4.0)),
                          Avoid([place], [2.0], 5.0)]
            for behaviour in behaviours:
                force = behaviour.force(car)
                with self.subTest(place=place, behaviour=type(behaviour).__name__):
                    self.assertTrue(force.is_finite())
                    self.assertLessEqual(force.length(), car.max_force * (1 + 1e-12))

    def test_a_direction_to_infinity_is_still_a_direction(self) -> None:
        self.assertEqual(direction_to(Vec(5.0, 5.0), Vec(math.inf, 7.0)), Vec(1.0, 0.0))
        self.assertEqual(direction_to(Vec(5.0, 5.0), Vec(5.0, 5.0)), Vec(0.0, 0.0))

    def test_avoid_sees_nothing_when_standing_still(self) -> None:
        car = Vehicle(Vec(0.0, 0.0), Vec(0.0, 0.0), 10.0, 20.0)
        self.assertEqual(Avoid([Vec(1.0, 0.0)], [2.0], 5.0).force(car), Vec(0.0, 0.0))


if __name__ == "__main__":
    unittest.main()
