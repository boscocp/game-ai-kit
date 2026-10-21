"""Whether a squad attacks, holds or retreats, and its retreat in two waves.

The tier-1 half of `godot/addons/ai_teamwork/squad_confidence.gd` [Karlsson
2021]: friendly strength over enemy strength, plus kills, minus losses; a gap
between entering and leaving each state; and a retreat split by place in the
squad, one half moving while the other covers.
"""

from __future__ import annotations

import dataclasses

ATTACK, HOLD, RETREAT = "attack", "hold", "retreat"


@dataclasses.dataclass
class Facts:
    friendly_strength: float
    enemy_strength: float
    kills: int = 0
    losses: int = 0


@dataclasses.dataclass
class Thresholds:
    attack_at: float = 1.3
    keep_attacking_at: float = 1.1
    retreat_at: float = 0.7
    recover_at: float = 1.0
    per_kill: float = 0.25
    per_loss: float = 0.25
    least_enemy: float = 0.5


def confidence(facts: Facts, thresholds: Thresholds) -> float:
    """The squad's confidence now."""
    ratio = facts.friendly_strength / max(facts.enemy_strength, thresholds.least_enemy)
    return ratio + thresholds.per_kill * facts.kills - thresholds.per_loss * facts.losses


def next_state(previous: str, value: float, thresholds: Thresholds, may_retreat: bool) -> str:
    """The state after `previous` at confidence `value`; `may_retreat` False
    holds where it would retreat."""
    if previous == RETREAT and value < thresholds.recover_at and may_retreat:
        return RETREAT
    if value <= thresholds.retreat_at:
        return RETREAT if may_retreat else HOLD
    if value >= thresholds.attack_at:
        return ATTACK
    if previous == ATTACK and value >= thresholds.keep_attacking_at:
        return ATTACK
    return HOLD


def waves(members: list[int], phase: int) -> tuple[list[int], list[int]]:
    """(moving, covering) for `members` in the squad's order."""
    moving, covering = [], []
    for index, member in enumerate(members):
        (moving if len(members) == 1 or index % 2 == phase % 2 else covering).append(member)
    return moving, covering
