"""Write the wave function collapse vectors in this directory.

Imports nothing from the repository, so the maps and the restarts come from
neither implementation the vectors hold. It follows the README's rules in a
shape of its own: a grid of cells with coordinates and directions, an arc a
pair of cells, and no constraint objects -- so a mistake shared by the two
twins, which build the map as a `ConstraintProblem`, is not shared by it:

    python3 spec/vectors/constraints/collapse/derive.py spec/vectors/constraints/collapse
"""
import json
import math
import sys
from collections import deque

# The squad's tile set, as spec/squad/tiles.json has it; the test holds them equal.
SQUAD_TILES = [
    {"tile": ".", "weight": 20, "left_right": ".T#~=f", "up_down": ".T#~"},
    {"tile": "T", "weight": 6, "left_right": ".T#~", "up_down": ".T#~"},
    {"tile": "#", "weight": 3, "left_right": ".T#", "up_down": ".T#"},
    {"tile": "~", "weight": 5, "left_right": ".T~", "up_down": ".T~=f"},
    {"tile": "=", "weight": 1, "left_right": ".=", "up_down": "~"},
    {"tile": "f", "weight": 1, "left_right": ".f", "up_down": "~"},
]
SQUAD_STARTS = [(1, 2), (1, 4), (0, 5), (1, 6), (12, 6), (12, 4), (13, 3), (12, 2)]
# Up, left, right, down: the order a cell's constraints were declared in,
# since they are declared row by row, each cell's right one before its lower one.
DIRECTIONS = [(0, -1), (-1, 0), (1, 0), (0, 1)]


def xorshift(seed):
    state = seed & 0xFFFFFFFF or 1
    while True:
        state ^= (state << 13) & 0xFFFFFFFF
        state ^= state >> 17
        state ^= (state << 5) & 0xFFFFFFFF
        yield state


def shuffled(items, draws):
    items = list(items)
    for place in range(len(items) - 1, 0, -1):
        other = next(draws) % (place + 1)
        items[place], items[other] = items[other], items[place]
    return items


class Grid:
    def __init__(self, vector):
        self.width, self.height = vector["width"], vector["height"]
        self.tiles = {t["tile"]: t for t in vector["tiles"]}
        self.names = [t["tile"] for t in vector["tiles"]]
        self.pinned = vector["pinned"]
        self.cells = [(x, y) for y in range(self.height) for x in range(self.width)]

    def inside(self, cell):
        return 0 <= cell[0] < self.width and 0 <= cell[1] < self.height

    def neighbours(self, cell):
        found = [(cell[0] + dx, cell[1] + dy) for dx, dy in DIRECTIONS]
        return [n for n in found if self.inside(n)]

    def fits(self, cell, tile, other, other_tile):
        axis = "left_right" if cell[1] == other[1] else "up_down"
        return other_tile in self.tiles[tile][axis]

    def first_arcs(self):
        arcs = []
        for cell in self.cells:
            for step in [(1, 0), (0, 1)]:
                other = (cell[0] + step[0], cell[1] + step[1])
                if self.inside(other):
                    arcs += [(cell, other), (other, cell)]
        return arcs


def entropy(grid, left):
    weights = [grid.tiles[t]["weight"] for t in grid.names if t in left]
    if len(weights) <= 1:
        return 0.0
    total = sum(weights)
    return math.log(total) - sum(w * math.log(w) for w in weights) / total


def propagate(grid, wave, arcs):
    """AC-3 on arcs (target, source); the cell emptied, or None."""
    waiting, queued = deque(arcs), set(arcs)
    while waiting:
        target, source = waiting.popleft()
        queued.discard((target, source))
        kept = [t for t in wave[target] if any(grid.fits(target, t, source, s) for s in wave[source])]
        if len(kept) == len(wave[target]):
            continue
        wave[target] = kept
        if not kept:
            return target
        for neighbour in grid.neighbours(target):
            if neighbour != source and (neighbour, target) not in queued:
                waiting.append((neighbour, target))
                queued.add((neighbour, target))
    return None


def pick(grid, left, picks):
    left = [t for t in grid.names if t in left]
    if len(left) == 1:
        return left[0]
    draw = next(picks) % sum(grid.tiles[t]["weight"] for t in left)
    for tile in left:
        if draw < grid.tiles[tile]["weight"]:
            return tile
        draw -= grid.tiles[tile]["weight"]


