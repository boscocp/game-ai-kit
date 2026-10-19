"""Seek, arrive, pursue and avoid: each a force from where the vehicle is.

The GDScript addon gives each one a file; here they share one, in the same
order, because each is a dozen lines. Every one keeps the contract
`SteeringBehaviour` states: it changes nothing, and the force it returns is
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


def direction_to(start: Vec, end: Vec) -> Vec:
    """The unit direction from `start` to `end`; zero when they coincide.

    An infinite offset keeps its direction: each infinite part becomes one step
    that way and the finite parts drop out, as they would at infinity. Plain
    normalising would answer zero, and a vehicle seeking the horizon would stop.
    """
    offset = end - start
    if offset.is_finite():
        return offset.normalized()
    return Vec(_towards_infinity(offset.x), _towards_infinity(offset.y)).normalized()


def _towards_infinity(part: float) -> float:
    """One step towards an infinite part, none for a finite one or NaN."""
    if math.isinf(part):
        return math.copysign(1.0, part)
    return 0.0


def towards_velocity(vehicle: Vehicle, desired: Vec) -> Vec:
    """Reynolds' steering: desired velocity minus velocity, clamped."""
    return (desired - vehicle.velocity).limit_length(vehicle.max_force)


def combined(vehicle: Vehicle, forces: list[Vec], weights: list[float]) -> Vec:
    """Each force times its weight, added, and clamped once."""
    total = ZERO
    for force, weight in zip(forces, weights):
        total = total + force * weight
    return total.limit_length(vehicle.max_force)


@dataclasses.dataclass
class Seek:
    """Full speed at `target`. Never asks for less, so never stops there."""

    target: Vec

    def force(self, vehicle: Vehicle) -> Vec:
        """Full speed towards the target."""
        return towards_velocity(vehicle, direction_to(vehicle.position, self.target) * vehicle.max_speed)


@dataclasses.dataclass
class Arrive:
    """Seek, with the desired speed falling to zero inside `braking_radius`.

    The velocity is asked to change within `time_to_target` seconds
    (Millington's form), which damps the approach so it comes to rest.
    """

    target: Vec
    braking_radius: float
    time_to_target: float = 0.1

    def force(self, vehicle: Vehicle) -> Vec:
        """Towards the target at a speed that falls as the distance does."""
        distance = vehicle.position.distance_to(self.target)
        speed = vehicle.max_speed
        if distance < self.braking_radius:
            speed *= distance / self.braking_radius
        desired = direction_to(vehicle.position, self.target) * speed
        return ((desired - vehicle.velocity) / self.time_to_target).limit_length(vehicle.max_force)


@dataclasses.dataclass
class Pursue:
    """Seek where the quarry will be: its velocity times the chase's length,
    never more than `max_prediction` seconds ahead."""

    quarry_position: Vec
    quarry_velocity: Vec
    max_prediction: float = 1.0

    def predicted(self, vehicle: Vehicle) -> Vec:
        """Where the quarry will be when the chase arrives."""
        seconds = self.max_prediction
        if vehicle.max_speed > 0.0:
            seconds = min(vehicle.position.distance_to(self.quarry_position) / vehicle.max_speed,
                          self.max_prediction)
        return self.quarry_position + self.quarry_velocity * seconds

    def force(self, vehicle: Vehicle) -> Vec:
        """Seek, aimed at the prediction."""
        return Seek(self.predicted(vehicle)).force(vehicle)


@dataclasses.dataclass
class Avoid:
    """Swerve at full force from the first round obstacle within `look_ahead`
    (less as the vehicle slows); head-on, to the left; nothing when still."""

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
        closest = _closest_on_stretch(vehicle.position, heading, reach, self.centres[threat])
        away = (closest - self.centres[threat]).normalized()
        if away == ZERO:
            away = Vec(heading.y, -heading.x)
        return away * vehicle.max_force

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
