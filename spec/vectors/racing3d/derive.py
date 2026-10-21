#!/usr/bin/env python3
"""Write the 3D driver's conformance vectors from a third copy of its rules.

`RaceDriver3D` (GDScript) and `gameaikit.racing` (Python) must decide the
same from the same snapshot. The answers in the `.json` files beside this
come from neither: this file builds each snapshot from a stated road --
straights and arcs, in the car's frame -- and decides it with its own copy
of the rules in plain lists, importing nothing from the repository.
Independent of the code, not of its author: it makes the same choices, so
it catches a slip in transcribing them, not a choice that is wrong.

    python3 spec/vectors/racing3d/derive.py spec/vectors/racing3d
"""

from __future__ import annotations

import json
import math
import pathlib
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


# --- the road, in the car's frame ------------------------------------------

def road(pieces: list[tuple[float, float]], cross_track: float, width: float = 9.0, horizon: int = HORIZON) -> dict:
    """HORIZON points SPACING apart along straights (radius 0) and arcs
    (radius > 0 turns left, < 0 right), each piece (metres, radius); the
    car sits `cross_track` left of the line's first point, pointing along it."""
    points, heading, x, y = [], 0.0, 0.0, 0.0
    queue = list(pieces)
    left_in_piece = queue[0][0]
    for _ in range(horizon):
        points.append((x, y - cross_track))
        radius = queue[0][1]
        if radius != 0.0:
            heading += SPACING / radius
        x += SPACING * math.cos(heading)
        y += SPACING * math.sin(heading)
        left_in_piece -= SPACING
        if left_in_piece <= 0.0 and len(queue) > 1:
            queue.pop(0)
            left_in_piece = queue[0][0]
    return {"line_forward": [p[0] for p in points], "line_left": [p[1] for p in points],
            "room_left": [width] * horizon, "room_right": [width] * horizon}


def view(pieces, speed, cross_track=0.0, time=0.0, rivals=(), width=9.0, horizon=HORIZON) -> dict:
    shape = road(pieces, cross_track, width, horizon)
    shape.update({"time": time, "step": 1.0 / 60.0, "speed": speed, "cross_track": cross_track,
                  "rivals": [list(r) for r in rivals]})
    return shape


# --- the rules, a third time -------------------------------------------------

def gap(v, a, b):
    return math.hypot(v["line_forward"][b] - v["line_forward"][a], v["line_left"][b] - v["line_left"][a])


def bend(v, i):
    m = min(max(i, BEND), len(v["line_forward"]) - 1 - BEND)
    a, b = m - BEND, m + BEND
    f, l = v["line_forward"], v["line_left"]
    turned = (f[m] - f[a]) * (l[b] - l[m]) - (l[m] - l[a]) * (f[b] - f[m])
    sides = gap(v, a, m) * gap(v, m, b) * gap(v, a, b)
    return 2.0 * turned / sides if sides > 0 else 0.0


