"""Steering behaviours: seek, arrive, pursue and avoid, as forces.

The tier-1 half of `ai_steering`, standard library only. The same maths as
the GDScript addon, piece for piece; `spec/vectors/steering/` holds the two
to the same trajectories.

    from gameaikit.steering import Vec, Vehicle, Arrive, run
    car = Vehicle(Vec(0, 0), Vec(0, 0), max_speed=10, max_force=20)
    run(car, Arrive(Vec(30, 0), braking_radius=8), steps=600, dt=1 / 60)
    car.position, car.speed()          # at rest, at (30, 0)

Read `vector.py`, then `vehicle.py`, then `behaviours.py`: the arithmetic,
the thing that moves, and what tells it where.
"""

from .behaviours import Arrive, Avoid, Pursue, Seek, combined, direction_to
from .vector import Vec
from .vehicle import Vehicle, run

__all__ = ["Arrive", "Avoid", "Pursue", "Seek", "Vec", "Vehicle", "combined", "direction_to", "run"]
