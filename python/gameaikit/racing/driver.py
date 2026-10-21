"""`RaceDriver3D`, line for line: the decision a 3D driver makes each frame.

Read `godot/game3d/racing/race_driver_3d.gd` for why each step is there; this
file is the same steps in the same order, so a reader can check one against
the other and the vectors can hold them to the same numbers.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field

#: Points either side of a point the bend there is measured over.
BEND_REACH = 2
#: How wide a car is taken to be when asking whether one is in the way.
CAR_WIDTH = 2.2
#: Metres beyond its braking distance a car ahead is followed from.
FOLLOW_MARGIN = 15.0
#: Pedal per metre a second the car is off the speed it wants.
PEDAL_GAIN = 0.5
#: Radians of steering added per metre the car is off the line it wants.
STEER_GAIN = 0.04
#: The nearest the aimed-at point comes, in metres.
MIN_AIM = 8.0
#: Metres of tarmac the aimed-at point keeps from either edge.
AIM_MARGIN = 1.0


@dataclass
class Level:
    """A difficulty: T23's three knobs."""

    title: str
    lookahead: float
    grip_margin: float
    wander: float


@dataclass
class View:
    """What a driver perceives on one frame, in its own frame."""

    time: float
    step: float
    speed: float
    cross_track: float
    line_forward: list[float]
    line_left: list[float]
    room_left: list[float]
    room_right: list[float]
    rivals: list[list[float]] = field(default_factory=list)

    @staticmethod
    def from_dict(values: dict) -> "View":
        """A view from the shape `RaceView3D.to_dictionary` writes."""
        return View(float(values["time"]), float(values["step"]), float(values["speed"]),
                    float(values["cross_track"]), [float(v) for v in values["line_forward"]],
                    [float(v) for v in values["line_left"]], [float(v) for v in values["room_left"]],
                    [float(v) for v in values["room_right"]],
                    [[float(v) for v in rival] for rival in values["rivals"]])


def clamp(value: float, low: float, high: float) -> float:
    """`value` held between `low` and `high`, as GDScript's clampf."""
    return max(low, min(high, value))


def lerp(start: float, end: float, share: float) -> float:
    """GDScript's lerpf."""
    return start + (end - start) * share


def distance(view: View, first: int, second: int) -> float:
    """Metres between two points of the view's line."""
    forward = view.line_forward[second] - view.line_forward[first]
    left = view.line_left[second] - view.line_left[first]
    return math.sqrt(forward * forward + left * left)


def bend_at(view: View, index: int) -> float:
    """The line's curvature at point `index`, positive to the left."""
    middle = min(max(index, BEND_REACH), len(view.line_forward) - 1 - BEND_REACH)
    before, after = middle - BEND_REACH, middle + BEND_REACH
    f, l = view.line_forward, view.line_left
    turned = (f[middle] - f[before]) * (l[after] - l[middle]) - (l[middle] - l[before]) * (f[after] - f[middle])
    sides = distance(view, before, middle) * distance(view, middle, after) * distance(view, before, after)
    return 2.0 * turned / sides if sides > 0.0 else 0.0


def pursuit_steer(forward: float, left: float, axles: float) -> float:
    """The wheel angle for the arc through (forward, left): pure pursuit."""
    reach = math.sqrt(forward * forward + left * left)
    if reach <= 0.0:
        return 0.0
    return math.atan(axles * 2.0 * math.sin(math.atan2(left, forward)) / reach)


