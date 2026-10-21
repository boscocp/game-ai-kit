"""Which objective each squad goes to: weighed objectives with an ideal number
of bots, filled greedily by the cheapest squad first.

The tier-1 half of `godot/addons/ai_teamwork/team_commander.gd` [Straatman et
al. 2013; Isla, Halo 3 objectives]. A squad's cost for an objective is its
distance over the objective's priority; the cheapest pair is assigned, the
objective's room shrinks by the squad's size, and again.
"""

from __future__ import annotations

import dataclasses
import math

NOBODY, US, THEM = 0, 1, -1


@dataclasses.dataclass
class Objective:
    """One objective as the commander sees it: who holds it, how many bots it
    should have, and the team's influence there (below zero, the enemy's)."""

    id: str
    position: tuple[float, float]
    held_by: int = NOBODY
    ideal: int = 2
    influence: float = 0.0


@dataclasses.dataclass
class SquadReport:
    """One squad as it reports up: where it is, how many it has."""

    id: str
    position: tuple[float, float]
    size: int = 1


@dataclasses.dataclass
class Weights:
    """What each objective is worth; `nearest_metres` keeps a squad standing
    on one from costing zero."""

    take: float = 3.0
    hold: float = 1.0
    defend: float = 2.0
    nearest_metres: float = 1.0


def priority_of(objective: Objective, weights: Weights) -> float:
    """What `objective` is worth now."""
    if objective.held_by != US:
        return weights.take / (1.0 + max(0.0, -objective.influence))
    return weights.hold + weights.defend * max(0.0, -objective.influence)


def _distance(one: tuple[float, float], other: tuple[float, float]) -> float:
    return math.hypot(one[0] - other[0], one[1] - other[1])


def assign(squads: list[SquadReport], objectives: list[Objective], weights: Weights) -> dict[str, str]:
    """The objective id each squad is sent to, by squad id."""
    if not objectives:
        return {}
    worth = [priority_of(objective, weights) for objective in objectives]
    room = [objective.ideal for objective in objectives]
    waiting, orders = list(squads), {}
    while waiting:
        open_ = [index for index, left in enumerate(room) if left > 0] or list(range(len(objectives)))
        best, best_cost = None, math.inf
        for squad_index, squad in enumerate(waiting):
            for index in open_:
                distance = max(_distance(squad.position, objectives[index].position), weights.nearest_metres)
                cost = distance / worth[index]
                if cost < best_cost:
                    best, best_cost = (squad_index, index), cost
        squad = waiting.pop(best[0])
        orders[squad.id] = objectives[best[1]].id
        room[best[1]] -= squad.size
    return orders


def nearest(squads: list[SquadReport], objectives: list[Objective]) -> dict[str, str]:
    """Without a commander: each squad to the nearest objective not ours, or
    the nearest of all when every one is ours."""
    orders = {}
    for squad in squads:
        pool = [objective for objective in objectives if objective.held_by != US] or objectives
        if pool:
            orders[squad.id] = min(pool, key=lambda objective: _distance(squad.position, objective.position)).id
    return orders
