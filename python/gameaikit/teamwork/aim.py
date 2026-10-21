"""Where on a body to aim: the zone whose shot is worth the most damage.

The tier-1 half of `godot/addons/ai_teamwork/aim_choice.gd`: aimed at a
point, a shot lands evenly in a square `spread` either side of it; a zone's
chance is how much of the square its rectangles cover, times its exposure;
the worth of aiming at a zone is every zone's chance times its multiplier,
summed. The bot aims where that is highest, the first of equal worth.
"""

from __future__ import annotations

import dataclasses

#: The least spread taken, in metres; GDScript's 32-bit Rect2 rounds below it.
SMALLEST_SPREAD = 0.001

#: A rectangle as (low x, low y, high x, high y): across, up from the feet.
Rect = tuple[float, float, float, float]


@dataclasses.dataclass
class Zone:
    """A zone of a target: its multiplier, its aim point, its rectangles and
    the share of it the shooter can see."""

    name: str
    multiplier: float
    aim: tuple[float, float]
    rects: list[Rect]
    exposure: float = 1.0


@dataclasses.dataclass
class Choice:
    """For each zone aimed at, its own chance and the shot's worth; the zone
    aimed at (-1: none), and every zone's chance from that aim."""

    own_chances: list[float]
    expected: list[float]
    aimed: int
    chances: list[float]


def _overlap(one: Rect, other: Rect) -> float:
    across = min(one[2], other[2]) - max(one[0], other[0])
    up = min(one[3], other[3]) - max(one[1], other[1])
    return max(across, 0.0) * max(up, 0.0)


def chances_from(aim: tuple[float, float], spread: float, zones: list[Zone]) -> list[float]:
    """The chance a shot aimed at `aim` lands in each zone, in their order."""
    reach = max(spread, SMALLEST_SPREAD)
    square = (aim[0] - reach, aim[1] - reach, aim[0] + reach, aim[1] + reach)
    area = (2.0 * reach) ** 2
    return [sum(_overlap(square, rect) for rect in zone.rects) / area * zone.exposure for zone in zones]


def expected_from(aim: tuple[float, float], spread: float, zones: list[Zone]) -> float:
    """The damage a shot aimed at `aim` is worth, in multipliers."""
    return sum(chance * zone.multiplier for chance, zone in zip(chances_from(aim, spread, zones), zones))


def choose(zones: list[Zone], spread: float) -> Choice:
    """Aim at each zone in turn and keep the one worth the most."""
    choice = Choice([], [], -1, [])
    best = 0.0
    for index, zone in enumerate(zones):
        chances = chances_from(zone.aim, spread, zones)
        choice.own_chances.append(chances[index])
        choice.expected.append(expected_from(zone.aim, spread, zones))
        if choice.expected[index] > best:
            best = choice.expected[index]
            choice.aimed = index
            choice.chances = chances
    return choice


def land(chances: list[float], roll: float) -> int:
    """The zone a shot with these chances lands in for `roll` in [0, 1), or -1."""
    reached = 0.0
    for index, chance in enumerate(chances):
        reached += chance
        if roll < reached:
            return index
    return -1