def limits(v, margin, known):
    n = len(v["line_forward"])
    out = [math.sqrt(margin * known["grip"] / abs(bend(v, i))) if bend(v, i) != 0 else math.inf for i in range(n)]
    for i in range(n - 2, -1, -1):
        out[i] = min(out[i], math.sqrt(out[i + 1] ** 2 + 2 * margin * known["braking"] * gap(v, i, i + 1)))
    return [min(x, known["top_speed"]) for x in out]


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

    def roll(self, rivals, room_l, room_r, speed, step):
        cells = [-room_r + (room_l + room_r) * (c / (CELLS - 1)) for c in range(CELLS)]
        heat = [LINE_HEAT * x * x + EDGE_HEAT * max(0.0, 1 - min(room_l - x, x + room_r) / EDGE_REACH) for x in cells]
        for ahead, left, rival_speed in rivals:
            if -BESIDE < ahead <= 0 or (0 < ahead < REACH and rival_speed < speed + 1):
                strength = RIVAL_HEAT * ALONGSIDE if ahead <= 0 else RIVAL_HEAT * (1 - ahead / REACH)
                heat = [h + strength * math.exp(-((x - left) / SPREAD) ** 2) for h, x in zip(heat, cells)]
        width = cells[-1] - cells[0]
        cell = width / (CELLS - 1)

        def at(x):
            place = max(0.0, min(CELLS - 1.0, (x - cells[0]) / width * (CELLS - 1)))
            below = min(math.floor(place), CELLS - 2)
            return heat[below] + (heat[below + 1] - heat[below]) * (place - below)

        slope = (at(self.ball + cell / 2) - at(self.ball - cell / 2)) / cell if cell > 0 else 0.0
        self.ball_speed += (-PUSH * slope - DRAG * self.ball_speed) * step
        self.ball += self.ball_speed * step
        if not cells[0] <= self.ball <= cells[-1]:
            self.ball, self.ball_speed = max(cells[0], min(cells[-1], self.ball)), 0.0
        return self.ball

    def one_rival(self, rivals, room_l, room_r):
        near = [r for r in rivals if -BESIDE < r[0] < REACH and abs(r[1]) < SPREAD + PASS_GAP]
        if not near:
            self.side = 0
            return 0.0
        first = min(near, key=lambda r: abs(r[0]))
        if self.side == 0:
            self.side = 1 if room_l - first[1] >= first[1] + room_r else -1
        return max(-room_r, min(room_l, first[1] + self.side * (SPREAD + PASS_GAP)))

    def decide(self, v) -> dict:
        level, known = self.level, self.known
        margin = level["grip_margin"]
        lim = limits(v, margin, known)
        first = next((i for i, f in enumerate(v["line_forward"]) if f >= 0), 0)
        reach = max(MIN_AIM, level["lookahead"] * v["speed"])
        point, walked = len(v["line_forward"]) - 1, 0.0
        for i in range(len(v["line_forward"]) - 1):
            if walked >= reach:
                point = i
                break
            walked += gap(v, i, i + 1)
        room_l, room_r = v["room_left"][point] - AIM_MARGIN, v["room_right"][point] - AIM_MARGIN
        wanted = self.roll(v["rivals"], room_l, room_r, v["speed"], v["step"]) if self.heat_on else self.one_rival(v["rivals"], room_l, room_r)
        step_most = SIDE_SPEED * v["step"]
        self.offset = wanted if abs(wanted - self.offset) <= step_most else self.offset + math.copysign(step_most, wanted - self.offset)
        drift = (math.sin(0.43 * v["time"] + self.phases[0]) + math.sin(1.13 * v["time"] + self.phases[1])) / 2
        wanted_left = self.offset + level["wander"] * drift
        capped = math.inf
        for ahead, left, speed in v["rivals"]:
            stopping = 0.0 if v["speed"] <= speed else (v["speed"] ** 2 - speed ** 2) / (2 * margin * known["braking"])
            if 0 < ahead < stopping + FOLLOW and (abs(left - wanted_left) < WIDTH or abs(left - v["cross_track"]) < WIDTH):
                capped = min(capped, speed)
        target = min(lim[first], capped)
        braking_in = next((v["line_forward"][i] for i in range(first, len(lim)) if lim[i] < v["speed"]), -1.0)
        aim_f, aim_l = aim(v, reach, wanted_left)
        span = math.hypot(aim_f, aim_l)
        pursuit = math.atan(known["wheelbase"] * 2 * math.sin(math.atan2(aim_l, aim_f)) / span) if span > 0 else 0.0
        most = min(known["max_steer"], math.atan(known["wheelbase"] * known["grip"] / max(v["speed"] ** 2, 1e-6)) + known["slip_steer"])
        steer = max(-most, min(most, pursuit + self.line.push(wanted_left - v["cross_track"], v["step"])))
        pedal = self.speed.push(target - v["speed"], v["step"])
        return {"steer": steer, "throttle": max(0.0, min(1.0, pedal)), "brake": max(0.0, min(1.0, -pedal)),
                "target_speed": target, "braking_in": braking_in, "aim_forward": aim_f, "aim_left": aim_l,
                "wanted_left": wanted_left}


def aim(v, reach, sideways):
    f, l = v["line_forward"], v["line_left"]
    walked, i, last = 0.0, 0, len(f) - 1
    while i < last - 1 and walked + gap(v, i, i + 1) < reach:
        walked += gap(v, i, i + 1)
        i += 1
    piece = gap(v, i, i + 1)
    share = max(0.0, min(1.0, (reach - walked) / piece)) if piece > 0 else 0.0
    df, dl = (f[i + 1] - f[i]) / max(piece, 1e-9), (l[i + 1] - l[i]) / max(piece, 1e-9)
    room_l = v["room_left"][i] + (v["room_left"][i + 1] - v["room_left"][i]) * share - AIM_MARGIN
    room_r = v["room_right"][i] + (v["room_right"][i + 1] - v["room_right"][i]) * share - AIM_MARGIN
    pushed = max(-room_r, min(room_l, sideways))
    return (f[i] + (f[i + 1] - f[i]) * share - dl * pushed, l[i] + (l[i + 1] - l[i]) * share + df * pushed)


# --- the vectors ---------------------------------------------------------------

def level(lookahead=0.7, margin=0.9, wander=0.0, title="probe"):
    return {"title": title, "lookahead": lookahead, "grip_margin": margin, "wander": wander}


