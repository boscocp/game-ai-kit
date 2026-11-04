"""The maze and its rules, read from the JSON beside this file.

`maze.json` and `rules.json` here are byte-for-byte copies of `spec/maze/`,
kept in the package because the package is what ships (the reason the
dataset package keeps its own copy of the combat rules); a test holds
both copies to the spec. Every number a step depends on is in those two
files, and `rules.json`'s "about" is the rules in words.

A cell is a pair (column, row), row 0 at the top, so up is row - 1. A
direction is one of the names "up", "left", "down", "right".

The ghost's choice is Pittman's, from the Pac-Man Dossier: never reverse,
measure from the cell beyond each way to the target tile, take the
shortest, ties up, left, down, right. `choose` writes down everything that
went into it, because the demo shows it before the ghost moves.

When not to use it: a maze bigger than a screen, or one with tunnels or a
ghost house. Neither is here, and the rules say so rather than half-model
them.
"""

from __future__ import annotations

import json
import pathlib

from gameaikit.core.xorshift import Xorshift

HERE = pathlib.Path(__file__).resolve().parent
MAZE = json.loads((HERE / "maze.json").read_text())
RULES = json.loads((HERE / "rules.json").read_text())

#: Each direction's step, as [column, row].
DIRECTIONS = {name: tuple(step) for name, step in RULES["directions"].items()}
#: The order that breaks a tie between two ways equally near the target.
TIE_ORDER = tuple(RULES["tie_order"])
#: The chance an imprecise ghost keeps the Dossier's choice at a fork.
PRECISION = RULES["precision"]
WALL = "#"

SCATTER = "scatter"
CHASE = "chase"

#: How a ghost came by its next move: written on the screen and in the vectors.
REVERSAL = "reversal"
ONLY_WAY = "only way"
NEAREST = "nearest"
DICE = "dice"


def is_open(cell: tuple[int, int]) -> bool:
    """Whether `cell` is floor. Outside the rows counts as wall."""
    column, row = cell
    rows = MAZE["rows"]
    if row < 0 or row >= len(rows) or column < 0 or column >= len(rows[row]):
        return False
    return rows[row][column] != WALL


def floor_cells() -> list[tuple[int, int]]:
    """Every floor cell, row by row from the top left."""
    return [(column, row) for row, line in enumerate(MAZE["rows"])
            for column, character in enumerate(line) if character != WALL]


def moved(cell: tuple[int, int], direction: str) -> tuple[int, int]:
    """The cell one step from `cell` towards `direction`, wall or not."""
    step = DIRECTIONS[direction]
    return (cell[0] + step[0], cell[1] + step[1])


def reverse(direction: str) -> str:
    """The direction back the way `direction` came."""
    step = DIRECTIONS[direction]
    for name, other in DIRECTIONS.items():
        if other == (-step[0], -step[1]):
            return name
    raise ValueError(f"no reverse for {direction}")


def mode_at(step: int, schedule: list[dict] | None = None) -> str:
    """The ghosts' mode during step `step`, counted from 0, by `schedule`.

    None is the arcade's, from `rules.json`; T98's MDP plays one of its own,
    chase for ever (`mdp.json`).
    """
    periods = RULES["schedule"] if schedule is None else schedule
    start = 0
    for period in periods:
        if period["steps"] is None or step < start + period["steps"]:
            return period["mode"]
        start += period["steps"]
    return periods[-1]["mode"]


def target(name: str, mode: str, pacman: tuple[int, int], facing: str) -> tuple[int, int]:
    """The ghost's target tile: its corner in scatter, its personality in chase.

    Blinky's is Pac-Man's cell. Pinky's is `tiles` ahead of where Pac-Man
    faces, and -- the Dossier's overflow bug, kept -- as many to the left
    too when he faces up.
    """
    if mode == SCATTER:
        return tuple(MAZE["ghosts"][name]["corner"])
    personality = RULES["targets"][name]
    if personality["chase"] == "pacman":
        return pacman
    step = DIRECTIONS[facing]
    tiles = personality["tiles"]
    ahead = (pacman[0] + step[0] * tiles, pacman[1] + step[1] * tiles)
    if facing == "up" and personality["up_also_left"]:
        ahead = (ahead[0] - tiles, ahead[1])
    return ahead


def squared_distance(first: tuple[int, int], second: tuple[int, int]) -> int:
    """The straight line between two cells, squared: whole, so exact in both languages."""
    return (first[0] - second[0]) ** 2 + (first[1] - second[1]) ** 2


def ways(cell: tuple[int, int], heading: str, goal: tuple[int, int]) -> list[dict]:
    """The ways a ghost on `cell`, last moved `heading`, may take, in tie order.

    Every open neighbour but the one behind it, each with the cell beyond and
    its squared distance to `goal`. Only a dead end leaves the way back.
    """
    found = [direction for direction in TIE_ORDER
             if direction != reverse(heading) and is_open(moved(cell, direction))]
    if not found:
        found = [reverse(heading)]
    return [{"direction": direction, "beyond": moved(cell, direction),
             "squared": squared_distance(moved(cell, direction), goal)} for direction in found]


def nearest(open_ways: list[dict]) -> str:
    """The Dossier's choice: the shortest way, and on a tie the first in `TIE_ORDER`.

    The order is asked here, not left to the order of `open_ways`, so a tie is
    decided the same however the ways were listed.
    """
    best = min(open_ways, key=lambda way: (way["squared"], TIE_ORDER.index(way["direction"])))
    return best["direction"]


def choose(open_ways: list[dict], mode: str, dice: Xorshift) -> dict:
    """Which way the ghost takes, and how it came to: the decision the demo draws.

    One way is taken without a draw. At a fork, in a mode `rules.json` calls
    imprecise, a uniform draw below `PRECISION` keeps the Dossier's choice;
    otherwise a second draw picks any way evenly.
    """
    best = nearest(open_ways)
    if len(open_ways) == 1:
        return {"chosen": best, "best": best, "kind": ONLY_WAY}
    if mode not in RULES["imprecise_in"]:
        return {"chosen": best, "best": best, "kind": NEAREST}
    roll = dice.uniform()
    if roll < PRECISION:
        return {"chosen": best, "best": best, "kind": NEAREST, "roll": roll}
    pick = dice.index(len(open_ways))
    return {"chosen": open_ways[pick]["direction"], "best": best, "kind": DICE, "roll": roll, "pick": pick}


def chances(open_ways: list[dict], mode: str) -> dict[str, float]:
    """The probability of each way, as `choose` takes them: T98's transition model.

    precision x [it is the Dossier's] + (1 - precision) / ways at an
    imprecise fork, and certainty for the Dossier's way everywhere else.
    Exact up to the generator's bias, about 2^-32: a draw is 1 to 2^32 - 1,
    and the second is taken modulo the ways.
    """
    best = nearest(open_ways)
    if len(open_ways) == 1 or mode not in RULES["imprecise_in"]:
        return {way["direction"]: 1.0 if way["direction"] == best else 0.0 for way in open_ways}
    even = (1.0 - PRECISION) / len(open_ways)
    return {way["direction"]: even + (PRECISION if way["direction"] == best else 0.0) for way in open_ways}
