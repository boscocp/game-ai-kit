"""What the eye makes of a body: the zone it is in and how certain that is.

The tier-1 half of `godot/addons/ai_perception/vision_shape.gd`, read the
same way: the most certain zone holding the body, nothing when too few of
its points are clear, and the zone's certainty moved by light, movement
and hiding [Rabin 2015; Walsh 2015].
"""

from __future__ import annotations

import dataclasses


@dataclasses.dataclass
class Look:
    """One look at a body: where it is from the eye, and what shows of it."""

    distance: float
    angle: float
    points: list[bool]
    needed: int
    light: float
    moving: bool
    hidden: float


def zone_at(shape: dict, distance: float, angle: float) -> int:
    """The most certain zone holding the body, the earlier on a tie; -1 none."""
    best = -1
    for index, zone in enumerate(shape["zones"]):
        if not (zone["near"] <= distance < zone["far"] and abs(angle) <= zone["half_angle"]):
            continue
        if best == -1 or zone["certainty"] > shape["zones"][best]["certainty"]:
            best = index
    return best


def certainty_in(shape: dict, index: int, light: float, moving: bool, hidden: float) -> float:
    """The certainty zone `index` gives a body enough points of are seen."""
    lit = shape["dark_share"] + (1.0 - shape["dark_share"]) * _unit(light)
    shown = shape["zones"][index]["certainty"] * lit + (shape["motion_bonus"] if moving else 0.0)
    return _unit(shown * (1.0 - _unit(hidden)))


def percept(shape: dict, look: Look) -> tuple[int, float]:
    """The zone and the certainty of one look; 0 outside every zone or when
    fewer points than the stance needs are clear."""
    zone = zone_at(shape, look.distance, look.angle)
    if zone == -1 or look.points.count(True) < look.needed:
        return zone, 0.0
    return zone, certainty_in(shape, zone, look.light, look.moving, look.hidden)


def _unit(value: float) -> float:
    return min(max(value, 0.0), 1.0)
