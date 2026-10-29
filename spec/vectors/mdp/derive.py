"""Write the MDP vectors in this directory: ten maze states, each one's value and best move.

Imports nothing from the repository: a third copy of the maze's rules and
a second value iteration, written from `spec/maze/rules.json`'s and
`spec/maze/mdp.json`'s "about" in plain dictionaries, so the numbers come
from neither `gameaikit.mdp` nor Godot. It solves the whole MDP (a few
seconds), then keeps the cases below, and refuses one whose best move is
within `MARGIN` of the second best -- a vector that rounding could flip
would hold nothing -- or whose best move is not the one its name claims.

    python3 spec/vectors/mdp/derive.py spec/vectors/mdp
"""
import json, pathlib, sys

SPEC = pathlib.Path(__file__).resolve().parents[2] / "maze"
MAZE = json.loads((SPEC / "maze.json").read_text())
RULES = json.loads((SPEC / "rules.json").read_text())
MDP = json.loads((SPEC / "mdp.json").read_text())
STEP = {name: tuple(step) for name, step in RULES["directions"].items()}
ORDER = RULES["tie_order"]
BACK = {"up": "down", "down": "up", "left": "right", "right": "left"}
FLOOR = [(column, row) for row, line in enumerate(MAZE["rows"]) for column, c in enumerate(line) if c != "#"]
PELLETS = [tuple(cell) for cell in MAZE["pellets"]]
PAY = MDP["rewards"]
GAMMA = MDP["discount"]
PRECISION = RULES["precision"]
MARGIN = 0.01

# (name, why, Pac-Man, Blinky, Blinky's heading, pellets left, the move the name claims)
CASES = [
    ("the-start", "The game's first state: all four pellets, Blinky above in the middle, heading left.",
     (6, 7), (6, 3), "left", PELLETS, None),
    ("one-pellet-one-step-away", "The last pellet is one step left and Blinky is far: take it and win.",
     (2, 1), (11, 5), "down", [(1, 1)], "left"),
    ("blinky-in-the-corridor-ahead", "Blinky is two cells to the right on the bottom row, heading at Pac-Man: turn away.",
     (3, 7), (5, 7), "left", [(1, 1), (11, 1), (11, 7)], "left"),
    ("blinky-right-behind", "Blinky one cell to the right on the top row, heading at Pac-Man: every move but left is caught.",
     (3, 1), (4, 1), "left", [(1, 1), (11, 1)], "left"),
    ("two-pellets-left-on-the-right", "The two right-hand pellets left, Blinky in the far left column.",
     (6, 3), (1, 5), "down", [(11, 1), (11, 7)], None),
    ("blinky-between-pac-man-and-the-pellet", "The last pellet is top right, and Blinky stands on the way to it.",
     (7, 3), (9, 3), "left", [(11, 1)], None),
    ("blinky-heading-away", "Blinky just above, heading away up the column; the bottom pellets left.",
     (1, 5), (1, 3), "up", [(1, 7), (11, 7)], None),
    ("the-middle-row", "Pac-Man halfway along the middle row, all four pellets left, Blinky coming along the row below.",
     (6, 3), (4, 5), "right", [(1, 1), (11, 1), (1, 7), (11, 7)], None),
    ("last-pellet-far-blinky-near", "One pellet left in the far corner, Blinky close behind Pac-Man.",
     (9, 7), (7, 7), "right", [(1, 1)], None),
    ("a-corner-with-blinky-across", "Pac-Man in the bottom-right corner just after its pellet, Blinky across the maze.",
     (11, 7), (1, 1), "up", [(1, 1), (1, 7)], None),
]


def is_open(cell):
    column, row = cell
    rows = MAZE["rows"]
    return 0 <= row < len(rows) and 0 <= column < len(rows[row]) and rows[row][column] != "#"


def plus(cell, direction):
    return (cell[0] + STEP[direction][0], cell[1] + STEP[direction][1])


