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
    passage.py      how to get past a body: wait, go round, ask, or another spot
    search.py       spots divided among searchers, and a cap on the last known position
    roles.py        shooter or flanker once a fight starts, one flanker at most
    tokens.py       attack tokens: who may strike a target now, and when they give it back
    rings.py        engagement rings: where the others stand while one attacks

What one bot does now, the errands it leaves its post for (T101) and where
on a body it aims (T64) are the Python half of `ai_utility`: nothing in them
is about a team.
"""

from . import commander, confidence, influence, passage, positions, rings, roles, search, tokens

__all__ = ["commander", "confidence", "influence", "passage", "positions", "rings", "roles", "search", "tokens"]
