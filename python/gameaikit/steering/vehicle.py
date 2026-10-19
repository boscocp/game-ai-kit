"""Something that steers: a point with a velocity, and two limits.

Reynolds' vehicle, crude on purpose -- no mass beyond 1, no wheels, no
drift. It may change its velocity by at most `max_force` a second and never
go faster than `max_speed`. One step is explicit Euler: the force, clamped,
changes the velocity; the velocity changes the position. Constant time.

When not to use it: anything whose turning depends on its speed or grip. The
behaviours still say where to go; a car model would say how.
"""

from __future__ import annotations

import dataclasses
from typing import Protocol

from .vector import Vec


@dataclasses.dataclass
class Vehicle:
    """Where it is, how it moves, and what it can do."""

    position: Vec
    velocity: Vec
    max_speed: float
    max_force: float

    def step(self, force: Vec, dt: float) -> None:
        """Move `dt` seconds under `force`, clamped first to what it can apply."""
        self.velocity = (self.velocity + force.limit_length(self.max_force) * dt).limit_length(self.max_speed)
        self.position = self.position + self.velocity * dt

    def speed(self) -> float:
        """How fast it is going."""
        return self.velocity.length()


class Behaviour(Protocol):
    """Anything that answers a vehicle with a force."""

    def force(self, vehicle: Vehicle) -> Vec: ...


def run(vehicle: Vehicle, behaviour: Behaviour, steps: int, dt: float) -> list[Vec]:
    """Step `vehicle` under `behaviour` `steps` times; the forces it was given."""
    forces = []
    for _ in range(steps):
        force = behaviour.force(vehicle)
        forces.append(force)
        vehicle.step(force, dt)
    return forces
