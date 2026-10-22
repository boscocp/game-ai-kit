"""Three errands a bot may leave its post for: back for rounds and health, out for a power weapon, or into hiding to heal.

The tier-1 half of `godot/addons/ai_teamwork/errand_choice.gd`: each errand
is a gain less its costs -- going back is worth the rounds spent and the
health missing -- and the larger is taken when above zero. A team
sends one bot to fetch, the one the weapon is worth most to.
"""

from __future__ import annotations

import dataclasses

NONE, RESUPPLY, FETCH, HIDE = "", "resupply", "fetch power", "hide to heal"


@dataclasses.dataclass
class Weights:
    """What each part of a weighing is worth, in score points."""

    resupply_walk: float = 0.05
    leave_holding: float = 0.3
    leave_attacking: float = 0.5
    health_worth: float = 1.0
    power_worth: float = 1.0
    power_walk: float = 0.08
    power_danger: float = 0.3
    hide_second: float = 0.02


@dataclasses.dataclass
class Resupply:
    """What going back is weighed on."""

    spent: float = 0.0
    hurt: float = 0.0
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


@dataclasses.dataclass
class Hide:
    """What hiding to heal is weighed on."""

    available: bool = False
    hurt: float = 0.0
    walk_seconds: float = 0.0
    wait_seconds: float = 0.0
    attacking: bool = False


def weigh_hide(facts: Hide, weights: Weights) -> list[float]:
    """[gain, seconds away, cost of leaving, score]; all nothing when unavailable."""
    if not facts.available:
        return [0.0, 0.0, 0.0, 0.0]
    gain = facts.hurt * weights.health_worth
    away = facts.walk_seconds + facts.wait_seconds
    leaving = weights.leave_attacking if facts.attacking else weights.leave_holding
    return [gain, away, leaving, gain - away * weights.hide_second - leaving]


def weigh_resupply(facts: Resupply, weights: Weights) -> list[float]:
    """[gain, walk seconds, cost of leaving, score]."""
    gain = facts.spent + facts.hurt * weights.health_worth + (weights.power_worth if facts.earned_power else 0.0)
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


def choose(resupply_score: float, fetch_score: float, hide_score: float = 0.0) -> str:
    """The highest above zero; of equals back, then fetch, then hide."""
    best = max(resupply_score, fetch_score, hide_score)
    if best <= 0.0:
        return NONE
    if resupply_score >= best:
        return RESUPPLY
    return FETCH if fetch_score >= best else HIDE
