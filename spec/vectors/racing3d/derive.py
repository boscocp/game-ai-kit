#!/usr/bin/env python3
"""Write the 3D driver's conformance vectors from a third copy of its rules.

`RaceDriver3D` (GDScript) and `gameaikit.racing` (Python) must decide the
same from the same snapshot. The answers in the `.json` files beside this
come from neither: this file builds each snapshot from a stated road --
straights and arcs, in the car's frame -- and decides it with its own copy
of the rules in plain lists, importing nothing from the repository.
Independent of the code, not of its author: it makes the same choices, so
it catches a slip in transcribing them, not a choice that is wrong.

Every expression below is written in the same order as the GDScript's, so
the three agree to the last digit printed (the vectors' tolerance is 1e-9).

    python3 spec/vectors/racing3d/derive.py spec/vectors/racing3d
"""

from __future__ import annotations

import json
import math
import pathlib
import re
import sys

SPACING = 3.0
HORIZON = 60
BEND = 2
WIDTH = 2.2
FOLLOW = 15.0
LINE_GAINS = (0.04, 0.02, 0.02, 0.1)
SPEED_GAINS = (0.5, 0.25, 0.0, 0.3)
MIN_AIM = 8.0
AIM_MARGIN = 1.0
CELLS, LINE_HEAT, EDGE_HEAT, EDGE_REACH, PUSH, DRAG = 41, 0.15, 4.0, 1.5, 6.0, 3.0
REACH, BESIDE, RIVAL_HEAT, ALONGSIDE, SPREAD, PASS_GAP, SIDE_SPEED = 60.0, 6.0, 3.0, 3.0, 2.6, 1.2, 4.0

KNOWN = {"top_speed": 50.0, "wheelbase": 2.6, "max_steer": 0.5, "grip": 9.4, "braking": 8.4, "slip_steer": 0.03}

#: Points of road a held vector shows: 60 metres, enough for its bend and
#: its aim, and a file a reader can open.
SHORT = 20


# --- the road, in the car's frame ------------------------------------------

def road(pieces, cross_track, width=9.0, horizon=HORIZON, behind=0.0, narrowing=0.0) -> dict:
    """`horizon` points SPACING apart along straights (radius 0) and arcs
    (radius > 0 turns left, < 0 right), each piece (metres, radius). The
    line starts `behind` metres behind the car, which sits `cross_track`
    left of it, pointing along it; the tarmac either side is `width`, less
    `narrowing` for every point further on."""
    points, heading, along, across = [], 0.0, 0.0, 0.0
    queue = list(pieces)
    left_in_piece = queue[0][0]
    for _ in range(horizon):
        points.append((along - behind, across - cross_track))
        radius = queue[0][1]
        if radius != 0.0:
            heading += SPACING / radius
        along += SPACING * math.cos(heading)
        across += SPACING * math.sin(heading)
        left_in_piece -= SPACING
        if left_in_piece <= 0.0 and len(queue) > 1:
            queue.pop(0)
            left_in_piece = queue[0][0]
    rooms = [width - narrowing * index for index in range(horizon)]
    return {"line_forward": [point[0] for point in points], "line_left": [point[1] for point in points],
            "room_left": rooms, "room_right": list(rooms)}


def view(pieces, speed, cross_track=0.0, time=0.0, rivals=(), **shape) -> dict:
    """A snapshot: the road `road` builds, and the car's state."""
    seen = road(pieces, cross_track, **shape)
    seen.update({"time": time, "step": 1.0 / 60.0, "speed": speed, "cross_track": cross_track,
                 "rivals": [list(rival) for rival in rivals]})
    return seen


def held(pieces, speed, cross_track, frames, **rest) -> list[dict]:
    """The same road shown `frames` times, a frame apart, the car held off it
    by `cross_track`: what an error that stays there does to the PIDs."""
    return [view(pieces, speed, cross_track, time=frame / 60.0, horizon=SHORT, **rest) for frame in range(frames)]


# --- the rules, a third time -------------------------------------------------

def gap(seen, first, second):
    return math.hypot(seen["line_forward"][second] - seen["line_forward"][first],
                      seen["line_left"][second] - seen["line_left"][first])


