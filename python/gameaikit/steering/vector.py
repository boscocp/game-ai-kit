"""A two-dimensional vector: the arithmetic steering is written in.

The handful of operations Godot's `Vector2` gives the GDScript side, with the
same meaning, so a line of one reads like the line of the other. One
difference is not hidden: these are 64-bit floats and Godot's are 32-bit
(`docs/godot/vector2-is-single-precision.md`), which is why the steering
vectors carry a tolerance sized for single precision.

When not to use it: anything that needs speed over readability. A list of a
thousand of these is a thousand objects; `array` or NumPy is the answer then.
"""

from __future__ import annotations

import dataclasses
import math


@dataclasses.dataclass(frozen=True)
class Vec:
    """A point or a direction in the plane."""

    x: float
    y: float

    def __add__(self, other: Vec) -> Vec:
        return Vec(self.x + other.x, self.y + other.y)

    def __sub__(self, other: Vec) -> Vec:
        return Vec(self.x - other.x, self.y - other.y)

    def __mul__(self, factor: float) -> Vec:
        return Vec(self.x * factor, self.y * factor)

    def __truediv__(self, divisor: float) -> Vec:
        return Vec(self.x / divisor, self.y / divisor)

    def length(self) -> float:
        """How long it is."""
        return math.hypot(self.x, self.y)

    def distance_to(self, other: Vec) -> float:
        """How far `other` is."""
        return (other - self).length()

    def dot(self, other: Vec) -> float:
        """The dot product: how far this goes along `other`, times its length."""
        return self.x * other.x + self.y * other.y

    def is_finite(self) -> bool:
        """Neither part infinite nor NaN."""
        return math.isfinite(self.x) and math.isfinite(self.y)

    def normalized(self) -> Vec:
        """Length one, the same way; zero for zero -- and, as Godot answers,
        zero for a vector that is not finite."""
        size = self.length()
        if size == 0.0 or not math.isfinite(size):
            return Vec(0.0, 0.0)
        return self / size

    def limit_length(self, limit: float) -> Vec:
        """Shortened to `limit` if it is longer, else unchanged."""
        size = self.length()
        if size > limit and size > 0.0:
            return self * (limit / size)
        return self


ZERO = Vec(0.0, 0.0)
