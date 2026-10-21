"""Melder's heat vision, as `ai_steering`'s `HeatLine`: an array of heat
across a road and a ball that rolls to its coolest place.

Positions are metres left of the line (negative: right). Heat grows with the
square of the distance from the line, is high at the edges, and has a hump
wherever a car is; the ball is pushed down the slope under it and slowed by
drag, so it keeps its momentum ("The Heat Vision System for Racing AI",
Game AI Pro 2013).
"""

from __future__ import annotations

import math

CELLS = 41


class HeatLine:
    """The array, rebuilt each decision, and the ball, which is kept."""

    def __init__(self) -> None:
        self.line_heat = 0.15
        self.edge_heat = 4.0
        self.edge_reach = 1.5
        self.push = 6.0
        self.drag = 3.0
        self.heat: list[float] = []
        self.positions: list[float] = []
        self.ball = 0.0
        self.ball_speed = 0.0

    def build(self, room_left: float, room_right: float) -> None:
        """Lay the array across the road, with the line's and the edges' heat."""
        self.heat, self.positions = [], []
        for cell in range(CELLS):
            share = cell / (CELLS - 1)
            at = -room_right + (room_left + room_right) * share
            self.positions.append(at)
            from_edge = min(room_left - at, at + room_right)
            near_edge = self.edge_heat * max(0.0, 1.0 - from_edge / self.edge_reach)
            self.heat.append(self.line_heat * at * at + near_edge)

    def heat_up(self, at: float, strength: float, spread: float) -> None:
        """A hump of `strength` centred `at`, falling off over `spread`."""
        for cell, position in enumerate(self.positions):
            apart = (position - at) / spread
            self.heat[cell] += strength * math.exp(-apart * apart)

    def roll(self, step: float) -> None:
        """The ball `step` seconds down the slope, kept on the road."""
        self.ball_speed += (-self.push * self.slope_at(self.ball) - self.drag * self.ball_speed) * step
        self.ball += self.ball_speed * step
        lowest, highest = self.positions[0], self.positions[-1]
        if self.ball < lowest or self.ball > highest:
            self.ball = max(lowest, min(highest, self.ball))
            self.ball_speed = 0.0

    def slope_at(self, at: float) -> float:
        """The heat's slope at `at`, per metre, across one cell centred on it."""
        last = len(self.positions) - 1
        cell = (self.positions[last] - self.positions[0]) / last
        if cell <= 0.0:
            return 0.0
        return (self.heat_at(at + cell / 2.0) - self.heat_at(at - cell / 2.0)) / cell

    def heat_at(self, at: float) -> float:
        """The heat at `at`, read between the two cells either side of it."""
        last = len(self.positions) - 1
        width = self.positions[last] - self.positions[0]
        place = max(0.0, min(float(last), (at - self.positions[0]) / width * last))
        below = min(math.floor(place), last - 1)
        return self.heat[below] + (self.heat[below + 1] - self.heat[below]) * (place - below)