def bend(seen, index):
    forward, left = seen["line_forward"], seen["line_left"]
    middle = min(max(index, BEND), len(forward) - 1 - BEND)
    before, after = middle - BEND, middle + BEND
    turned = (forward[middle] - forward[before]) * (left[after] - left[middle]) \
        - (left[middle] - left[before]) * (forward[after] - forward[middle])
    sides = gap(seen, before, middle) * gap(seen, middle, after) * gap(seen, before, after)
    return 2.0 * turned / sides if sides > 0 else 0.0


def limits(seen, margin, known):
    count = len(seen["line_forward"])
    out = [math.sqrt(margin * known["grip"] / abs(bend(seen, index))) if bend(seen, index) != 0 else math.inf
           for index in range(count)]
    for index in range(count - 2, -1, -1):
        reachable = math.sqrt(out[index + 1] * out[index + 1] + 2.0 * margin * known["braking"] * gap(seen, index, index + 1))
        out[index] = min(out[index], reachable)
    return [min(value, known["top_speed"]) for value in out]


class Pid:
    def __init__(self, gains, full):
        self.kp, self.ki, self.kd, self.most = gains
        self.full, self.summed, self.last, self.started = full, 0.0, 0.0, False

    def push(self, error, step):
        out = self.kp * error
        if self.full:
            self.summed += error * step
            if self.ki != 0:
                self.summed = max(-self.most / abs(self.ki), min(self.most / abs(self.ki), self.summed))
            rate = (error - self.last) / step if self.started and step > 0 else 0.0
            out = out + self.ki * self.summed + self.kd * rate
        self.last, self.started = error, True
        return out


