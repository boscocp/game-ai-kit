"""Bots that cooperate: where each stands, where each squad goes, and when a
squad falls back.

The tier-1 half of `ai_teamwork`, standard library only. Each technique is a
function of facts a game has already measured -- distances, who covers whom,
who holds what -- so it can be run, and checked, without a 3D engine (ADR
0018). `spec/vectors/teamwork/` holds this and the GDScript addon to the same
answers.

    positions.py    candidates, conditions, Killzone's weights, claims
    influence.py    a team's additive hold on the map
    commander.py    objectives with an ideal number of bots, filled greedily
    confidence.py   attack, hold or retreat, and the retreat in waves
"""

from . import commander, confidence, influence, positions

__all__ = ["commander", "confidence", "influence", "positions"]
