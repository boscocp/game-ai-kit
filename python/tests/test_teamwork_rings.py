"""Engagement rings' promises over random scenes with cover, and the planted
generators each check must reject: one that ignores the claims, one that
ignores the view and one that ignores the line of sight.

The vectors pin answers on stated scripts; these hold what must be true in
every scene. `godot/test/ai_teamwork/engagement_rings_test.gd` holds the
same promises for the GDScript side.
"""

import math
import random
import unittest

from gameaikit.teamwork import positions, rings

TRIALS = 40
STEPS = 30
MELEE = 6
RANGED = 2
PILLARS = 4
SPACING = 2.5


class IgnoresClaims(rings.EngagementRings):
    """A generator that never says a point is taken or crowded."""

    def _crowding(self, enemy_id: int, point: rings.Point) -> int:
        return -1


class IgnoresView(rings.EngagementRings):
    """A generator that calls every point in front of the camera."""

    def _faces(self, position: rings.Vec, view_from: rings.Vec, view_forward: rings.Vec) -> bool:
        return True


class IgnoresSight(rings.EngagementRings):
    """A generator that says every point sees the target."""

    def _sight(self, point: rings.Point) -> bool:
        return True


def config() -> rings.Config:
    """Inner and waiting rings close enough that a claim on one crowds the other."""
    return rings.Config(rings=[rings.Ring(rings.INNER, 2.0, 4), rings.Ring(rings.WAITING, 4.0, 10, math.pi / 10),
                               rings.Ring(rings.RANGED, 9.0, 10)],
                        spacing=SPACING, weights=positions.Weights(max_travel=40.0))


def blocked(start: rings.Vec, end: rings.Vec, pillars: list) -> bool:
    """Whether the segment from `start` to `end` passes through a pillar (centre, radius)."""
    along = (end[0] - start[0], end[1] - start[1])
    length_squared = along[0] ** 2 + along[1] ** 2
    for centre, radius in pillars:
        share = ((centre[0] - start[0]) * along[0] + (centre[1] - start[1]) * along[1]) / length_squared
        share = min(1.0, max(0.0, share))
        nearest = (start[0] + along[0] * share, start[1] + along[1] * share)
        if math.dist(nearest, centre) < radius:
            return True
    return False


def in_front(position: rings.Vec, view_from: rings.Vec, forward: rings.Vec) -> bool:
    return (position[0] - view_from[0]) * forward[0] + (position[1] - view_from[1]) * forward[1] > 0.0


def free_in_front(field: rings.EngagementRings, enemy: int, ring: str, view: tuple, pillars: list) -> bool:
    """Whether a point of `ring` is in front, seen and uncrowded -- worked out here, not by the rings."""
    others = [point.position for point in field.points if point.claimed_by not in (-1, enemy)]
    for point in field.points:
        if point.ring != ring or not in_front(point.position, *view) or blocked(point.position, field.target, pillars):
            continue
        if all(math.dist(point.position, other) >= SPACING for other in others):
            return True
    return False


def why_broken(field: rings.EngagementRings, enemy: int, ring: str, chosen: int, view: tuple, pillars: list,
               had_free_front: bool) -> str:
    """The first promise `enemy`'s choice broke, or ""."""
    claimed = [point for point in field.points if point.claimed_by != -1]
    for index, one in enumerate(claimed):
        for other in claimed[index + 1:]:
            if math.dist(one.position, other.position) < SPACING:
                return f"{one.id} and {other.id} closer than the spacing"
    if chosen == -1:
        return ""
    point = field.points[chosen]
    if ring == rings.RANGED and blocked(point.position, field.target, pillars):
        return f"ranged {enemy} at {point.id}, which cannot see the target"
    if ring == rings.WAITING and not in_front(point.position, *view) and had_free_front:
        return f"waiting {enemy} behind the camera at {point.id} with a free point in front"
    return ""


def scene(dice: random.Random) -> list:
    """Pillars round the target: (centre, radius)."""
    pillars = []
    for _ in range(PILLARS):
        angle, distance = dice.uniform(0.0, math.tau), dice.uniform(3.0, 8.0)
        pillars.append(((math.cos(angle) * distance, math.sin(angle) * distance), dice.uniform(0.5, 1.0)))
    return pillars


