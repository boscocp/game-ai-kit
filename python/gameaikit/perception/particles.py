"""Where the guards believe the target is, as a cloud of particles.

The tier-1 half of `godot/addons/ai_perception/particle_belief.gd`, which
says the why. A particle filter [Thrun 2002; AIMA 4th ed., ch. 14]: each
particle is one guess at the target's node. Each unseen step every particle
moves by the transition model (walk on, else turn, else stay), is weighed by
the sensor model (0 where a guard sees and saw no one; `unheard` where a
guard would have heard it and heard nothing; else 1), and the cloud is
resampled systematically. Every probability is a constant: nothing here is
fitted (invariant 6).
"""

from __future__ import annotations

from .draws import ParticleDraws
from gameaikit.techniques import technique

#: How likely a particle walks on: to a neighbour other than the one it came from.
WALK_ON = 0.7
#: How likely it turns instead: to any neighbour, back included. Else it stays.
TURN = 0.2
#: What a particle weighs where a guard would have heard it and heard nothing.
UNHEARD = 0.3
#: How many particles, unless the game says otherwise.
COUNT = 256


@technique("particle-filter", "the same question as a cloud of weighted particles")
class ParticleBelief:
    """A cloud of `count` particles over a graph given as `neighbours[i]` lists."""

    def __init__(self, neighbours: list[list[int]], count: int = COUNT, seed: int = 1) -> None:
        self.neighbours = neighbours
        self.count = max(count, 1)
        self.walk_on, self.turn, self.unheard = WALK_ON, TURN, UNHEARD
        self.draws = ParticleDraws(seed)
        self.nodes: list[int] = []
        self.came_from: list[int] = []
        self.weights: list[float] = []
        self.shares: list[float] = []
        self.emptied: list[int] = []
        self.reseeded = False
        self._place_evenly(list(range(len(neighbours))))
        self.weights = [1.0 / self.count] * len(self.nodes)

    def collapse(self, node: int) -> None:
        """Every particle on `node`, with no heading."""
        self.nodes = [node] * self.count
        self.came_from = [-1] * self.count
        self.weights = [1.0 / self.count] * self.count
        self.emptied = []
        self.reseeded = False
        self._count_shares()

    def step_unseen(self, seen: list[int], unheard: list[int]) -> None:
        """Move, weigh by what was not seen and not heard, resample -- or reseed."""
        for index in range(len(self.nodes)):
            self._move(index)
        weights = self._weigh(set(seen), set(unheard))
        total = sum(weights)
        self.reseeded = total <= 0.0
        if self.reseeded:
            seen_set = set(seen)
            unseen = [node for node in range(len(self.neighbours)) if node not in seen_set]
            self._place_evenly(unseen if unseen else list(range(len(self.neighbours))))
            self.weights = [0.0] * len(self.nodes)
        else:
            self.weights = [weight / total for weight in weights]
            self._resample()
        self._count_shares()

    def _move(self, index: int) -> None:
        here = self.nodes[index]
        edges = self.neighbours[here]
        chance = self.draws.uniform()
        if chance < self.walk_on:
            choices = [node for node in edges if node != self.came_from[index]] or edges
        elif chance < self.walk_on + self.turn:
            choices = edges
        else:
            return
        if choices:
            self.nodes[index] = choices[self.draws.index(len(choices))]
            self.came_from[index] = here

    def _weigh(self, seen: set[int], unheard: set[int]) -> list[float]:
        weights, self.emptied = [], []
        for node in self.nodes:
            if node in seen:
                weights.append(0.0)
                if node not in self.emptied:
                    self.emptied.append(node)
            else:
                weights.append(self.unheard if node in unheard else 1.0)
        return weights

    def _resample(self) -> None:
        stride = 1.0 / len(self.nodes)
        start = self.draws.uniform() * stride
        source, reached = 0, self.weights[0]
        nodes, came_from = [], []
        for index in range(len(self.nodes)):
            mark = start + index * stride
            while mark > reached and source < len(self.nodes) - 1:
                source += 1
                reached += self.weights[source]
            nodes.append(self.nodes[source])
            came_from.append(self.came_from[source])
        self.nodes, self.came_from = nodes, came_from

    def _place_evenly(self, candidates: list[int]) -> None:
        self.nodes = [candidates[index * len(candidates) // self.count] for index in range(self.count)] if candidates else []
        self.came_from = [-1] * len(self.nodes)
        self._count_shares()

    def _count_shares(self) -> None:
        self.shares = [0.0] * len(self.neighbours)
        for node in self.nodes:
            self.shares[node] += 1.0 / len(self.nodes)