CASES = [
    ("a-straight-at-speed", "On the line on a straight at 30 m/s: the top speed, full throttle, no steering.",
     level(), [0.0, 0.0], [view([(180, 0)], 30.0)]),
    ("a-bend-ahead-brakes-in-time",
     "A left arc of 40 m radius starts 60 m ahead, at 35 m/s: the profile carried back from the arc is under the car's speed, so it brakes, and says how far ahead the braking point is.",
     level(), [0.0, 0.0], [view([(60, 0), (200, 40)], 35.0), view([(30, 0), (200, 40)], 30.0)]),
    ("off-the-line-steers-back", "Two metres right of the line on a straight: pursuit and the correction both steer left; then two metres left, both right.",
     level(), [0.0, 0.0], [view([(180, 0)], 25.0, -2.0), view([(180, 0)], 25.0, 2.0)]),
    ("a-car-ahead-in-the-lane-caps-the-speed",
     "A rival 20 m ahead at 20 m/s in the car's lane caps the target at its speed; the same rival 4 m to the left does not.",
     level(), [0.0, 0.0], [view([(180, 0)], 30.0, rivals=[(20.0, 0.5, 20.0)]),
                           view([(180, 0)], 30.0, rivals=[(20.0, 4.0, 20.0)]),
                           view([(180, 0)], 30.0, rivals=[(-10.0, 0.0, 10.0)])]),
    ("wander-drifts-the-aim", "Wander 2 m with stated phases: at three moments the aim sits at three places across the line.",
     level(wander=2.0), [0.7, 2.1], [view([(180, 0)], 20.0, time=t) for t in (0.0, 4.0, 9.0)]),
    ("at-the-limit-the-wheels-turn-no-further",
     "A right arc of 15 m radius at 30 m/s: the arc asks more than the grip gives, and the wheels stop at the limit the measured grip and slip allow.",
     level(), [0.0, 0.0], [view([(200, -15)], 30.0)]),
    ("the-aim-keeps-to-the-tarmac", "Wander 6 m on a road with 3 m of tarmac each side: the aim is held a metre inside the edge.",
     level(wander=6.0), [math.pi / 2, math.pi / 2], [view([(180, 0)], 20.0, width=3.0)]),
    ("a-slow-car-aims-close", "At 5 m/s the lookahead's seconds come to less than the nearest aim, which holds it at 8 m.",
     level(), [0.0, 0.0], [view([(10, 0), (200, 30)], 5.0)]),
]


#: Points of road a held vector shows: 60 metres, enough for its bend and
#: its aim, and a file a reader can open.
SHORT = 20


def held(pieces, speed, cross_track, frames, **rest) -> list[dict]:
    """The same road shown `frames` times, a frame apart, the car held off it
    by `cross_track`: what an error that stays there does to the PID."""
    return [view(pieces, speed, cross_track, time=i / 60.0, horizon=SHORT, **rest) for i in range(frames)]


CASES += [
    ("pid-sums-an-offset-that-stays",
     "Held 0.3 m right of the line on a straight for half a second: the integral grows every frame, so the steering does; the first frame has no derivative.",
     level(), [0.0, 0.0], held([(180, 0)], 20.0, -0.3, 30), {}),
    ("proportional-only-does-not",
     "The same car with the PID's integral and derivative off: the steering is the same every frame.",
     level(), [0.0, 0.0], held([(180, 0)], 20.0, -0.3, 10), {"full_pid": False}),
    ("the-pedal-sums-a-speed-it-cannot-reach",
     "Half a metre a second under the speed a 60 m arc allows, frame after frame: the proportional term asks a quarter of the throttle, and the integral adds to it every frame.",
     level(), [0.0, 0.0], held([(200, 60)], 22.0, 0.0, 40), {}),
    ("heat-rolls-round-a-car-ahead",
     "A slower car 30 m ahead, just left of the line: the ball rolls right, a frame at a time, and the car means to be there.",
     level(), [0.0, 0.0], held([(180, 0)], 30.0, 0.0, 45, rivals=[(30.0, 0.5, 20.0)]), {}),
    ("heat-goes-round-two-cars-at-once",
     "Two slower cars ahead, one each side of the line: the coolest place is the gap between them, so the ball stays near the line -- where one rival at a time would pull out beside the nearer.",
     level(), [0.0, 0.0], held([(180, 0)], 30.0, 0.0, 60, rivals=[(25.0, 2.5, 20.0), (40.0, -2.5, 20.0)]), {}),
    ("one-rival-at-a-time",
     "Without the heat line: the nearer car on the line is passed on its roomier side, and the second is not looked at until the first is.",
     level(), [0.0, 0.0], held([(180, 0)], 30.0, 0.0, 40, rivals=[(25.0, 1.0, 20.0), (40.0, -2.5, 20.0)]), {"heat_vision": False}),
]


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: derive.py <directory>", file=sys.stderr)
        return 2
    target = pathlib.Path(argv[1])
    for case in CASES:
        name, why, lvl, phases, views = case[:5]
        flags = case[5] if len(case) > 5 else {}
        driver = Third(lvl, KNOWN, phases, flags)
        frames = [{"view": v, "expect": driver.decide(v)} for v in views]
        vector = {"name": name, "why": why,
                  "driver": {"level": lvl, "known": KNOWN, "drift_phases": phases, "switches": flags}, "frames": frames}
        (target / f"{name}.json").write_text(json.dumps(vector, indent=1) + "\n")
    print(f"{len(CASES)} vector(s) written to {target}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