class Third:
    """The driver a third time, with the state it keeps between frames."""

    def __init__(self, level, known, phases, flags):
        self.level, self.known, self.phases = level, known, phases
        self.heat_on = flags.get("heat_vision", True)
        full = flags.get("full_pid", True)
        self.line, self.speed = Pid(LINE_GAINS, full), Pid(SPEED_GAINS, full)
        self.ball = self.ball_speed = self.offset = 0.0
        self.side = 0

    def roll(self, rivals, room_left, room_right, speed, step):
        cells = [-room_right + (room_left + room_right) * (cell / (CELLS - 1)) for cell in range(CELLS)]
        heat = [LINE_HEAT * at * at + EDGE_HEAT * max(0.0, 1 - min(room_left - at, at + room_right) / EDGE_REACH)
                for at in cells]
        for ahead, left, rival_speed in rivals:
            if -BESIDE < ahead <= 0 or (0 < ahead < REACH and rival_speed < speed + 1):
                strength = RIVAL_HEAT * ALONGSIDE if ahead <= 0 else RIVAL_HEAT * (1 - ahead / REACH)
                heat = [warm + strength * math.exp(-((at - left) / SPREAD) ** 2) for warm, at in zip(heat, cells)]
        width = cells[-1] - cells[0]
        cell = width / (CELLS - 1)

        def heat_at(at):
            place = max(0.0, min(CELLS - 1.0, (at - cells[0]) / width * (CELLS - 1)))
            below = min(math.floor(place), CELLS - 2)
            return heat[below] + (heat[below + 1] - heat[below]) * (place - below)

        slope = (heat_at(self.ball + cell / 2) - heat_at(self.ball - cell / 2)) / cell if cell > 0 else 0.0
        self.ball_speed += (-PUSH * slope - DRAG * self.ball_speed) * step
        self.ball += self.ball_speed * step
        if not cells[0] <= self.ball <= cells[-1]:
            self.ball, self.ball_speed = max(cells[0], min(cells[-1], self.ball)), 0.0
        return self.ball

    def one_rival(self, rivals, room_left, room_right):
        near = [rival for rival in rivals if -BESIDE < rival[0] < REACH and abs(rival[1]) < SPREAD + PASS_GAP]
        if not near:
            self.side = 0
            return 0.0
        nearest = min(near, key=lambda rival: abs(rival[0]))
        if self.side == 0:
            self.side = 1 if room_left - nearest[1] >= nearest[1] + room_right else -1
        return max(-room_right, min(room_left, nearest[1] + self.side * (SPREAD + PASS_GAP)))

    def decide(self, seen) -> dict:
        level, known = self.level, self.known
        margin = level["grip_margin"]
        forward = seen["line_forward"]
        allowed = limits(seen, margin, known)
        first = next((index for index, ahead in enumerate(forward) if ahead >= 0), 0)
        reach = max(MIN_AIM, level["lookahead"] * seen["speed"])
        point, walked = len(forward) - 1, 0.0
        for index in range(len(forward) - 1):
            if walked >= reach:
                point = index
                break
            walked += gap(seen, index, index + 1)
        room_left, room_right = seen["room_left"][point] - AIM_MARGIN, seen["room_right"][point] - AIM_MARGIN
        if self.heat_on:
            wanted = self.roll(seen["rivals"], room_left, room_right, seen["speed"], seen["step"])
        else:
            wanted = self.one_rival(seen["rivals"], room_left, room_right)
        step_most = SIDE_SPEED * seen["step"]
        if abs(wanted - self.offset) <= step_most:
            self.offset = wanted
        else:
            self.offset = self.offset + math.copysign(step_most, wanted - self.offset)
        drift = (math.sin(0.43 * seen["time"] + self.phases[0]) + math.sin(1.13 * seen["time"] + self.phases[1])) / 2
        wanted_left = self.offset + level["wander"] * drift
        capped = math.inf
        for ahead, left, speed in seen["rivals"]:
            stopping = 0.0 if seen["speed"] <= speed else \
                (seen["speed"] * seen["speed"] - speed * speed) / (2 * margin * known["braking"])
            in_the_way = abs(left - wanted_left) < WIDTH or abs(left - seen["cross_track"]) < WIDTH
            if 0 < ahead < stopping + FOLLOW and in_the_way:
                capped = min(capped, speed)
        target = min(allowed[first], capped)
        braking_in = next((forward[index] for index in range(first, len(allowed)) if allowed[index] < seen["speed"]), -1.0)
        aim_forward, aim_left = aim(seen, reach, wanted_left)
        span = math.hypot(aim_forward, aim_left)
        pursuit = math.atan(known["wheelbase"] * 2 * math.sin(math.atan2(aim_left, aim_forward)) / span) if span > 0 else 0.0
        arc = math.atan(known["wheelbase"] * known["grip"] / max(seen["speed"] * seen["speed"], 1e-6))
        most = min(known["max_steer"], arc + known["slip_steer"])
        steer = max(-most, min(most, pursuit + self.line.push(wanted_left - seen["cross_track"], seen["step"])))
        pedal = self.speed.push(target - seen["speed"], seen["step"])
        return {"steer": steer, "throttle": max(0.0, min(1.0, pedal)), "brake": max(0.0, min(1.0, -pedal)),
                "target_speed": target, "braking_in": braking_in, "aim_forward": aim_forward, "aim_left": aim_left,
                "wanted_left": wanted_left}


def aim(seen, reach, sideways):
    forward, left = seen["line_forward"], seen["line_left"]
    walked, index, last = 0.0, 0, len(forward) - 1
    while index < last - 1 and walked + gap(seen, index, index + 1) < reach:
        walked += gap(seen, index, index + 1)
        index += 1
    piece = gap(seen, index, index + 1)
    share = max(0.0, min(1.0, (reach - walked) / piece)) if piece > 0 else 0.0
    along_forward = (forward[index + 1] - forward[index]) / max(piece, 1e-9)
    along_left = (left[index + 1] - left[index]) / max(piece, 1e-9)
    room_left = seen["room_left"][index] + (seen["room_left"][index + 1] - seen["room_left"][index]) * share - AIM_MARGIN
    room_right = seen["room_right"][index] + (seen["room_right"][index + 1] - seen["room_right"][index]) * share - AIM_MARGIN
    pushed = max(-room_right, min(room_left, sideways))
    return (forward[index] + (forward[index + 1] - forward[index]) * share - along_left * pushed,
            left[index] + (left[index + 1] - left[index]) * share + along_forward * pushed)


# --- the vectors ---------------------------------------------------------------

