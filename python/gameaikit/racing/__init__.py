"""The 3D racer's driver, without the 3D: a decision from a snapshot.

The tier-1 half of T54 (ADR 0018, invariant 5). The car, its tyres and the
track are Godot's; the decision -- how fast the road ahead allows, where to
steer, the pedals -- is a function of a `View`, what the driver perceives
in its own frame, and runs here with the standard library alone.
`spec/vectors/racing3d/` holds this and `RaceDriver3D` to the same answers.

    from gameaikit.racing import Driver, View
    driver = Driver(level, known, drift_phases)
    driver.decide(View.from_dict(snapshot))
    driver.steer, driver.throttle, driver.brake
"""

from .driver import Driver, Level, View

__all__ = ["Driver", "Level", "View"]
