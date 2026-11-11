"""Engagement rings' promises over random scenes with cover, and the planted
generators each check must reject: one that ignores the claims, the view,
or the line of sight; one where nothing gives way to a token holder; one
that drops a point for being far.

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
#: Where the enemies start: far enough that the default 20 m `max_travel`
#: would drop the front points of a ring.
SPAWN = 30.0


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


class NothingGivesWay(rings.EngagementRings):
    """A generator where a waiting claim keeps a token holder out of the inner ring."""

    def _gives_way(self, claim: rings.Point, point: rings.Point) -> bool:
        return False


class DropsFarPoints(rings.EngagementRings):
    """A generator that keeps the config's `max_travel`, so a far front point is dropped."""

    def _weights_reaching(self, start: rings.Vec) -> positions.Weights:
        return self.config.weights


def config() -> rings.Config:
    """Inner and waiting rings close enough that a claim on one crowds the other; default weights."""
    return rings.Config(rings=[rings.Ring(rings.INNER, 2.0, 4), rings.Ring(rings.WAITING, 4.0, 10, math.pi / 10),
                               rings.Ring(rings.RANGED, 9.0, 10)], spacing=SPACING)


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


def free_points(field: rings.EngagementRings, enemy: int, ring: str, pillars: list, view: tuple | None) -> list[str]:
    """The points of `ring` in sight and uncrowded -- and in front, given `view` -- worked out here.

    A claim crowds within the spacing, on any ring, except that only inner
    claims keep an enemy out of the inner ring: a token holder's right of way.
    """
    others = [point for point in field.points if point.claimed_by not in (-1, enemy)]
    if ring == rings.INNER:
        others = [point for point in others if point.ring == rings.INNER]
    return [point.id for point in field.points
            if point.ring == ring and not blocked(point.position, field.target, pillars)
            and (view is None or in_front(point.position, *view))
            and all(math.dist(point.position, other.position) >= SPACING for other in others)]


def too_close(field: rings.EngagementRings) -> str:
    """Two claims closer than the spacing, named, or ""."""
    claimed = [point for point in field.points if point.claimed_by != -1]
    for index, one in enumerate(claimed):
        for other in claimed[index + 1:]:
            if math.dist(one.position, other.position) < SPACING:
                return f"{one.id} and {other.id} closer than the spacing"
    return ""


def wrong_place(field: rings.EngagementRings, ring: str, chosen: int, pillars: list, view: tuple,
                free: list, free_front: list) -> str:
    """Why `chosen` breaks a promise, or "": a -1 must have had nothing free."""
    if chosen == -1:
        return f"got no {ring} point while {free[0]} is free" if free else ""
    point = field.points[chosen]
    if ring == rings.RANGED and blocked(point.position, field.target, pillars):
        return f"ranged at {point.id}, which cannot see the target"
    if not in_front(point.position, *view) and free_front:
        return f"{ring} behind the camera at {point.id} with {free_front[0]} free in front"
    return ""


def scene(dice: random.Random) -> list:
    """Pillars round the target: (offset from it, radius)."""
    pillars = []
    for _ in range(PILLARS):
        angle, distance = dice.uniform(0.0, math.tau), dice.uniform(3.0, 8.0)
        pillars.append(((math.cos(angle) * distance, math.sin(angle) * distance), dice.uniform(0.5, 1.0)))
    return pillars