def level(lookahead=0.7, margin=0.9, wander=0.0, title="probe"):
    return {"title": title, "lookahead": lookahead, "grip_margin": margin, "wander": wander}


STILL = [0.0, 0.0]
STRAIGHT = [(180, 0)]
ARC_60 = [(200, 60)]

CASES = [
    ("a-straight-at-speed", "On the line on a straight at 30 m/s: the top speed, full throttle, no steering.",
     level(), STILL, [view(STRAIGHT, 30.0)]),
    ("a-bend-ahead-brakes-in-time",
     "A left arc of 40 m radius starts 60 m ahead, at 35 m/s: the profile carried back from the arc is under the car's speed, so it brakes, and says how far ahead the braking point is.",
     level(), STILL, [view([(60, 0), (200, 40)], 35.0), view([(30, 0), (200, 40)], 30.0)]),
    ("off-the-line-steers-back", "Two metres right of the line on a straight: pursuit and the correction both steer left; then two metres left, both right.",
     level(), STILL, [view(STRAIGHT, 25.0, -2.0), view(STRAIGHT, 25.0, 2.0)]),
    ("a-car-ahead-in-the-lane-caps-the-speed",
     "A rival 20 m ahead at 20 m/s in the car's lane caps the target at its speed; the same rival 4 m to the left does not.",
     level(), STILL, [view(STRAIGHT, 30.0, rivals=[(20.0, 0.5, 20.0)]),
                      view(STRAIGHT, 30.0, rivals=[(20.0, 4.0, 20.0)]),
                      view(STRAIGHT, 30.0, rivals=[(-10.0, 0.0, 10.0)])]),
    ("wander-drifts-the-aim", "Wander 2 m with stated phases: at three moments the aim sits at three places across the line.",
     level(wander=2.0), [0.7, 2.1], [view(STRAIGHT, 20.0, time=moment) for moment in (0.0, 4.0, 9.0)]),
    ("at-the-limit-the-wheels-turn-no-further",
     "A right arc of 15 m radius at 30 m/s: the arc asks more than the grip gives, and the wheels stop at the limit the measured grip and slip allow.",
     level(), STILL, [view([(200, -15)], 30.0)]),
    ("the-aim-keeps-to-the-tarmac", "Wander 6 m on a road with 3 m of tarmac each side: the aim is held a metre inside the edge.",
     level(wander=6.0), [math.pi / 2, math.pi / 2], [view(STRAIGHT, 20.0, width=3.0)]),
    ("a-slow-car-aims-close", "At 5 m/s the lookahead's seconds come to less than the nearest aim, which holds it at 8 m.",
     level(), STILL, [view([(10, 0), (200, 30)], 5.0)]),
    ("pid-sums-an-offset-that-stays",
     "Held 0.3 m right of the line on a straight for half a second: the integral grows every frame, so the steering does; the first frame has no derivative.",
     level(), STILL, held(STRAIGHT, 20.0, -0.3, 30), {}),
    ("proportional-only-does-not",
     "The same car with the PID's integral and derivative off: the steering is the same every frame.",
     level(), STILL, held(STRAIGHT, 20.0, -0.3, 10), {"full_pid": False}),
    ("the-pedal-sums-a-speed-it-cannot-reach",
     "Half a metre a second under the speed a 60 m arc allows, frame after frame: the proportional term asks a quarter of the throttle, and the integral adds to it every frame.",
     level(), STILL, held(ARC_60, 22.0, 0.0, 40), {}),
    ("heat-rolls-round-a-car-ahead",
     "A slower car 30 m ahead, just left of the line: the ball rolls right, a frame at a time, and the car means to be there.",
     level(), STILL, held(STRAIGHT, 30.0, 0.0, 45, rivals=[(30.0, 0.5, 20.0)]), {}),
    ("heat-goes-round-two-cars-at-once",
     "Two slower cars ahead, one each side of the line: the coolest place is the gap between them, so the ball stays near the line -- where one rival at a time would pull out beside the nearer.",
     level(), STILL, held(STRAIGHT, 30.0, 0.0, 60, rivals=[(25.0, 2.5, 20.0), (40.0, -2.5, 20.0)]), {}),
    ("one-rival-at-a-time",
     "Without the heat line: the nearer car on the line is passed on its roomier side, and the second is not looked at until the first is.",
     level(), STILL, held(STRAIGHT, 30.0, 0.0, 40, rivals=[(25.0, 1.0, 20.0), (40.0, -2.5, 20.0)]), {"heat_vision": False}),
]


