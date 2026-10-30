"""Seek, arrive, pursue and avoid: each a force from where the vehicle is.

The GDScript addon gives each one a file; here they share one, in the same
order, because each is a dozen lines. Every one keeps the contract
`GakSteeringBehaviour` states: it changes nothing, and the force it returns is
never longer than the vehicle's `max_force`.

    seek     full speed at a point -- and through it, forever
    arrive   seek, slowing inside a braking radius, so it stops
    pursue   seek where a moving quarry will be
    avoid    swerve from the first round obstacle ahead

`combined` is the weighted sum that puts them together, clamped once.
"""

from __future__ import annotations

import dataclasses
import math

from .vector import ZERO, Vec
from .vehicle import Vehicle
from gameaikit.techniques import technique


def direction_to(start: Vec, end: Vec) -> Vec:
    """The unit direction from `start` to `end`; zero when they coincide.

    A finite offset is first divided by its larger part, as the GDScript side
    must to keep a 32-bit length from overflowing; the two then agree. An
    infinite offset keeps its direction: each infinite part becomes one step
    that way and the finite parts drop out, as they would at infinity.
    """
    offset = end - start
    if not offset.is_finite():
        return Vec(_towards_infinity(offset.x), _towards_infinity(offset.y)).normalized()
    larger = max(abs(offset.x), abs(offset.y))
    if larger == 0.0:
        return ZERO
    return (offset / larger).normalized()


def _towards_infinity(part: float) -> float:
    """One step towards an infinite part, none for a finite one or NaN."""
    if math.isinf(part):
        return math.copysign(1.0, part)
    return 0.0


def clamped(force: Vec, limit: float) -> Vec:
    """`force`, shortened to `limit` if longer; an infinite one is as long as
    it can be, in its own direction."""
    if not force.is_finite():
        return direction_to(ZERO, force) * limit
    return force.limit_length(limit)


SHORTEST_TIME = 0.001
"""The shortest `time_to_target` taken. It only keeps zero (or less) from
dividing by zero; under half a frame each step overshoots the velocity wanted
and the next swings back -- it chatters, bounded only by `max_force`."""


def towards_velocity(vehicle: Vehicle, desired: Vec, time_to_target: float = 1.0) -> Vec:
    """Reynolds' steering, desired velocity minus velocity, divided by
    `time_to_target` (Millington's form) and clamped. The time is a time
    constant: unclamped, about two-thirds of the gap closes in it. The
    default second is what the gap alone meant here, since `Vehicle.step`
    adds force times seconds. The same at any frame rate while the time is
    several frames long; under half a frame it chatters."""
    return clamped((desired - vehicle.velocity) / max(time_to_target, SHORTEST_TIME), vehicle.max_force)


def combined(vehicle: Vehicle, forces: list[Vec], weights: list[float]) -> Vec:
    """Each force times its weight, added, and clamped once."""
    total = ZERO
    for force, weight in zip(forces, weights):
        total = total + force * weight
    return clamped(total, vehicle.max_force)


@technique("seek", "full speed at a point, a force no longer than the vehicle's max_force")
@dataclasses.dataclass
class Seek:
    """Full speed at `target`. Never asks for less, so never stops there.

    `time_to_target` is a time constant, the same knob as arrive's: about
    two-thirds of the gap to the velocity wanted closes in it. A second by
    default, what seek always was here; a tenth for a car that must hold a
    line. Floored at `SHORTEST_TIME`.
    """

    target: Vec
    time_to_target: float = 1.0

    def __post_init__(self) -> None:
        self.time_to_target = max(self.time_to_target, SHORTEST_TIME)

    def force(self, vehicle: Vehicle) -> Vec:
        """Full speed towards the target."""
        desired = direction_to(vehicle.position, self.target) * vehicle.max_speed
        return towards_velocity(vehicle, desired, self.time_to_target)


