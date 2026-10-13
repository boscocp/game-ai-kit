"""How true is "near"? A membership function answers with a number in [0, 1].

A boolean asks whether a guard is alerted. A fuzzy set asks *how much*, and
the answer slopes: a player four cells away is a little near and mostly not.
That slope is the whole difference, and it is why a guard written with fuzzy
sets turns its head slowly where a boolean guard snaps.

One shape serves every set here: the **trapezoid**, four points along the
input -- where the slope starts rising, where it reaches 1, where it starts
falling, where it reaches 0 again. A triangle is a trapezoid whose top is one
point wide, and a shoulder is one whose rising edge is vertical. Three numbers
mean a triangle and four a trapezoid, which is the convention of the library
this one was rewritten from (see ADR 0011).

Evaluating a set is constant time; fuzzifying a value is one evaluation per
set of its variable.

When not to use it: when the input is genuinely discrete. "Has a key" is not
a matter of degree, and a fuzzy set over it is a boolean in disguise.
"""

from __future__ import annotations

import dataclasses
import math


class FuzzyError(ValueError):
    """A controller that cannot be evaluated, said in one sentence with a code.

    The codes are shared with the GDScript side (`FuzzyRuleBase.problem`), so
    a test on either side can tell which rule refused, rather than matching on
    wording that a later edit is free to improve.
    """


@dataclasses.dataclass(frozen=True)
class FuzzySet:
    """One linguistic term -- "near", "dark", "alarmed" -- as a trapezoid."""

    name: str
    rise_start: float
    rise_end: float
    fall_start: float
    fall_end: float

    @classmethod
    def from_points(cls, name: str, points: list[float]) -> FuzzySet:
        """A set from three points (a triangle) or four (a trapezoid).

        A triangle's middle point is both the end of its rise and the start
        of its fall, which is exactly what makes it a trapezoid with no top.
        """
        if len(points) == 3:
            points = [points[0], points[1], points[1], points[2]]
        if len(points) != 4:
            raise FuzzyError(f"F1 set {name!r} needs three or four points, "
                             f"not {len(points)}")
        found = cls(name, *(float(point) for point in points))
        found.check()
        return found

    def check(self) -> None:
        """Refuse a shape whose points do not run left to right.

        A falling edge before its rising edge describes no shape at all, and
        `degree` would answer with numbers outside [0, 1] rather than fail.
        """
        points = [self.rise_start, self.rise_end, self.fall_start, self.fall_end]
        if any(math.isnan(point) or math.isinf(point) for point in points):
            raise FuzzyError(f"F1 set {self.name!r} has a point that is not a number")
        if points != sorted(points):
            raise FuzzyError(f"F1 set {self.name!r} has points out of order: {points}")

    def degree(self, value: float) -> float:
        """How far `value` belongs to this set, from 0 (not at all) to 1.

        The flat top is tested before either slope, and that order is what
        lets a vertical edge -- `rise_start == rise_end`, a shoulder -- answer
        1 at its corner instead of dividing by zero.
        """
        if value < self.rise_start or value > self.fall_end:
            return 0.0
        if self.rise_end <= value <= self.fall_start:
            return 1.0
        if value < self.rise_end:
            return (value - self.rise_start) / (self.rise_end - self.rise_start)
        return (self.fall_end - value) / (self.fall_end - self.fall_start)


@dataclasses.dataclass(frozen=True)
class Variable:
    """A quantity the controller reads or writes, and the terms that describe it.

    `minimum` and `maximum` mean different things on the two sides. An input
    is **clamped** into them before it is fuzzified, because a guard should
    not stop worrying about a player for being further away than the designer
    drew. An output is **sampled** across them, `samples` times, when the
    centroid is taken; an input leaves `samples` at 0.
    """

    name: str
    minimum: float
    maximum: float
    sets: tuple[FuzzySet, ...]
    samples: int = 0

    def check(self, is_output: bool) -> None:
        """Refuse a variable that cannot be read or cannot be sampled."""
        if not self.minimum < self.maximum:
            raise FuzzyError(f"F2 variable {self.name!r} has an empty range")
        if not self.sets:
            raise FuzzyError(f"F2 variable {self.name!r} has no sets")
        names = [one.name for one in self.sets]
        if len(set(names)) != len(names):
            raise FuzzyError(f"F2 variable {self.name!r} names a set twice")
        if is_output and self.samples < 2:
            raise FuzzyError(f"F3 output {self.name!r} needs at least two samples")
        for one in self.sets:
            one.check()

    def set_named(self, name: str) -> FuzzySet | None:
        """The set called `name`, or None."""
        return next((one for one in self.sets if one.name == name), None)

    def fuzzify(self, value: float) -> dict[str, float]:
        """Every set's degree for one crisp value, clamped into the range first."""
        clamped = min(max(value, self.minimum), self.maximum)
        return {one.name: one.degree(clamped) for one in self.sets}
