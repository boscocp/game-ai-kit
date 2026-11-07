"""Separation, alignment and cohesion: Reynolds' boids, as three forces.

The GDScript addon gives each rule a file and `Flock` another; here they
share one, in the same order. Each rule reads a list of neighbours it is
handed -- it never looks for them -- and keeps `GakSteeringBehaviour`'s
contract: it changes nothing, and its force is never longer than the
vehicle's `max_force`.

    separation  away from neighbours closer than a radius, harder the closer
    alignment   towards the neighbours' average heading, at top speed
    cohesion    towards the neighbours' centre, at top speed
    Flock       the three, weighted 1.5, 1 and 1, added and clamped once

Finding the neighbours is the caller's: every boid against every other is
O(n^2); a uniform grid is about O(n). Hand them in a fixed order and two runs
agree. A vehicle listed among its own neighbours is skipped.

When not to use it: a group that must arrive in order or hold a formation. A
flock has no places and no leader.
"""

from __future__ import annotations

import dataclasses

from .behaviours import SHORTEST_TIME, clamped, combined, direction_to, towards_velocity
from .vector import ZERO, Vec
from .vehicle import Vehicle
from gameaikit.techniques import technique


@dataclasses.dataclass
class Separation:
    """Each neighbour nearer than `radius` pushes straight away from itself,
    from all of `max_force` at contact down to nothing at the radius
    (Millington's linear falloff); the pushes are added and clamped. One on
    the very same point has no direction and pushes nothing."""

    radius: float
    neighbours: list[Vehicle] = dataclasses.field(default_factory=list)

    def force(self, vehicle: Vehicle) -> Vec:
        """The added pushes of the neighbours too close, clamped."""
        push = ZERO
        for other in self.neighbours:
            if other is vehicle:
                continue
            distance = vehicle.position.distance_to(other.position)
            if distance < self.radius:
                push = push + direction_to(other.position, vehicle.position) * (1.0 - distance / self.radius)
        return clamped(push * vehicle.max_force, vehicle.max_force)


@dataclasses.dataclass
class Alignment:
    """Towards the direction of the neighbours' added headings. Each
    heading is a unit vector, so a slow neighbour weighs as much as a fast
    one; the velocity wanted is at top speed, so the flock keeps flying.
    Nothing when they are still or cancel exactly. `time_to_target` is
    seek's knob."""

    time_to_target: float = 1.0
    neighbours: list[Vehicle] = dataclasses.field(default_factory=list)

    def __post_init__(self) -> None:
        self.time_to_target = max(self.time_to_target, SHORTEST_TIME)

    def force(self, vehicle: Vehicle) -> Vec:
        """Towards the average heading; none without one."""
        headings = ZERO
        for other in self.neighbours:
            if other is not vehicle:
                headings = headings + direction_to(ZERO, other.velocity)
        heading = direction_to(ZERO, headings)
        if heading == ZERO:
            return ZERO
        return towards_velocity(vehicle, heading * vehicle.max_speed, self.time_to_target)


@dataclasses.dataclass
class Cohesion:
    """Seek the neighbours' average position at top speed; nothing without
    a neighbour. Like seek, it swings through the centre."""

    time_to_target: float = 1.0
    neighbours: list[Vehicle] = dataclasses.field(default_factory=list)

    def __post_init__(self) -> None:
        self.time_to_target = max(self.time_to_target, SHORTEST_TIME)

    def force(self, vehicle: Vehicle) -> Vec:
        """Full speed towards the centre; none without a neighbour."""
        total, counted = ZERO, 0
        for other in self.neighbours:
            if other is not vehicle:
                total, counted = total + other.position, counted + 1
        if counted == 0:
            return ZERO
        desired = direction_to(vehicle.position, total / counted) * vehicle.max_speed
        return towards_velocity(vehicle, desired, self.time_to_target)


@technique("flocking", "Reynolds' boids: separation, alignment and cohesion over the neighbours each boid sees")
class Flock:
    """The three rules over one list of neighbours, weighted and added.

    `weights` are in the order separation, alignment, cohesion, set when the
    flock is made; separation weighs most by default, as in Shiffman's
    flocking example (*The Nature of Code*). A weight of zero switches a
    rule off. Set at construction and never assigned after, as on the
    GDScript side, where `check_no_training.py`'s N3 net refuses any
    assignment to `.weights` -- a caller that switches rules mid-game passes
    its own weights to `combined`.
    """

    def __init__(self, too_close: float, time_to_target: float = 1.0,
                 weights: tuple[float, float, float] = (1.5, 1.0, 1.0)) -> None:
        self.separation = Separation(too_close)
        self.alignment = Alignment(time_to_target)
        self.cohesion = Cohesion(time_to_target)
        self.weights = list(weights)

    def see(self, neighbours: list[Vehicle]) -> None:
        """Hands the same neighbours to all three rules."""
        self.separation.neighbours = neighbours
        self.alignment.neighbours = neighbours
        self.cohesion.neighbours = neighbours

    def forces(self, vehicle: Vehicle) -> list[Vec]:
        """The three rules' forces, unweighted, in the weights' order."""
        return [self.separation.force(vehicle), self.alignment.force(vehicle), self.cohesion.force(vehicle)]

    def force(self, vehicle: Vehicle) -> Vec:
        """The three forces times their weights, added, clamped once."""
        return combined(vehicle, self.forces(vehicle), self.weights)
