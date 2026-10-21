"""How a bot gets past a body in its way: wait, go round, ask, or another spot.

The tier-1 half of `godot/addons/ai_teamwork/passage_choice.gd`: each way
priced in seconds lost, from facts the game measured; the cheapest taken,
the first of equal cost, and waiting when none is possible.
"""

from __future__ import annotations

import dataclasses
import math

WAIT, DETOUR, ASK, OTHER_SPOT = "wait", "go round", "ask to pass", "another spot"
WAYS = (WAIT, DETOUR, ASK, OTHER_SPOT)


@dataclasses.dataclass
class Facts:
    """One blocked bot and the body in its way, as the game measured them."""

    gap: float = 0.0
    leaving_speed: float = 0.0
    detour_metres: float = math.inf
    speed: float = 1.0
    teammate: bool = False
    refused: bool = False
    ask_seconds: float = 1.0
    spot_loss: float = math.inf
    points_a_second: float = 1.0


@dataclasses.dataclass
class Request:
    """A request to step aside: what it saves the asker, and what the
    teammate asked is doing."""

    saves: float = 0.0
    enemies_in_sight: int = 0
    shooting: bool = False
    reloading: bool = False
    covering_a_retreat: bool = False
    driven_by_a_person: bool = False
    room_to_step: bool = True


@dataclasses.dataclass
class Prices:
    """What moving costs the teammate asked, in seconds, by what it is doing."""

    step_seconds: float = 0.5
    per_enemy_seen: float = 2.0
    shooting: float = 1.5
    reloading: float = 0.5
    covering_a_retreat: float = 3.0


def cost_to_step_aside(request: Request, prices: Prices) -> float:
    """The teammate's seconds lost stepping aside; inf when it cannot move."""
    if request.driven_by_a_person or not request.room_to_step:
        return math.inf
    return (prices.step_seconds + prices.per_enemy_seen * request.enemies_in_sight
            + prices.shooting * request.shooting + prices.reloading * request.reloading
            + prices.covering_a_retreat * request.covering_a_retreat)


def answer(request: Request, prices: Prices) -> tuple[float, bool]:
    """The teammate's cost, and whether it steps aside: when that saves more."""
    cost = cost_to_step_aside(request, prices)
    return cost, request.saves > cost


def costs_of(facts: Facts) -> list[float]:
    """The seconds each way costs, in WAYS' order; inf where it cannot be taken."""
    return [facts.gap / facts.leaving_speed if facts.leaving_speed > 0.0 else math.inf,
            facts.detour_metres / max(facts.speed, 1e-6),
            facts.ask_seconds if facts.teammate and not facts.refused else math.inf,
            facts.spot_loss / max(facts.points_a_second, 1e-6)]


def choose(facts: Facts) -> tuple[list[float], str]:
    """Each way's cost and the cheapest, the first of equal cost; WAIT if none."""
    costs = costs_of(facts)
    chosen, best = WAIT, math.inf
    for way, cost in zip(WAYS, costs):
        if cost < best:
            best, chosen = cost, way
    return costs, chosen
