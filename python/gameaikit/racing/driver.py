"""`RaceDriver3D`, line for line: the decision a 3D driver makes each frame.

Read `godot/game3d/racing/race_driver_3d.gd` for why each step is there; this
file is the same steps in the same order, so a reader can check one against
the other and the vectors can hold them to the same numbers.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field

from gameaikit.steering.heat_line import HeatLine
from gameaikit.steering.pid import PidController

#: Points either side of a point the bend there is measured over.
BEND_REACH = 2
#: How wide a car is taken to be when asking whether one is in the way.
CAR_WIDTH = 2.2
#: Metres beyond its braking distance a car ahead is followed from.
FOLLOW_MARGIN = 15.0
#: The steering PID's gains and integral limit, and the pedal's.
LINE_GAINS = [0.04, 0.02, 0.02, 0.1]
SPEED_GAINS = [0.5, 0.25, 0.0, 0.3]
#: The traffic's reach, a car alongside, a car's heat, spread, gap, side speed.
REACH = 60.0
BESIDE = 6.0
RIVAL_HEAT = 3.0
SPREAD = 2.6
ALONGSIDE = 3.0
PASS_GAP = 1.2
SIDE_SPEED = 4.0
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
                    float(values["cross_track"]), [float(point) for point in values["line_forward"]],
                    [float(point) for point in values["line_left"]], [float(room) for room in values["room_left"]],
                    [float(room) for room in values["room_right"]],
                    [[float(number) for number in rival] for rival in values["rivals"]])


def clamp(value: float, low: float, high: float) -> float:
    """`value` held between `low` and `high`, exactly as GDScript's clampf:
    below `low` is `low`, else above `high` is `high`. The order matters
    only when `low` is above `high`, and then both sides answer `low`."""
    if value < low:
        return low
    if value > high:
        return high
    return value


def lerp(start: float, end: float, share: float) -> float:
    """GDScript's lerpf."""
    return start + (end - start) * share


def distance(view: View, first: int, second: int) -> float:
    """Metres between two points of the view's line."""
    forward = view.line_forward[second] - view.line_forward[first]
    left = view.line_left[second] - view.line_left[first]
    return math.sqrt(forward * forward + left * left)


def bend_at(view: View, index: int) -> float:
    """The line's curvature at point `index`, positive to the left. A view
    too short to measure a bend over (under 2 * BEND_REACH + 1 points) has
    none, rather than one read through negative indices."""
    if len(view.line_forward) < 2 * BEND_REACH + 1:
        return 0.0
    middle = min(max(index, BEND_REACH), len(view.line_forward) - 1 - BEND_REACH)
    before, after = middle - BEND_REACH, middle + BEND_REACH
    forward, left = view.line_forward, view.line_left
    turned = (forward[middle] - forward[before]) * (left[after] - left[middle]) \
        - (left[middle] - left[before]) * (forward[after] - forward[middle])
    sides = distance(view, before, middle) * distance(view, middle, after) * distance(view, before, after)
    return 2.0 * turned / sides if sides > 0.0 else 0.0


def pursuit_steer(forward: float, left: float, axles: float) -> float:
    """The wheel angle for the arc through (forward, left): pure pursuit."""
    reach = math.sqrt(forward * forward + left * left)
    if reach <= 0.0:
        return 0.0
    return math.atan(axles * 2.0 * math.sin(math.atan2(left, forward)) / reach)


def move_toward(start: float, end: float, most: float) -> float:
    """GDScript's move_toward."""
    if abs(end - start) <= most:
        return end
    return start + math.copysign(most, end - start)


class Traffic:
    """`RaceTraffic3D`: the heat line, or one rival at a time."""

    def __init__(self) -> None:
        self.heat_vision = True
        self.heat = HeatLine()
        self.offset = 0.0
        self.passing_side = 0

    def plan(self, rivals: list[list[float]], room_left: float, room_right: float, speed: float, step: float) -> float:
        """The offset from the line to steer for."""
        if self.heat_vision:
            wanted = self._heat_vision(rivals, room_left, room_right, speed, step)
        else:
            wanted = self._one_rival(rivals, room_left, room_right)
        self.offset = move_toward(self.offset, wanted, SIDE_SPEED * step)
        return self.offset

    def _heat_vision(self, rivals, room_left, room_right, speed, step) -> float:
        self.heat.build(room_left, room_right)
        for ahead, left, rival_speed in rivals:
            alongside = -BESIDE < ahead <= 0.0
            closing = 0.0 < ahead < REACH and rival_speed < speed + 1.0
            if alongside:
                self.heat.heat_up(left, RIVAL_HEAT * ALONGSIDE, SPREAD)
            elif closing:
                self.heat.heat_up(left, RIVAL_HEAT * (1.0 - ahead / REACH), SPREAD)
        self.heat.roll(step)
        return self.heat.ball

    def _one_rival(self, rivals, room_left, room_right) -> float:
        nearest = -1
        for index, (ahead, left, _speed) in enumerate(rivals):
            blocking = abs(left) < SPREAD + PASS_GAP
            near = -BESIDE < ahead < REACH
            if near and blocking and (nearest < 0 or abs(ahead) < abs(rivals[nearest][0])):
                nearest = index
        if nearest < 0:
            self.passing_side = 0
            return 0.0
        rival_left = rivals[nearest][1]
        if self.passing_side == 0:
            self.passing_side = 1 if room_left - rival_left >= rival_left + room_right else -1
        return clamp(rival_left + self.passing_side * (SPREAD + PASS_GAP), -room_right, room_left)


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
        self.wanted_left = self.line_error = 0.0
        self.full_pid = True
        self.line_pid = PidController(*LINE_GAINS)
        self.speed_pid = PidController(*SPEED_GAINS)
        self.traffic = Traffic()

    def decide(self, view: View) -> None:
        """This frame's steering and pedals, from `view`."""
        self.used = {"lookahead": self.level.lookahead, "grip_margin": self.level.grip_margin,
                     "wander": self.level.wander}
        self.limits = self.speed_limits(view, self.used["grip_margin"])
        reach = max(MIN_AIM, self.used["lookahead"] * view.speed)
        ahead = self._point_at(view, reach)
        side = self.traffic.plan(view.rivals, view.room_left[ahead] - AIM_MARGIN,
                                 view.room_right[ahead] - AIM_MARGIN, view.speed, view.step)
        self.wanted_left = side + self.used["wander"] * self.drift(view.time)
        self.target_speed = min(self.limits[self._first_ahead(view)], self._traffic_limit(view))
        self.braking_in = self._braking_in(view)
        self._aim(view, reach, self.wanted_left)
        self.line_pid.proportional_only = not self.full_pid
        self.speed_pid.proportional_only = not self.full_pid
        self.line_error = self.wanted_left - view.cross_track
        most = self.steer_limit(view.speed)
        pursuit = pursuit_steer(self.aim_forward, self.aim_left, self.wheelbase)
        self.steer = clamp(pursuit + self.line_pid.update(self.line_error, view.step), -most, most)
        pedal = self.speed_pid.update(self.target_speed - view.speed, view.step)
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
            in_the_way = abs(left - self.wanted_left) < CAR_WIDTH or abs(left - view.cross_track) < CAR_WIDTH
            if 0.0 < ahead < reach and in_the_way:
                capped = min(capped, speed)
        return capped

    def _point_at(self, view: View, reach: float) -> int:
        walked = 0.0
        for index in range(len(view.line_forward) - 1):
            if walked >= reach:
                return index
            walked += distance(view, index, index + 1)
        return len(view.line_forward) - 1

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
