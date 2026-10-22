"""Where the guards believe the target is, over a neighbour list.

The tier-1 half of `godot/addons/ai_perception/belief_map.gd`: all of it on
a node the target was perceived or reported at; otherwise spread along
edges, zeroed where a guard sees, renormalised -- and reseeded evenly over
the unseen nodes when nothing is left [Isla 2013; McIntosh 2015].
"""

from __future__ import annotations


class BeliefMap:
    """One share per node of a graph given as `neighbours[i]` lists."""

    def __init__(self, neighbours: list[list[int]]):
        self.neighbours = neighbours
        self.shares = [1.0 / max(len(neighbours), 1)] * len(neighbours)
        self.reseeded = False

    def collapse(self, node: int) -> None:
        """All of the belief on `node`."""
        self.shares = [1.0 if index == node else 0.0 for index in range(len(self.shares))]
        self.reseeded = False

    def step_unseen(self, seen: list[int], spread: float) -> None:
        """Spread, zero what is seen, renormalise -- or reseed over the unseen."""
        moved = spread_along_edges(self.shares, self.neighbours, min(max(spread, 0.0), 1.0))
        for node in seen:
            moved[node] = 0.0
        total = sum(moved)
        self.reseeded = total <= 0.0
        if self.reseeded:
            seen_set = set(seen)
            unseen = len(moved) - len(seen_set)
            self.shares = [0.0 if node in seen_set else 1.0 / unseen for node in range(len(moved))]
        else:
            self.shares = [share / total for share in moved]


def spread_along_edges(shares: list[float], neighbours: list[list[int]], spread: float) -> list[float]:
    """One step of diffusion: each node keeps `1 - spread` and gives `spread`
    to its neighbours in equal parts; a node with none keeps it all."""
    moved = [0.0] * len(shares)
    for node, edges in enumerate(neighbours):
        given = spread if edges else 0.0
        moved[node] += shares[node] * (1.0 - given)
        for next_node in edges:
            moved[next_node] += shares[node] * given / len(edges)
    return moved