def blinky_moves(pac, ghost, heading):
    """Each way Blinky may take, with its chance: chase, aiming at Pac-Man's cell."""
    ways = [d for d in ORDER if d != BACK[heading] and is_open(plus(ghost, d))] or [BACK[heading]]
    far = lambda d: (sum((a - b) ** 2 for a, b in zip(plus(ghost, d), pac)), ORDER.index(d))
    best = min(ways, key=far)
    if len(ways) == 1:
        return {best: 1.0}
    return {d: (1 - PRECISION) / len(ways) + (PRECISION if d == best else 0.0) for d in ways}


def outcomes(state, move):
    pac, ghost, heading, left = state
    after = plus(pac, move) if is_open(plus(pac, move)) else pac
    if after == ghost:
        return [(1.0, PAY["step"] + PAY["caught"], None)]
    pay = PAY["step"]
    if after in left:
        pay += PAY["pellet"]
        left = left - {after}
        if not left:
            return [(1.0, pay + PAY["cleared"], None)]
    found = []
    for way, chance in blinky_moves(pac, ghost, heading).items():
        moved = plus(ghost, way)
        found.append((chance, pay + PAY["caught"], None) if moved == after else (chance, pay, (after, moved, way, left)))
    return found


def every_state():
    subsets = [frozenset(p for i, p in enumerate(PELLETS) if bits >> i & 1) for bits in range(1, 16)]
    return [(pac, ghost, heading, left) for pac in FLOOR for ghost in FLOOR for heading in ORDER for left in subsets
            if pac != ghost and is_open(plus(ghost, BACK[heading])) and pac not in left]


def q(values, state, move):
    return sum(c * (r + GAMMA * (0.0 if n is None else values[n])) for c, r, n in outcomes(state, move))


def solve():
    states = every_state()
    table = {s: {m: outcomes(s, m) for m in ORDER} for s in states}
    values = dict.fromkeys(states, 0.0)
    limit = MDP["epsilon"] * (1 - GAMMA) / GAMMA
    while True:
        new = {s: max(sum(c * (r + GAMMA * (0.0 if n is None else values[n])) for c, r, n in table[s][m])
                      for m in ORDER) for s in states}
        moved = max(abs(new[s] - values[s]) for s in states)
        values = new
        if moved <= limit:
            return values


def case(values, name, why, pac, ghost, heading, left, claimed):
    state = (pac, ghost, heading, frozenset(left))
    if state not in values:
        sys.exit(f"{name}: not a state the game can be in")
    worth = {m: q(values, state, m) for m in ORDER}
    ranked = sorted(ORDER, key=lambda m: (-worth[m], ORDER.index(m)))
    if worth[ranked[0]] - worth[ranked[1]] < MARGIN:
        sys.exit(f"{name}: {ranked[0]} and {ranked[1]} are within {MARGIN}: {worth}")
    if claimed and ranked[0] != claimed:
        sys.exit(f"{name}: the best move is {ranked[0]}, not {claimed}")
    return {"name": name, "description": why, "pacman": list(pac), "ghost": list(ghost), "heading": heading,
            "pellets": [list(p) for p in sorted(left)], "value": round(values[state], 3), "action": ranked[0],
            "q": {m: round(worth[m], 3) for m in ORDER}}


def main(out):
    values = solve()
    cases = [case(values, *one) for one in CASES]
    document = {"description": "Ten states of the maze's MDP, each with its value, the four moves' Q-values "
                "and the best move, from derive.py's own value iteration (spec/vectors/mdp/README.md).",
                "tolerance": 0.002, "cases": cases}
    path = pathlib.Path(out) / "ten-states.json"
    head = json.dumps({key: value for key, value in document.items() if key != "cases"}, indent=1)[:-2]
    rows = ",\n  ".join(json.dumps(one) for one in cases)
    path.write_text(head + ',\n "cases": [\n  ' + rows + "\n ]\n}\n")
    for one in cases:
        print(f"{one['name']}: {one['action']} {one['value']} {one['q']}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else pathlib.Path(__file__).parent)
