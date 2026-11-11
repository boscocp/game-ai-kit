"""Where the enemies stand while one of them attacks: rings round the
target, and a point on the right ring for each enemy.

The tier-1 half of `godot/addons/ai_teamwork/engagement_rings.gd`, read the
same way. The rings only place candidate points -- an inner ring for a
melee token holder, a waiting ring for the rest of the melee, a band for
the ranged [Dawe 2013, 28.3.1] -- and `positions.choose` picks among them:
another ring is outside the area, a point another's claim crowds is
claimed, a point with no line of sight is exposed, nearness ranks the rest.
A point behind the player's view is taken only when none in front is free.
It casts no rays: the caller fills in each point's line of sight.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field

from . import positions

INNER = "inner"
WAITING = "waiting"
RANGED = "ranged"

Vec = tuple[float, float]


@dataclass
class Ring:
    """A ring: its name, radius in metres, how many points, the first one's angle."""

    name: str
    radius: float
    count: int
    phase: float = 0.0


@dataclass
class Config:
    """The rings, the spacing no two claims come closer than, the query's weights."""

    rings: list[Ring]
    spacing: float = 1.5
    weights: positions.Weights = field(default_factory=positions.Weights)


@dataclass
class Point:
    """A point on a ring; `line_of_sight` is the caller's to fill in."""

    id: str
    ring: str
    position: Vec = (0.0, 0.0)
    line_of_sight: bool = True
    claimed_by: int = -1


def ring_for(holds_token: bool, ranged: bool) -> str:
    """The ring an enemy belongs on: a melee token holder in, the rest out, the ranged in their band."""
    if ranged:
        return RANGED
    return INNER if holds_token else WAITING


def _distance(one: Vec, other: Vec) -> float:
    return math.hypot(one[0] - other[0], one[1] - other[1])


class EngagementRings:
    """The rings round one target, their points, and who claims each."""

    def __init__(self, config: Config, at: Vec = (0.0, 0.0)) -> None:
        self.config = config
        self.points = [Point(f"{ring.name}-{index}", ring.name) for ring in config.rings for index in range(ring.count)]
        self.target = at
        self.last_choice = positions.Choice([], [], -1)
        self.place(at)

    def place(self, at: Vec) -> None:
        """Move the rings to `at`; each point keeps its id and its claim."""
        self.target = at
        index = 0
        for ring in self.config.rings:
            for step in range(ring.count):
                angle = ring.phase + math.tau * step / ring.count
                self.points[index].position = (at[0] + math.cos(angle) * ring.radius,
                                               at[1] + math.sin(angle) * ring.radius)
                index += 1

    def choose(self, enemy_id: int, ring: str, start: Vec, view_from: Vec, view_forward: Vec) -> int:
        """Claim a point on `ring` for `enemy_id`: in front of the view if one is free; its index or -1."""
        self.release(enemy_id)
        weights = self.config.weights
        found = self.candidates(enemy_id, ring, start, view_from, view_forward, True)
        self.last_choice = positions.choose(enemy_id, found, weights, True, True)
        if self.last_choice.chosen == -1:
            found = self.candidates(enemy_id, ring, start, view_from, view_forward, False)
            self.last_choice = positions.choose(enemy_id, found, weights, True, True)
        if self.last_choice.chosen != -1:
            self.points[self.last_choice.chosen].claimed_by = enemy_id
        return self.last_choice.chosen

    def release(self, enemy_id: int) -> bool:
        """Give up `enemy_id`'s claim; true when it had one."""
        for point in self.points:
            if point.claimed_by == enemy_id:
                point.claimed_by = -1
                return True
        return False

    def claim_of(self, enemy_id: int) -> int:
        """The index of the point `enemy_id` claims, or -1."""
        return next((index for index, point in enumerate(self.points) if point.claimed_by == enemy_id), -1)

    def candidates(self, enemy_id: int, ring: str, start: Vec, view_from: Vec, view_forward: Vec,
                   front_only: bool) -> list[positions.Candidate]:
        """Every point as the facts `positions.choose` weighs for `enemy_id`."""
        return [positions.Candidate(
            id=point.id, travel=_distance(start, point.position),
            threat_distance=_distance(self.target, point.position),
            covered_from_main=False, fires_on_main=self._sight(point),
            in_area=point.ring == ring and (not front_only or self._faces(point.position, view_from, view_forward)),
            claimed_by=self._crowding(enemy_id, point)) for point in self.points]

    def _crowding(self, enemy_id: int, point: Point) -> int:
        """The enemy whose claim leaves `point` too close, or -1."""
        for other in self.points:
            if other.claimed_by in (-1, enemy_id):
                continue
            if other is point or _distance(other.position, point.position) < self.config.spacing:
                return other.claimed_by
        return -1

    def _faces(self, position: Vec, view_from: Vec, view_forward: Vec) -> bool:
        """In front of the view, strictly: level with the camera is behind."""
        return (position[0] - view_from[0]) * view_forward[0] + (position[1] - view_from[1]) * view_forward[1] > 0.0

    def _sight(self, point: Point) -> bool:
        """The caller's line-of-sight fact; a hook, so a test can plant one that ignores it."""
        return point.line_of_sight