def fight(field: rings.EngagementRings, seed: int) -> str:
    """A random fight round one moving target; the first broken promise, or ""."""
    dice = random.Random(seed)
    pillars = scene(dice)
    standing = {enemy: (dice.uniform(-12, 12), dice.uniform(-12, 12)) for enemy in range(MELEE + RANGED)}
    heading = dice.uniform(0.0, math.tau)
    for step in range(STEPS):
        heading += dice.uniform(-0.6, 0.6)
        forward = (math.cos(heading), math.sin(heading))
        field.place((dice.uniform(-0.5, 0.5), dice.uniform(-0.5, 0.5)))
        moved = [(centre[0] + field.target[0], centre[1] + field.target[1]) for centre, _ in pillars]
        here = [(centre, radius) for centre, (_, radius) in zip(moved, pillars)]
        for point in field.points:
            point.line_of_sight = not blocked(point.position, field.target, here)
        view = ((field.target[0] - forward[0] * 3.0, field.target[1] - forward[1] * 3.0), forward)
        holders = set(dice.sample(range(MELEE), 2))
        for enemy in range(MELEE + RANGED):
            ring = rings.ring_for(enemy in holders, enemy >= MELEE)
            field.release(enemy)
            had_free_front = free_in_front(field, enemy, ring, view, here)
            chosen = field.choose(enemy, ring, standing[enemy], *view)
            why = why_broken(field, enemy, ring, chosen, view, here, had_free_front)
            if why:
                return f"seed {seed} step {step}: {why}"
            if chosen != -1:
                standing[enemy] = field.points[chosen].position
    return ""


def first_broken(kind: type) -> str:
    for trial in range(TRIALS):
        why = fight(kind(config()), trial)
        if why:
            return why
    return ""


class EngagementRingsTests(unittest.TestCase):
    def test_every_promise_holds_over_random_scenes(self) -> None:
        self.assertEqual(first_broken(rings.EngagementRings), "")

    def test_a_generator_that_ignores_the_claims_is_caught(self) -> None:
        self.assertIn("closer than the spacing", first_broken(IgnoresClaims))

    def test_a_generator_that_ignores_the_view_is_caught(self) -> None:
        self.assertIn("behind the camera", first_broken(IgnoresView))

    def test_a_generator_that_ignores_the_sight_is_caught(self) -> None:
        self.assertIn("cannot see the target", first_broken(IgnoresSight))

    def test_a_token_sends_a_melee_enemy_in_and_back_out(self) -> None:
        self.assertEqual(rings.ring_for(True, False), rings.INNER)
        self.assertEqual(rings.ring_for(False, False), rings.WAITING)
        self.assertEqual(rings.ring_for(True, True), rings.RANGED)
        self.assertEqual(rings.ring_for(False, True), rings.RANGED)

    def test_the_points_lie_on_their_rings_and_follow_the_target(self) -> None:
        field = rings.EngagementRings(config(), (3.0, -1.0))
        field.choose(1, rings.WAITING, (3.0, 6.0), (3.0, -4.0), (0.0, 1.0))
        claim = field.claim_of(1)
        field.place((5.0, 2.0))
        radius = {ring.name: ring.radius for ring in config().rings}
        for point in field.points:
            self.assertAlmostEqual(math.dist(point.position, (5.0, 2.0)), radius[point.ring])
        self.assertEqual(field.claim_of(1), claim)
        self.assertTrue(field.release(1))
        self.assertFalse(field.release(1))
        self.assertEqual(field.claim_of(1), -1)

    def test_no_point_left_is_minus_one(self) -> None:
        field = rings.EngagementRings(config())
        taken = [field.choose(enemy, rings.INNER, (0.0, 5.0), (0.0, -3.0), (0.0, 1.0)) for enemy in range(5)]
        self.assertEqual(taken[-1], -1)
        self.assertEqual(sorted(taken[:4]), [0, 1, 2, 3])


if __name__ == "__main__":
    unittest.main()