class Driver:
    """A driver of one level, knowing its car as `known` says."""

    def __init__(self, level: Level, known: dict, drift_phases: list[float]):
        self.level = level
        self.top_speed = float(known["top_speed"])
        self.wheelbase = float(known["wheelbase"])
        self.max_steer = float(known["max_steer"])
        self.grip = float(known["grip"])
        self.braking = float(known["braking"])
        self.slip_steer = float(known["slip_steer"])
        self.drift_phases = [float(p) for p in drift_phases]
        self.steer = self.throttle = self.brake = self.target_speed = 0.0
        self.braking_in = -1.0
        self.aim_forward = self.aim_left = 0.0
        self.limits: list[float] = []
        self.used: dict = {}

    def decide(self, view: View) -> None:
        """This frame's steering and pedals, from `view`."""
        self.used = {"lookahead": self.level.lookahead, "grip_margin": self.level.grip_margin,
                     "wander": self.level.wander}
        self.limits = self.speed_limits(view, self.used["grip_margin"])
        self.target_speed = min(self.limits[self._first_ahead(view)], self._traffic_limit(view))
        self.braking_in = self._braking_in(view)
        self._aim(view, max(MIN_AIM, self.used["lookahead"] * view.speed),
                  self.used["wander"] * self.drift(view.time))
        wanted_left = self.used["wander"] * self.drift(view.time)
        correction = STEER_GAIN * (wanted_left - view.cross_track)
        most = self.steer_limit(view.speed)
        self.steer = clamp(pursuit_steer(self.aim_forward, self.aim_left, self.wheelbase) + correction, -most, most)
        pedal = PEDAL_GAIN * (self.target_speed - view.speed)
        self.throttle = clamp(pedal, 0.0, 1.0)
        self.brake = clamp(-pedal, 0.0, 1.0)

    def speed_limits(self, view: View, margin: float) -> list[float]:
        """The fastest the driver will be at each point it sees."""
        count = len(view.line_forward)
        allowed = []
        for index in range(count):
            bend = abs(bend_at(view, index))
            allowed.append(math.sqrt(margin * self.grip / bend) if bend > 0.0 else math.inf)
        for index in range(count - 2, -1, -1):
            gap = distance(view, index, index + 1)
            reachable = math.sqrt(allowed[index + 1] * allowed[index + 1] + 2.0 * margin * self.braking * gap)
            allowed[index] = min(allowed[index], reachable)
        return [min(value, self.top_speed) for value in allowed]

    def steer_limit(self, speed: float) -> float:
        """The most the wheels are worth turning at `speed`."""
        arc = math.atan(self.wheelbase * self.grip / max(speed * speed, 1e-6))
        return min(self.max_steer, arc + self.slip_steer)

    def drift(self, time: float) -> float:
        """Between -1 and 1, slowly: the wander's two waves."""
        return (math.sin(0.43 * time + self.drift_phases[0]) + math.sin(1.13 * time + self.drift_phases[1])) / 2.0

    def _first_ahead(self, view: View) -> int:
        for index, forward in enumerate(view.line_forward):
            if forward >= 0.0:
                return index
        return 0

    def _traffic_limit(self, view: View) -> float:
        capped = math.inf
        for ahead, left, speed in view.rivals:
            reach = self._stopping(view.speed, speed) + FOLLOW_MARGIN
            if 0.0 < ahead < reach and abs(left - view.cross_track) < CAR_WIDTH:
                capped = min(capped, speed)
        return capped

    def _stopping(self, speed: float, other: float) -> float:
        if speed <= other:
            return 0.0
        return (speed * speed - other * other) / (2.0 * self.used["grip_margin"] * self.braking)

    def _braking_in(self, view: View) -> float:
        for index in range(self._first_ahead(view), len(self.limits)):
            if self.limits[index] < view.speed:
                return view.line_forward[index]
        return -1.0

    def _aim(self, view: View, reach: float, sideways: float) -> None:
        walked = 0.0
        last = len(view.line_forward) - 1
        index = 0
        while index < last - 1 and walked + distance(view, index, index + 1) < reach:
            walked += distance(view, index, index + 1)
            index += 1
        piece = distance(view, index, index + 1)
        share = clamp((reach - walked) / piece, 0.0, 1.0) if piece > 0.0 else 0.0
        along_forward = (view.line_forward[index + 1] - view.line_forward[index]) / max(piece, 1e-9)
        along_left = (view.line_left[index + 1] - view.line_left[index]) / max(piece, 1e-9)
        room_left = lerp(view.room_left[index], view.room_left[index + 1], share) - AIM_MARGIN
        room_right = lerp(view.room_right[index], view.room_right[index + 1], share) - AIM_MARGIN
        pushed = clamp(sideways, -room_right, room_left)
        self.aim_forward = lerp(view.line_forward[index], view.line_forward[index + 1], share) - along_left * pushed
        self.aim_left = lerp(view.line_left[index], view.line_left[index + 1], share) + along_forward * pushed