def frames_of(count, make) -> list[dict]:
    """`count` views, the frame's number handed to `make` for each."""
    return [make(frame) for frame in range(count)]


# The review's cases (wave 73): each pins a rule a one-line change to the
# Python twin used to get past.
CASES += [
    ("a-rival-alongside",
     "A rival level with the car (0 m ahead), as fast as it, just left of the line: alongside counts from 0 m back, three times as hot as a car at the bumper, and the ball rolls right.",
     level(), STILL, held(STRAIGHT, 30.0, 0.0, 45, rivals=[(0.0, 1.0, 30.0)]), {}),
    ("a-rival-half-a-car-behind",
     "A rival 4.5 m behind the car's line sample: still alongside, which reaches 6 m back.",
     level(), STILL, held(STRAIGHT, 30.0, 0.0, 30, rivals=[(-4.5, 0.5, 30.0)]), {}),
    ("a-rival-barely-slower",
     "A rival 25 m ahead going 30.5 m/s, the car 30: closing counts a car up to a metre a second faster, so it is weighed.",
     level(), STILL, held(STRAIGHT, 30.0, 0.0, 30, rivals=[(25.0, 0.5, 30.5)]), {}),
    ("the-heat-line-at-the-edge",
     "A rival alongside on a road with 2 m to spare each side: the ball is pushed into the edge's heat, and stops at the edge.",
     level(), STILL, held(STRAIGHT, 30.0, 0.0, 90, rivals=[(0.0, 0.8, 30.0)], width=3.0), {}),
    ("one-rival-the-nearer-listed-second",
     "Without the heat line, two cars on the line listed far one first: the nearer one, listed second, is the one passed.",
     level(), STILL, held(STRAIGHT, 30.0, 0.0, 30, rivals=[(40.0, -0.5, 20.0), (25.0, 1.0, 20.0)]), {"heat_vision": False}),
    ("one-rival-leaves-and-comes-back",
     "Without the heat line: a rival left of the line is passed on the right; it goes, the side is forgotten; it comes back right of the line and is passed on the left.",
     level(), STILL, frames_of(60, lambda frame: view(
         STRAIGHT, 30.0, time=frame / 60.0, horizon=SHORT,
         rivals=[(25.0, 1.0, 20.0)] if frame < 20 else ([] if frame < 30 else [(25.0, -1.0, 20.0)]))),
     {"heat_vision": False}),
    ("one-rival-a-tie-goes-left",
     "Without the heat line, a rival dead on the line of a road as wide either side: the tie goes to the left.",
     level(), STILL, held(STRAIGHT, 30.0, 0.0, 30, rivals=[(25.0, 0.0, 20.0)]), {"heat_vision": False}),
    ("one-rival-near-the-edge",
     "Without the heat line, on a road with 2 m to spare: passing a car 1 m left of the line on its right would put the car past the edge, so it is held at the edge.",
     level(), STILL, held(STRAIGHT, 30.0, 0.0, 60, rivals=[(25.0, 1.0, 20.0)], width=3.0), {"heat_vision": False}),
    ("a-rival-where-the-car-is",
     "The car 2.5 m right of the line, a slower rival 20 m ahead right where the car is: the car means to be elsewhere, and still follows it until it is.",
     level(), STILL, held(STRAIGHT, 30.0, -2.5, 3, rivals=[(20.0, -2.5, 20.0)]), {}),
    ("a-rival-where-the-car-means-to-be",
     "The car 3 m left of the line, a slower rival 20 m ahead on the line, where the car means to be: it follows.",
     level(), STILL, held(STRAIGHT, 30.0, 3.0, 3, rivals=[(20.0, 0.3, 20.0)]), {}),
    ("following-from-fifteen-metres",
     "A rival 13 m ahead a tenth of a metre a second slower: under the fifteen metres a car is followed from beyond its braking, so it caps the speed.",
     level(), STILL, held(STRAIGHT, 30.0, 0.0, 3, rivals=[(13.0, 0.0, 29.9)]), {}),
    ("stopping-at-the-braking-it-dares",
     "A rival 46 m ahead at 20 m/s, the car at 30: braking at the margin's share, the car needs 33 m and so follows from 48; at full braking it would wait until 44.8.",
     level(), STILL, held(STRAIGHT, 30.0, 0.0, 3, rivals=[(46.0, 0.0, 20.0)]), {}),
    ("a-long-error-saturates",
     "Held 2 m right of the line at 5 m/s for two and a half seconds: the steering integral reaches its limit, a tenth of a radian, and stays there, with the wheels still short of their own limit.",
     level(), STILL, held(STRAIGHT, 5.0, -2.0, 160), {}),
    ("the-pedal-integral-is-held",
     "Half a metre a second slow on a 60 m arc for nearly three seconds: the pedal's integral reaches its limit, 0.3, and the throttle stops growing.",
     level(), STILL, held(ARC_60, 22.0, 0.0, 170), {}),
    ("at-the-speed-it-wants",
     "On a straight at exactly the top speed: nothing ahead is slower than the car, so there is no braking point.",
     level(), STILL, [view(STRAIGHT, 50.0)]),
    ("a-slow-tight-bend",
     "A right arc of 6 m radius at 3 m/s: what pursuit asks is past full lock, and the wheels stop at half a radian.",
     level(), STILL, [view([(200, -6)], 3.0)]),
    ("the-first-points-behind",
     "The line starts 12 m behind the car, on a straight into a 12 m left arc that begins where the car is: the speed wanted and the braking point are read from the first point not yet passed, the one at 0 m.",
     level(), STILL, [view([(12, 0), (200, 12)], 25.0, behind=12.0)]),
    ("room-narrows-ahead",
     "Wander 8 m and a car alongside on a road that narrows by 0.1 m a point: the room is the one where the car aims, not where it is.",
     level(wander=8.0), [math.pi / 2, math.pi / 2],
     held(STRAIGHT, 20.0, 0.0, 30, rivals=[(0.0, 1.0, 20.0)], narrowing=0.1), {}),
    ("proportional-only-pedal",
     "Half a metre a second slow on a 60 m arc with the PID off: the pedal is the proportional term alone, the same every frame.",
     level(), STILL, held(ARC_60, 22.0, 0.0, 20), {"full_pid": False}),
    ("a-car-drifting-off-the-line",
     "The car drifting right a centimetre a frame and losing speed: both errors change, so both derivative terms speak.",
     level(), STILL, frames_of(30, lambda frame: view(
         ARC_60, 22.0 - 0.02 * frame, -0.01 * frame, time=frame / 60.0, horizon=SHORT)), {}),
    ("an-s-bend",
     "Arcs of 25 m radius, left and right, 12 m each: the bend at a point is measured over two points either side, and the profile follows it.",
     level(), STILL, [view([(12, 25), (12, -25)] * 8, 20.0)]),
]


def compact(text: str) -> str:
    """The file with every list of plain numbers on one line, so a frame's
    view reads as a few lines rather than a hundred."""
    return re.sub(r"\[\s*(-?[0-9][-0-9.e+,\s]*?)\s*\]",
                  lambda found: "[" + " ".join(found.group(1).split()) + "]", text)


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: derive.py <directory>", file=sys.stderr)
        return 2
    target = pathlib.Path(argv[1])
    for case in CASES:
        name, why, knobs, phases, views = case[:5]
        flags = case[5] if len(case) > 5 else {}
        driver = Third(knobs, KNOWN, phases, flags)
        frames = [{"view": seen, "expect": driver.decide(seen)} for seen in views]
        vector = {"name": name, "why": why,
                  "driver": {"level": knobs, "known": KNOWN, "drift_phases": phases, "switches": flags}, "frames": frames}
        (target / f"{name}.json").write_text(compact(json.dumps(vector, indent=1)) + "\n")
    print(f"{len(CASES)} vector(s) written to {target}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