def attempt(grid, seed):
    """(map or None, [[cell, tile]...], the cell of the contradiction or None)."""
    draws = xorshift(seed)
    order = shuffled(grid.cells, draws)
    wave = {cell: list(grid.pinned.get("%d,%d" % cell, grid.names)) for cell in grid.cells}
    stuck = propagate(grid, wave, grid.first_arcs())
    picks, done, collapsed = xorshift(seed), set(), []
    while stuck is None and len(done) < len(grid.cells):
        cell = min((c for c in order if c not in done), key=lambda c: (entropy(grid, wave[c]), order.index(c)))
        tile = pick(grid, wave[cell], picks)
        done.add(cell)
        collapsed.append(["%d,%d" % cell, tile])
        wave[cell] = [tile]
        stuck = propagate(grid, wave, [(n, cell) for n in grid.neighbours(cell) if n not in done])
    if stuck is not None:
        return None, collapsed, "%d,%d" % stuck
    return ["".join(wave[(x, y)][0] for x in range(grid.width)) for y in range(grid.height)], collapsed, None


def run(vector):
    grid = Grid(vector)
    contradictions = []
    for number in range(vector["attempts"]):
        found, collapsed, stuck = attempt(grid, vector["seed"] + number)
        if found is not None:
            return dict(vector, map=found, collapsed=collapsed, restarts=number, contradictions=contradictions)
        contradictions.append(stuck)
        if not collapsed:
            break
    return dict(vector, map=None, collapsed=[], restarts=len(contradictions), contradictions=contradictions)


def squad_pinned():
    return {"%d,%d" % cell: ["."] for cell in SQUAD_STARTS}


CHECKERS = [{"tile": "a", "weight": 1, "left_right": "b", "up_down": "b"},
            {"tile": "b", "weight": 1, "left_right": "a", "up_down": "a"}]
# Three tiles, each of which may stand beside the other two and not beside
# itself: a cell between two that differ has one tile left, and a corner of
# four cells can run out -- a contradiction the solver cannot see coming.
THREE_COLOURS = [{"tile": "r", "weight": 1, "left_right": "gb", "up_down": "gb"},
                 {"tile": "g", "weight": 1, "left_right": "rb", "up_down": "rb"},
                 {"tile": "b", "weight": 1, "left_right": "rg", "up_down": "rg"}]
# One heavy tile and one light one that may stand anywhere: the draw, by weight.
HEAVY_AND_LIGHT = [{"tile": "h", "weight": 9, "left_right": "hl", "up_down": "hl"},
                   {"tile": "l", "weight": 1, "left_right": "hl", "up_down": "hl"}]


def base(description, tiles, width, height, seed, pinned=None, attempts=10):
    return {"description": description, "tiles": tiles, "width": width, "height": height,
            "pinned": pinned or {}, "seed": seed, "attempts": attempts}


VECTORS = {
    "checkers-decided-by-one-cell": base(
        "Two tiles that never stand beside themselves, on three by three: the first collapse decides every cell.",
        CHECKERS, 3, 3, 1),
    "heavy-and-light": base("A tile drawn nine times in ten and one drawn once, beside anything: the draw by weight.",
                            HEAVY_AND_LIGHT, 4, 2, 8),
    "three-colours-restart": base(
        "Three tiles, none beside itself, on eight by eight: seed 30 runs into a contradiction, and seed 31 does not.",
        THREE_COLOURS, 8, 8, 30),
    "three-colours-two-restarts": base(
        "The same three tiles on the squad map's 14 by 9: two seeds run into a contradiction before the third does not.",
        THREE_COLOURS, 14, 9, 6),
    "pinned-so-there-is-none": base(
        "Checkers with two neighbouring cells pinned to the same tile: AC-3 empties a cell before anything collapses, every seed.",
        CHECKERS, 3, 2, 1, {"0,0": ["a"], "1,0": ["a"]}, 3),
    "squad-map-seed-1": base("The XCOM-style mode's tile set on its 14 by 9 map, the eight starts pinned to open ground.",
                             SQUAD_TILES, 14, 9, 1, squad_pinned()),
    "squad-map-seed-2": base("The same, from seed 2.", SQUAD_TILES, 14, 9, 2, squad_pinned()),
}


def main(directory):
    for name, vector in VECTORS.items():
        with open(f"{directory}/{name}.json", "w", encoding="utf-8") as file:
            json.dump(run(vector), file, indent=1)
            file.write("\n")


if __name__ == "__main__":
    main(sys.argv[1])
