"""How aware a guard is of one stimulus, and the phase that number reads as.

The tier-1 half of `godot/addons/ai_perception/awareness.gd`: rising by the
rate it is given while perceived, falling at its phase's decay, or else the
row's, but never
past the floor of the phase below in one step [Leonard 2003], held at the
caution floor for the row's seconds after an alert [Alexander 2009;
Ubisoft 2024]. The phase is a pure reading of the number [Welsh 2013].
"""

from __future__ import annotations

import dataclasses
import math


@dataclasses.dataclass
class Awareness:
    """The number, and until when the caution floor holds."""

    value: float = 0.0
    caution_until: float = -math.inf

    def step(self, row: dict, perceived: bool, rate: float, seconds: float, now: float) -> None:
        """One step of `seconds`, ending at `now`."""
        peak = row["peak"]
        if perceived:
            self.value = min(peak, self.value + max(rate, 0.0) * peak * seconds)
        else:
            self.value = max(self.value - decay_in(self.value, row) * peak * seconds, self.lowest_after_falling(row, now))
        if phase(self.value, row) == len(row["phases"]) - 1:
            self.caution_until = now + row["caution"]["seconds"]

    def lowest_after_falling(self, row: dict, now: float) -> float:
        """The floor of the phase below, raised to the caution floor while it holds."""
        below = max(phase(self.value, row) - 1, 0)
        lowest = row["phases"][below]["at"] * row["peak"]
        if now < self.caution_until:
            lowest = max(lowest, row["caution"]["floor"] * row["peak"])
        return min(lowest, self.value)


def decay_in(number: float, row: dict) -> float:
    """How fast `number` falls: its phase's own decay, or the row's."""
    return row["phases"][phase(number, row)].get("decay", row["decay"])


def phase(number: float, row: dict) -> int:
    """The index of the last phase whose threshold `number` has reached."""
    found = 0
    for index, each in enumerate(row["phases"]):
        if number >= each["at"] * row["peak"]:
            found = index
    return found
