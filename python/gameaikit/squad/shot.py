"""One shot in the XCOM-style mode: cover, flanking, the hit chance and the die.

The same rules as `godot/game/squad/squad_cover.gd` and
`squad_combat.gd`, function for function, read from `rules.json` beside
this file (a copy of `spec/squad/rules.json`, held to it by a test).

Cover is read from the map's letters, the tactical map's own: `#` rock is
full cover, `T` trees half, and only a cell *beside* the target counts --
UFOpaedia's "cover only grants a defence bonus if a unit is standing
directly next to it". A cell of cover at step `d` from the target protects
against a shooter on that side, where the shooter's offset from the target
has a positive component along `d`. A shooter on no protected side has
flanked the target, and it gets nothing.

A cell is a pair (column, row), row 0 at the top.

When not to use it: anything beyond one shot. Who may shoot, sight and the
turn are the game's (`godot/game/squad/`); this module is the arithmetic
both languages must agree on.
"""

from __future__ import annotations

import json
import pathlib

HERE = pathlib.Path(__file__).resolve().parent
RULES = json.loads((HERE / "rules.json").read_text())

ROCK = "#"
TREES = "T"
#: The four steps beside a cell, as GDScript's `GakGridGraph.DIRECTIONS` lists them. The
#: order cannot change an answer: the best cover facing the shooter is taken.
STEPS = ((0, -1), (1, 0), (0, 1), (-1, 0))


def cover_of(rows: list[str], shooter: tuple[int, int], target: tuple[int, int]) -> dict:
    """The cover `target` has against `shooter`, and whether it was flanked.

    Returns {"cover": 0, 20 or 40, "flanked": bool}. Flanked means there was
    cover beside the target and none of it faced the shooter; a target in the
    open is not flanked, it simply has no cover.
    """
    best, beside_any = 0, False
    for step in STEPS:
        worth = _cover_worth(rows, (target[0] + step[0], target[1] + step[1]))
        if worth == 0:
            continue
        beside_any = True
        facing = (shooter[0] - target[0]) * step[0] + (shooter[1] - target[1]) * step[1]
        if facing > 0:
            best = max(best, worth)
    return {"cover": best, "flanked": beside_any and best == 0}


def hit_chance(aim: int, defence: int, cover: int) -> int:
    """Aim less defence less cover, clamped to [0, 100]."""
    return max(0, min(100, aim - defence - cover))


def shot(inputs: dict, roll: int) -> dict:
    """One shot with the die showing `roll`.

    `inputs` holds `aim`, `defence`, `cover`, `damage` and `target_health`.
    Returns {"chance", "hit", "target_left"}: the shot hits when the die is
    below the chance, and a hit takes `damage` off, never below 0.
    """
    chance = hit_chance(inputs["aim"], inputs["defence"], inputs["cover"])
    hit = roll < chance
    left = max(0, inputs["target_health"] - inputs["damage"]) if hit else inputs["target_health"]
    return {"chance": chance, "hit": hit, "target_left": left}


def inputs_for(shooter_type: str, target_type: str, cover: int, target_health: int) -> dict:
    """The shot's inputs, the pieces' numbers read from the rules."""
    pieces = RULES["pieces"]
    return {
        "aim": pieces[shooter_type]["aim"],
        "defence": pieces[target_type]["defence"],
        "cover": cover,
        "damage": pieces[shooter_type]["damage"],
        "target_health": target_health,
    }


def _cover_worth(rows: list[str], cell: tuple[int, int]) -> int:
    column, row = cell
    if row < 0 or row >= len(rows) or column < 0 or column >= len(rows[row]):
        return 0
    letter = rows[row][column]
    if letter == ROCK:
        return RULES["cover"]["full"]
    if letter == TREES:
        return RULES["cover"]["half"]
    return 0
