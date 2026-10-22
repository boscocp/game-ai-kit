"""Who does what once a fight starts: role requests granted or refused.

The tier-1 half of `godot/addons/ai_teamwork/role_arbiter.gd`: at most
`max_flankers` flanks, best score first; everyone else who can shoot
shoots; and if no one would, the best-scoring who can is made a shooter
[McIntosh 2015]. Off, everyone who can shoot does.
"""

from __future__ import annotations

SHOOTER = "shooter"
FLANKER = "flanker"
NONE = "none"


def grant(requests: list[dict], use_arbiter: bool, max_flankers: int = 1) -> list[str]:
    """The role each request gets, in the requests' order."""
    granted = [SHOOTER if each["can_shoot"] else NONE for each in requests]
    if not use_arbiter:
        return granted
    flankers = 0
    for index in _by_score(requests):
        if requests[index]["role"] == FLANKER and flankers < max_flankers:
            granted[index] = FLANKER
            flankers += 1
    if SHOOTER not in granted:
        for index in _by_score(requests):
            if requests[index]["can_shoot"] and granted[index] == FLANKER:
                granted[index] = SHOOTER
                break
    return granted


def _by_score(requests: list[dict]) -> list[int]:
    return sorted(range(len(requests)), key=lambda index: (-requests[index]["score"], index))