@technique("arrive", "seek, slowing inside a braking radius, so it stops")
@dataclasses.dataclass
class Arrive:
    """Seek, with the desired speed falling to zero inside `braking_radius`.

    The gap to the velocity wanted is divided by `time_to_target`, a time
    constant (Millington's form), which damps the approach so it comes to rest -- and
    asks harder than seek outside the radius too. Never under a thousandth of
    a second, which would divide by zero.
    """

    target: Vec
    braking_radius: float
    time_to_target: float = 0.1

    def __post_init__(self) -> None:
        self.time_to_target = max(self.time_to_target, SHORTEST_TIME)

    def force(self, vehicle: Vehicle) -> Vec:
        """Towards the target at a speed that falls as the distance does."""
        distance = vehicle.position.distance_to(self.target)
        speed = vehicle.max_speed
        if distance < self.braking_radius:
            speed *= distance / self.braking_radius
        desired = direction_to(vehicle.position, self.target) * speed
        return towards_velocity(vehicle, desired, self.time_to_target)


@technique("pursue", "seek where a moving quarry will be")
@dataclasses.dataclass
class Pursue:
    """Seek where the quarry will be: its velocity times the chase's length,
    never more than `max_prediction` seconds ahead. `time_to_target` is
    handed on to that seek, floored at `SHORTEST_TIME` as Seek's is."""

    quarry_position: Vec
    quarry_velocity: Vec
    max_prediction: float = 1.0
    time_to_target: float = 1.0

    def __post_init__(self) -> None:
        self.time_to_target = max(self.time_to_target, SHORTEST_TIME)

    def predicted(self, vehicle: Vehicle) -> Vec:
        """Where the quarry will be when the chase arrives."""
        seconds = self.max_prediction
        if vehicle.max_speed > 0.0:
            seconds = min(vehicle.position.distance_to(self.quarry_position) / vehicle.max_speed,
                          self.max_prediction)
        return self.quarry_position + self.quarry_velocity * seconds

    def force(self, vehicle: Vehicle) -> Vec:
        """Seek, aimed at the prediction."""
        return Seek(self.predicted(vehicle), self.time_to_target).force(vehicle)


@technique("avoid", "swerve from the first round obstacle ahead")
@dataclasses.dataclass
class Avoid:
    """Swerve sideways at full force from the first round obstacle within
    `look_ahead` (less as the vehicle slows; the first listed on a tie), to
    the side of the line its centre is not on; head-on, to the left; nothing
    when still. Only sideways: a push back would stall it in front -- so it
    never brakes, and `look_ahead` must be long enough to swerve in."""

    centres: list[Vec]
    radii: list[float]
    look_ahead: float

    def force(self, vehicle: Vehicle) -> Vec:
        """Full force away from the first obstacle ahead, or none."""
        heading = vehicle.velocity.normalized()
        if heading == ZERO or vehicle.max_speed <= 0.0:
            return ZERO
        reach = self.look_ahead * min(vehicle.speed() / vehicle.max_speed, 1.0)
        threat = self._first_threat(vehicle.position, heading, reach)
        if threat < 0:
            return ZERO
        from_centre = vehicle.position - self.centres[threat]
        across = from_centre - heading * from_centre.dot(heading)
        if across.length() < 1e-6:
            across = Vec(heading.y, -heading.x)
        return across.normalized() * vehicle.max_force

    def _first_threat(self, start: Vec, heading: Vec, reach: float) -> int:
        """The index of the obstacle the stretch ahead meets first, or -1."""
        first, first_along = -1, math.inf
        for index, centre in enumerate(self.centres):
            closest = _closest_on_stretch(start, heading, reach, centre)
            along = (closest - start).dot(heading)
            if closest.distance_to(centre) <= self.radii[index] and along < first_along:
                first, first_along = index, along
        return first


def _closest_on_stretch(start: Vec, heading: Vec, reach: float, centre: Vec) -> Vec:
    """The point of the stretch from `start`, `reach` long, nearest `centre`."""
    return start + heading * min(max((centre - start).dot(heading), 0.0), reach)
