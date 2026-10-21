"""Steering's claims, held on the Python side.

The GDScript side holds the same three as properties over seeded starts
(`godot/test/ai_steering/steering_properties.gd`); these are the same questions asked
of `gameaikit.steering`, so a reader at tier 1 can run them.
"""

import math
import random
import unittest

from gameaikit.steering import Arrive, Avoid, Pursue, Seek, Vec, Vehicle, clamped, direction_to
from gameaikit.steering.heat_line import HeatLine
from gameaikit.steering.pid import PidController

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
        # A force under twice the top speed, so seek's own clamp has work to
        # do: at 20 against 10, desired minus velocity never exceeds it.
        car = Vehicle(Vec(1.0, 2.0), Vec(10.0, 0.0), 10.0, 6.0)
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
        self.assertAlmostEqual(direction_to(Vec(0.0, 0.0), Vec(1e30, -1e30)).x, math.sqrt(0.5))

    def test_seek_on_a_weak_vehicle_asks_for_no_more_than_it_has(self) -> None:
        car = Vehicle(Vec(0.0, 0.0), Vec(0.0, -5.0), 10.0, 8.0)
        self.assertAlmostEqual(Seek(Vec(20.0, 15.0)).force(car).length(), 8.0)

    def test_an_infinite_force_is_clamped_in_its_own_direction(self) -> None:
        self.assertEqual(clamped(Vec(math.inf, 0.0), 3.0), Vec(3.0, 0.0))

    def test_avoid_turns_left_head_on_and_takes_the_first_of_two_equal_threats(self) -> None:
        car = Vehicle(Vec(0.0, 0.0), Vec(10.0, 0.0), 10.0, 20.0)
        self.assertEqual(Avoid([Vec(3.0, 0.0)], [1.0], 5.0).force(car), Vec(0.0, -20.0))
        # Two obstacles equally far along, either side of the line: the first
        # listed is the threat, and the push is away from its side.
        both = Avoid([Vec(3.0, 0.5), Vec(3.0, -0.5)], [1.0, 1.0], 5.0)
        self.assertEqual(both.force(car), Vec(0.0, -20.0))
        swapped = Avoid([Vec(3.0, -0.5), Vec(3.0, 0.5)], [1.0, 1.0], 5.0)
        self.assertEqual(swapped.force(car), Vec(0.0, 20.0))

    def test_arrive_waits_a_tenth_of_a_second_unless_told_otherwise(self) -> None:
        self.assertEqual(Arrive(Vec(0.0, 0.0), 5.0).time_to_target, 0.1)
        self.assertEqual(Arrive(Vec(0.0, 0.0), 5.0, 0.0).time_to_target, 0.001)

    def test_avoid_sees_nothing_when_standing_still(self) -> None:
        car = Vehicle(Vec(0.0, 0.0), Vec(0.0, 0.0), 10.0, 20.0)
        self.assertEqual(Avoid([Vec(1.0, 0.0)], [2.0], 5.0).force(car), Vec(0.0, 0.0))


def settle(controller: PidController, seconds: float) -> float:
    """A cart pushed towards zero against a steady pull of 0.5: where it rests."""
    where, speed = 1.0, 0.0
    for _ in range(round(seconds / DT)):
        push = controller.update(-where, DT)
        speed += (push - 0.5 - 2.0 * speed) * DT
        where += speed * DT
    return where


class PidAndHeatTests(unittest.TestCase):
    """The two pieces T54's driver adds to ai_steering, as the GDScript
    suite `godot/test/ai_steering/pid_and_heat_test.gd` asks them."""

    def test_proportional_alone_settles_off_and_the_integral_does_not(self) -> None:
        alone = PidController(2.0, 1.0, 1.0, 10.0)
        alone.proportional_only = True
        self.assertAlmostEqual(settle(alone, 30.0), -0.25, places=3)
        self.assertLess(abs(settle(PidController(2.0, 1.0, 1.0, 10.0), 30.0)), 1e-3)

    def test_the_ball_rolls_away_from_a_car(self) -> None:
        line = HeatLine()
        for _ in range(240):
            line.build(6.0, 6.0)
            line.heat_up(0.5, 3.0, 2.2)
            line.roll(DT)
        self.assertLess(line.ball, -1.5)


if __name__ == "__main__":
    unittest.main()
