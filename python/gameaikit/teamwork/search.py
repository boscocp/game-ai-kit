"""Who searches where: spots divided among searchers, and a cap on how
many go to the last known position.

The tier-1 half of `godot/addons/ai_teamwork/search_coordinator.gd`, read
the same way: a searcher's score for a spot is worth times WORTH less its
walk times TRAVEL; with claims, the best free pair is taken first and no
two searchers share a spot; without, each takes its own best [Welsh 2015].
"""

from __future__ import annotations

import dataclasses
import math


@dataclasses.dataclass
class Weights:
    """What a score is made of."""

    worth: float = 10.0
    travel: float = 0.2


def score(spot: dict, cost: float, weights: Weights) -> float:
    """A searcher's score for a spot; -inf when it is not worth going to."""
    if spot["searched"] or spot["worth"] <= 0.0 or not math.isfinite(cost):
        return -math.inf
    return spot["worth"] * weights.worth - cost * weights.travel


def assign(spots: list[dict], costs: list[list[float]], use_claims: bool, weights: Weights) -> list[int]:
    """The spot index each searcher is given, in their order; -1, none."""
    if not use_claims:
        return [_best_spot(spots, row, set(), weights) for row in costs]
    given = [-1] * len(costs)
    taken: set[int] = set()
    for _ in range(len(costs)):
        searcher, spot = _best_pair(spots, costs, given, taken, weights)
        if searcher == -1:
            break
        given[searcher] = spot
        taken.add(spot)
    return given


def grant_last_known(costs: list[float], cap: int) -> list[int]:
    """The `cap` nearest searchers, as indices in their order."""
    order = sorted(range(len(costs)), key=lambda index: (costs[index], index))
    return sorted(order[:max(cap, 0)])


def _best_spot(spots: list[dict], row: list[float], taken: set[int], weights: Weights) -> int:
    best, best_score = -1, -math.inf
    for spot, facts in enumerate(spots):
        value = score(facts, row[spot], weights)
        if spot not in taken and value > best_score:
            best, best_score = spot, value
    return best


def _best_pair(spots, costs, given, taken, weights) -> tuple[int, int]:
    best, best_score = (-1, -1), -math.inf
    for searcher, row in enumerate(costs):
        spot = _best_spot(spots, row, taken, weights) if given[searcher] == -1 else -1
        if spot != -1 and score(spots[spot], row[spot], weights) > best_score:
            best, best_score = (searcher, spot), score(spots[spot], row[spot], weights)
    return best