def fight(field: rings.EngagementRings, seed: int, counts: dict | None = None) -> str:
    """A random fight round one moving target; the first broken promise, or "".

    `counts` gets how many choices were made and how many came back -1.
    """
    dice, counts = random.Random(seed), {} if counts is None else counts
    offsets = scene(dice)
    standing = {enemy: (dice.uniform(-SPAWN, SPAWN), dice.uniform(-SPAWN, SPAWN)) for enemy in range(MELEE + RANGED)}
    heading = dice.uniform(0.0, math.tau)
    for step in range(STEPS):
        heading += dice.uniform(-0.6, 0.6)
        forward = (math.cos(heading), math.sin(heading))
        field.place((dice.uniform(-0.5, 0.5), dice.uniform(-0.5, 0.5)))
        pillars = [((centre[0] + field.target[0], centre[1] + field.target[1]), radius) for centre, radius in offsets]
        for point in field.points:
            point.line_of_sight = not blocked(point.position, field.target, pillars)
        view = ((field.target[0] - forward[0] * 3.0, field.target[1] - forward[1] * 3.0), forward)
        holders = set(dice.sample(range(MELEE), 2))
        for enemy in range(MELEE + RANGED):
            ring = rings.ring_for(enemy in holders, enemy >= MELEE)
            field.release(enemy)
            free = free_points(field, enemy, ring, pillars, None)
            free_front = free_points(field, enemy, ring, pillars, view)
            chosen = field.choose(enemy, ring, standing[enemy], *view)
            counts["choices"] = counts.get("choices", 0) + 1
            counts["none"] = counts.get("none", 0) + (chosen == -1)
            why = too_close(field) or wrong_place(field, ring, chosen, pillars, view, free, free_front)
            if why:
                return f"seed {seed} step {step}: enemy {enemy}: {why}"
            if chosen != -1:
                standing[enemy] = field.points[chosen].position
    return ""


def first_broken(kind: type, counts: dict | None = None) -> str:
    for trial in range(TRIALS):
        why = fight(kind(config()), trial, counts)
        if why:
            return why
    return ""


class EngagementRingsTests(unittest.TestCase):
    def test_every_promise_holds_over_random_scenes(self) -> None:
        counts: dict = {}
        self.assertEqual(first_broken(rings.EngagementRings, counts), "")
        # The promises were asked of every choice, and most found a point.
        self.assertEqual(counts["choices"], TRIALS * STEPS * (MELEE + RANGED))
        self.assertLess(counts["none"], counts["choices"] // 10)

    def test_a_generator_that_ignores_the_claims_is_caught(self) -> None:
        self.assertIn("closer than the spacing", first_broken(IgnoresClaims))

    def test_a_generator_that_ignores_the_view_is_caught(self) -> None:
        self.assertIn("behind the camera", first_broken(IgnoresView))

    def test_a_generator_that_ignores_the_sight_is_caught(self) -> None:
        self.assertIn("cannot see the target", first_broken(IgnoresSight))

    def test_a_token_holder_kept_out_by_a_waiter_is_caught(self) -> None:
        self.assertIn("got no inner point", first_broken(NothingGivesWay))

    def test_a_generator_that_drops_far_points_is_caught(self) -> None:
        self.assertRegex(first_broken(DropsFarPoints), "behind the camera|got no")

    def test_a_token_sends_a_melee_enemy_in_and_back_out(self) -> None:
        self.assertEqual(rings.ring_for(True, False), rings.INNER)
        self.assertEqual(rings.ring_for(False, False), rings.WAITING)
        self.assertEqual(rings.ring_for(True, True), rings.RANGED)
        self.assertEqual(rings.ring_for(False, True), rings.RANGED)

    def test_the_points_lie_on_their_rings_and_follow_the_target(self) -> None:
        field = rings.EngagementRings(config(), (3.0, -1.0))
        self.assertNotEqual(field.choose(1, rings.WAITING, (3.0, 6.0), (3.0, -4.0), (0.0, 1.0)), -1)
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

    def test_a_holder_bumps_the_waiter_beside_its_point(self) -> None:
        field = rings.EngagementRings(config())
        waiting = field.choose(1, rings.WAITING, (4.0, 1.0), (0.0, -3.0), (0.0, 1.0))
        self.assertEqual(field.points[waiting].id, "waiting-0")
        self.assertEqual(field.points[field.choose(2, rings.INNER, (4.0, 1.0), (0.0, -3.0), (0.0, 1.0))].id, "inner-0")
        self.assertEqual(field.last_bumped, [1])
        self.assertEqual(field.claim_of(1), -1)

    def test_the_view_is_told_apart_from_the_ring(self) -> None:
        field = rings.EngagementRings(config())
        field.choose(1, rings.WAITING, (0.0, 6.0), (0.0, -3.0), (0.0, 1.0))
        behind = {point.id for point, back in zip(field.points, field.last_behind) if back}
        self.assertEqual(behind, {"waiting-6", "waiting-7", "waiting-8", "ranged-6", "ranged-7", "ranged-8", "ranged-9"})


if __name__ == "__main__":
    unittest.main()
