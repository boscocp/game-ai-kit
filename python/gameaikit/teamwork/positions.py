"""Where a bot should stand: candidates dropped by conditions, weighed, and
the best one nobody on its team has claimed.

The tier-1 half of `godot/addons/ai_teamwork/tactical_positions.gd`, read
the same way: the conditions in the order they are asked, then Killzone's
weighted sum [Beij & Straatman 2005], then the highest score. It reads facts,
not geometry -- whoever built a `Candidate` has already cast the rays.
"""

from __future__ import annotations

import dataclasses

KEPT = "kept"
TOO_FAR = "too_far"
OUTSIDE_AREA = "outside_area"
CLAIMED = "claimed"
EXPOSED = "exposed"


@dataclasses.dataclass
class Candidate:
    """One candidate point, as the facts the score needs."""

    id: str
    travel: float
    threat_distance: float = 0.0
    covered_from_main: bool = False
    fires_on_main: bool = False
    covered_from_others: float = 0.0
    in_area: bool = True
    claimed_by: int = -1


@dataclasses.dataclass
class Weights:
    """The weights and limits; the defaults are Killzone's worked example."""

    partial_cover: float = 40.0
    line_of_fire: float = 20.0
    other_cover: float = 20.0
    nearness: float = 20.0
    preferred_range: float = 10.0
    preferred_metres: float = 15.0
    range_band: float = 10.0
    max_travel: float = 20.0


@dataclasses.dataclass
class Choice:
    """Every candidate's status and score, and the index chosen (-1: none)."""

    statuses: list[str]
    scores: list[float]
    chosen: int


def status_of(bot_id: int, candidate: Candidate, weights: Weights, has_threat: bool, use_claims: bool) -> str:
    """The first condition `candidate` fails, or KEPT."""
    if candidate.travel > weights.max_travel:
        return TOO_FAR
    if not candidate.in_area:
        return OUTSIDE_AREA
    if use_claims and candidate.claimed_by not in (-1, bot_id):
        return CLAIMED
    if has_threat and not candidate.covered_from_main and not candidate.fires_on_main:
        return EXPOSED
    return KEPT


def score_of(candidate: Candidate, weights: Weights, has_threat: bool) -> float:
    """The weighted sum for a candidate that passed every condition."""
    score = weights.nearness * (1.0 - candidate.travel / weights.max_travel)
    if not has_threat:
        return score
    if candidate.fires_on_main:
        score += weights.partial_cover if candidate.covered_from_main else weights.line_of_fire
    score += weights.other_cover * candidate.covered_from_others
    off_range = abs(candidate.threat_distance - weights.preferred_metres)
    score += weights.preferred_range * max(0.0, 1.0 - off_range / weights.range_band)
    return score


def choose(bot_id: int, candidates: list[Candidate], weights: Weights, has_threat: bool, use_claims: bool) -> Choice:
    """Choose for bot `bot_id`; the first of equal best scores wins."""
    statuses, scores, chosen, best = [], [], -1, float("-inf")
    for index, candidate in enumerate(candidates):
        status = status_of(bot_id, candidate, weights, has_threat, use_claims)
        score = score_of(candidate, weights, has_threat) if status == KEPT else 0.0
        statuses.append(status)
        scores.append(score)
        if status == KEPT and score > best:
            best, chosen = score, index
    return Choice(statuses, scores, chosen)
