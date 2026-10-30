"""The director's machine: the player's intensity and the four phases (T90).

Booth's Left 4 Dead director, as his slides state it [Booth 2009]: estimate
the player's "emotional intensity", raise it by what happens to them, let it
decay "towards zero over time" -- but not while they are engaged -- and read
four phases from it:

    build_up      full threats, until the intensity reaches the peak
    sustain_peak  for a few seconds more
    peak_fade     minimal threats, until the intensity is below fade_below
    relax         for a while, or until the player has travelled on

Each step costs a constant: the events of the step, one subtraction, one
comparison. The numbers are all `spec/director/director.json`'s, and the
machine fits none of them (invariant 6).

When not to use it: as a difficulty setting. A director paces a run; it
does not make the guards better or worse at what they do.

    pacing = Pacing(read_spec())
    pacing.step([{"kind": "seen"}])
"""

from __future__ import annotations

import json
import math
import pathlib

SPEC = pathlib.Path(__file__).resolve().parents[3] / "spec" / "director" / "director.json"
PHASES = ("build_up", "sustain_peak", "peak_fade", "relax")


def read_spec(path: pathlib.Path = SPEC) -> dict:
    """The director's numbers, as `spec/director/director.json` writes them."""
    return json.loads(path.read_text())


def steps_of(spec: dict, seconds: float) -> int:
    """`seconds` as whole steps, so Python and Godot count a phase alike."""
    return round(seconds / spec["step_seconds"])


class Pacing:
    """The player's intensity and the phase read from it, one step at a time."""

    def __init__(self, spec: dict) -> None:
        self.spec = spec
        self.intensity = 0.0
        self.phase = PHASES[0]
        self.steps_in_phase = 0
        self.chased = False
        self.exit_metres = math.inf
        self.relax_from = math.inf

    def step(self, events: list[dict]) -> str:
        """Apply one step's `events`, decay, and move the phase on.

        Returns the phase entered this step, or "" when it stayed: the change
        is what the game acts on and what the vectors record.
        """
        for event in events:
            self.intensity += self.raised_by(event)
        if not self.chased:
            self.intensity -= self.spec["decay_per_second"] * self.spec["step_seconds"]
        self.intensity = min(max(self.intensity, 0.0), self.spec["most"])
        self.steps_in_phase += 1
        following = self._next_phase()
        if following == self.phase:
            return ""
        self.phase = following
        self.steps_in_phase = 0
        if following == "relax":
            self.relax_from = self.exit_metres
        return following

    def raised_by(self, event: dict) -> float:
        """How much `event` adds to the intensity; a `chase` or an `exit`
        adds nothing and is remembered instead."""
        kind = event["kind"]
        raises = self.spec["raise"]
        if kind == "chase":
            self.chased = bool(event["on"])
        elif kind == "exit":
            self.exit_metres = float(event["metres"])
        elif kind in ("seen", "heard"):
            return raises[kind]
        elif kind == "hurt":
            return raises["hurt_per_point"] * event["points"]
        elif kind == "search_near":
            return raises["search_near"] * self.spec["step_seconds"] * self.nearness(event["distance"])
        return 0.0

    def nearness(self, distance: float) -> float:
        """Booth's "inversely proportional to distance": 1 within
        `full_within`, falling as 1/distance after it, 0 beyond `radius`."""
        search = self.spec["search"]
        if distance > search["radius"]:
            return 0.0
        return min(1.0, search["full_within"] / max(distance, search["full_within"]))

    def _next_phase(self) -> str:
        spec = self.spec
        if self.phase == "build_up" and self.intensity >= spec["peak"]:
            return "sustain_peak"
        if self.phase == "sustain_peak" and self.steps_in_phase >= steps_of(spec, spec["sustain_seconds"]):
            return "peak_fade"
        if self.phase == "peak_fade" and self.intensity < spec["fade_below"]:
            return "relax"
        if self.phase == "relax" and self._relaxed():
            return "build_up"
        return self.phase

    def _relaxed(self) -> bool:
        long_enough = self.steps_in_phase >= steps_of(self.spec, self.spec["relax_seconds"])
        travelled = self.relax_from - self.exit_metres >= self.spec["relax_travel"]
        return long_enough or travelled


def replay(spec: dict, steps: int, events: list[dict]) -> dict:
    """Step a fresh machine `steps` times on `events` (each with its `step`).

    Returns the intensity after every step and every phase change, as the
    vectors in spec/vectors/director/ record them.
    """
    pacing = Pacing(spec)
    by_step: dict[int, list[dict]] = {}
    for event in events:
        by_step.setdefault(event["step"], []).append(event)
    curve: list[float] = []
    changes: list[dict] = []
    for number in range(steps):
        before = pacing.phase
        entered = pacing.step(by_step.get(number, []))
        curve.append(pacing.intensity)
        if entered:
            changes.append({"step": number, "from": before, "to": entered})
    return {"intensity": curve, "changes": changes}
