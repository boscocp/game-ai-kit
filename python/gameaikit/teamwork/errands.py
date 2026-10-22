"""Two errands a bot may leave its post for: back for rounds, or out for a power weapon.

The tier-1 half of `godot/addons/ai_teamwork/errand_choice.gd`: each errand
is a gain less its costs, and the larger is taken when above zero. A team
sends one bot to fetch, the one the weapon is worth most to.
"""

from __future__ import annotations

import dataclasses

NONE, RESUPPLY, FETCH = "", "resupply", "fetch power"


@dataclasses.dataclass
class Weights:
    """What each part of a weighing is worth, in score points."""

    resupply_walk: float = 0.05
    leave_holding: float = 0.3
    leave_attacking: float = 0.5
    power_worth: float = 1.0
    power_walk: float = 0.08
    power_danger: float = 0.3


@dataclasses.dataclass
class Resupply:
    """What going back is weighed on."""

    spent: float = 0.0
    earned_power: bool = False
    walk_seconds: float = 0.0
    attacking: bool = False
    empty: bool = False


@dataclasses.dataclass
class Fetch:
    """What fetching is weighed on."""

    available: bool = False
    walk_seconds: float = 0.0
    enemies_near: int = 0


def weigh_resupply(facts: Resupply, weights: Weights) -> list[float]:
    """[gain, walk seconds, cost of leaving, score]."""
    gain = facts.spent + (weights.power_worth if facts.earned_power else 0.0)
    leaving = 0.0 if facts.empty else (weights.leave_attacking if facts.attacking else weights.leave_holding)
    return [gain, facts.walk_seconds, leaving, gain - facts.walk_seconds * weights.resupply_walk - leaving]


def weigh_fetch(facts: Fetch, weights: Weights) -> list[float]:
    """[worth, walk seconds, danger, score]; all nothing when it is not there."""
    if not facts.available:
        return [0.0, 0.0, 0.0, 0.0]
    danger = facts.enemies_near * weights.power_danger
    return [weights.power_worth, facts.walk_seconds, danger,
            weights.power_worth - facts.walk_seconds * weights.power_walk - danger]


def fetcher(scores: list[float]) -> int:
    """The index worth most, above zero, the first of equal; -1 nobody."""
    best, best_score = -1, 0.0
    for index, score in enumerate(scores):
        if score > best_score:
            best, best_score = index, score
    return best


def choose(resupply_score: float, fetch_score: float) -> str:
    """Back when above zero and no less than fetching; fetch when above zero."""
    if resupply_score > 0.0 and resupply_score >= fetch_score:
        return RESUPPLY
    if fetch_score > 0.0:
        return FETCH
    return NONE
