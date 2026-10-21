"""A team's hold on the map: friends add, enemies subtract, both fading.

The tier-1 half of `godot/addons/ai_teamwork/team_influence.gd`: every
source spreads its strength over a radius with a linear falloff, measured to
each cell's centre, and the sources add up [Mark 2015].
"""

from __future__ import annotations

import math


class TeamInfluence:
    """A grid of `width` by `height` cells of `cell_size` metres, its corner at
    `origin`, each source reaching `radius` metres."""

    def __init__(self, width: int, height: int, cell_size: float, origin: tuple[float, float], radius: float):
        self.width, self.height = max(width, 0), max(height, 0)
        self.cell_size, self.origin, self.radius = cell_size, origin, radius
        self._values = [0.0] * (self.width * self.height)

    def cell_of(self, place: tuple[float, float]) -> tuple[int, int]:
        """The cell a point falls in, which may be off the map."""
        return (math.floor((place[0] - self.origin[0]) / self.cell_size),
                math.floor((place[1] - self.origin[1]) / self.cell_size))

    def centre_of(self, cell: tuple[int, int]) -> tuple[float, float]:
        """The middle of a cell, in metres."""
        return (self.origin[0] + (cell[0] + 0.5) * self.cell_size,
                self.origin[1] + (cell[1] + 0.5) * self.cell_size)

    def add_source(self, place: tuple[float, float], strength: float) -> None:
        """Add `strength` at `place`: positive a friend, negative an enemy."""
        reach = math.ceil(self.radius / self.cell_size)
        column0, row0 = self.cell_of(place)
        for row in range(max(row0 - reach, 0), min(row0 + reach + 1, self.height)):
            for column in range(max(column0 - reach, 0), min(column0 + reach + 1, self.width)):
                centre = self.centre_of((column, row))
                distance = math.hypot(place[0] - centre[0], place[1] - centre[1])
                if distance < self.radius:
                    self._values[row * self.width + column] += strength * (1.0 - distance / self.radius)

    def value_at(self, place: tuple[float, float]) -> float:
        """The value at the cell holding `place`; zero off the map."""
        column, row = self.cell_of(place)
        if not (0 <= column < self.width and 0 <= row < self.height):
            return 0.0
        return self._values[row * self.width + column]
