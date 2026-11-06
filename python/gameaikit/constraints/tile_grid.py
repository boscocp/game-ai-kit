"""A map of tiles declared as a constraint problem: a cell a variable, a tile a value.

Read `godot/addons/ai_constraints/tile_grid.gd` for the why. A *tile set*
is a table written by hand: each tile's character, its weight, and the
tiles it may stand beside left or right (`left_right`) and above or below
(`up_down`). Nothing is learned from an example map; the adjacency is the
table. It is symmetric within an axis: `left_right` lists the tiles allowed
on either side, so a tile set with a direction (a cliff's high side) cannot
be written in it. `grid_problem` turns it into a `ConstraintProblem` that
`WaveCollapse` solves, in the order the README of
`spec/vectors/constraints/collapse/` states, which both languages keep.
"""

from __future__ import annotations

from gameaikit.constraints.problem import ConstraintProblem

#: The keys a tile of a tile set has, no more and no fewer.
TILE_KEYS = {"tile", "weight", "left_right", "up_down"}
#: What a map's row shows for a cell no tile was chosen for.
UNDECIDED = "?"


def cell_name(x: int, y: int) -> str:
    """The variable a cell is: "x,y"."""
    return f"{x},{y}"


def weights_of(tile_set: dict) -> dict[str, int]:
    """Tile -> weight, in the order the tile set lists them. Every choice of
    `WaveCollapse` that walks the tiles walks them in this order."""
    return {entry["tile"]: entry["weight"] for entry in tile_set["tiles"]}


def why_not_a_tile_set(tile_set: dict) -> str:
    """What is wrong with `tile_set`, or "" when nothing is.

    Adjacency is a relation between two tiles, so it must be said from both
    sides: a table where water lists the bridge above it and the bridge does
    not list water below it is refused, not quietly made to agree.
    """
    tiles = tile_set.get("tiles")
    if not isinstance(tiles, list) or not tiles:
        return "a tile set lists at least one tile"
    for entry in tiles:
        if set(entry) != TILE_KEYS or len(entry["tile"]) != 1:
            return f"a tile has the keys {sorted(TILE_KEYS)} and one character: {entry}"
        if not isinstance(entry["weight"], int) or isinstance(entry["weight"], bool) or entry["weight"] < 1:
            return f"the tile {entry['tile']!r} needs a whole weight of 1 or more"
    names = [entry["tile"] for entry in tiles]
    if len(set(names)) != len(names):
        return "a tile is listed twice"
    for axis in ("left_right", "up_down"):
        for entry in tiles:
            for other in entry[axis]:
                if other not in names:
                    return f"{entry['tile']!r} names {other!r} beside it, which is no tile"
                if entry["tile"] not in next(item for item in tiles if item["tile"] == other)[axis]:
                    return f"{entry['tile']!r} may stand {axis} of {other!r}, but not {other!r} of {entry['tile']!r}"
    return ""


def grid_problem(tile_set: dict, width: int, height: int, pinned: dict | None = None) -> ConstraintProblem:
    """A variable per cell, row by row, each with every tile -- or, for a
    cell in `pinned` (name -> tiles), only those -- and, cell by cell, a
    constraint with the cell to its right and then the one below it."""
    pinned = pinned or {}
    weights = weights_of(tile_set)
    beside = {entry["tile"]: {"left_right": entry["left_right"], "up_down": entry["up_down"]}
              for entry in tile_set["tiles"]}
    problem = ConstraintProblem()
    for y in range(height):
        for x in range(width):
            name = cell_name(x, y)
            problem.add_variable(name, list(pinned.get(name, weights)))
    for y in range(height):
        for x in range(width):
            if x + 1 < width:
                problem.add_binary(cell_name(x, y), cell_name(x + 1, y),
                                   lambda left, right: right in beside[left]["left_right"], "left_right")
            if y + 1 < height:
                problem.add_binary(cell_name(x, y), cell_name(x, y + 1),
                                   lambda above, below: below in beside[above]["up_down"], "up_down")
    return problem


def rows_of(tiles: dict, width: int, height: int) -> list[str]:
    """The map as rows of characters, from cell name -> tile; a cell with
    no tile yet shows `UNDECIDED`."""
    return ["".join(tiles.get(cell_name(x, y), UNDECIDED) for x in range(width)) for y in range(height)]
