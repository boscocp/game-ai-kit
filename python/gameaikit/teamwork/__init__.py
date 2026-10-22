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
    aim.py          where on a body to aim, by the damage a shot is worth
    passage.py      how to get past a body: wait, go round, ask, or another spot
    action.py       what to do now: every action scored by its considerations
    errands.py      back for rounds or out for a power weapon, each a gain less its costs
    search.py       spots divided among searchers, and a cap on the last known position
    roles.py        shooter or flanker once a fight starts, one flanker at most
"""

from . import action, aim, commander, confidence, errands, influence, passage, positions, roles, search

__all__ = ["action", "aim", "commander", "confidence", "errands", "influence", "passage", "positions", "roles", "search"]
