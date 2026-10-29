"""Write the maze vectors in this directory.

Imports nothing from the repository: a third copy of the rules, written from
`spec/maze/rules.json`'s "about" in plain dictionaries, so the positions come
from neither implementation the vectors hold. It reads the two spec files
for the maze and the numbers, and checks that each case shows what its name
says -- a vector named "the first reversal" in which nobody reversed would
hold nothing.

    python3 spec/vectors/maze/derive.py spec/vectors/maze
"""
import json, pathlib, sys

SPEC = pathlib.Path(__file__).resolve().parents[2] / "maze"
MAZE = json.loads((SPEC / "maze.json").read_text())
RULES = json.loads((SPEC / "rules.json").read_text())
STEP = {name: tuple(step) for name, step in RULES["directions"].items()}
BACK = {"up": "down", "down": "up", "left": "right", "right": "left"}
FLOOR = {(column, row) for row, line in enumerate(MAZE["rows"]) for column, c in enumerate(line) if c != "#"}


def plus(cell, direction, times=1):
    return (cell[0] + STEP[direction][0] * times, cell[1] + STEP[direction][1] * times)


def mode_at(step):
    start = 0
    for period in RULES["schedule"]:
        if period["steps"] is None or step < start + period["steps"]:
            return period["mode"]
        start += period["steps"]


class Dice:
    def __init__(self, seed):
        self.state = (seed & 0xFFFFFFFF) or 1

    def next(self):
        s = self.state
        s ^= (s << 13) & 0xFFFFFFFF
        s ^= s >> 17
        s ^= (s << 5) & 0xFFFFFFFF
        self.state = s
        return s


def target_of(name, mode, pac, facing):
    if mode == "scatter":
        return tuple(MAZE["ghosts"][name]["corner"])
    rule = RULES["targets"][name]
    if rule["chase"] == "pacman":
        return pac
    goal = plus(pac, facing, rule["tiles"])
    if facing == "up" and rule["up_also_left"]:
        goal = plus(goal, "left", rule["tiles"])
    return goal


def decide(ghost, mode, reversing, pac, facing, dice):
    goal = target_of(ghost["name"], mode, pac, facing)
    ghost["target"] = goal
    if reversing:
        return BACK[ghost["heading"]], "reversal"
    options = [d for d in RULES["tie_order"] if d != BACK[ghost["heading"]] and plus(ghost["cell"], d) in FLOOR]
    options = options or [BACK[ghost["heading"]]]
    far = [(plus(ghost["cell"], d)[0] - goal[0]) ** 2 + (plus(ghost["cell"], d)[1] - goal[1]) ** 2 for d in options]
    best = options[far.index(min(far))]
    if len(options) == 1:
        return best, "only way"
    if mode not in RULES["imprecise_in"]:
        return best, "nearest"
    if dice.next() / 4294967296.0 < RULES["precision"]:
        return best, "nearest"
    return options[dice.next() % len(options)], "dice"


def play(seed, names, moves):
    dice = Dice(seed)
    pac, facing = tuple(MAZE["pacman"]["cell"]), MAZE["pacman"]["facing"]
    pellets = [tuple(cell) for cell in MAZE["pellets"]]
    ghosts = [{"name": n, "cell": tuple(MAZE["ghosts"][n]["cell"]), "heading": MAZE["ghosts"][n]["heading"]} for n in names]
    steps, outcome = 0, "playing"
    for g in ghosts:
        g["next"], g["kind"] = decide(g, mode_at(0), False, pac, facing, dice)

    def seen():
        return {"pacman": list(pac), "facing": facing, "ghosts": [[g["cell"][0], g["cell"][1], g["next"], g["kind"], *g["target"]] for g in ghosts],
                "pellets": len(pellets), "mode": mode_at(steps), "outcome": outcome}

    trace = [seen()]
    for move in moves:
        if outcome == "playing":
            if plus(pac, move) in FLOOR:
                pac, facing = plus(pac, move), move
            if any(g["cell"] == pac for g in ghosts):
                outcome = "caught"
            elif pac in pellets:
                pellets.remove(pac)
                outcome = "won" if not pellets else outcome
            if outcome == "playing":
                for g in ghosts:
                    g["cell"], g["heading"] = plus(g["cell"], g["next"]), g["next"]
                    if g["cell"] == pac:
                        outcome = "caught"
                if outcome == "playing":
                    reversing = mode_at(steps + 1) != mode_at(steps)
                    steps += 1
                    for g in ghosts:
                        g["next"], g["kind"] = decide(g, mode_at(steps), reversing, pac, facing, dice)
        trace.append(seen())
    return trace


def kinds(trace):
    return {g[3] for snapshot in trace for g in snapshot["ghosts"]}


def pinky_up(trace):
    for s in trace:
        if s["outcome"] == "playing" and s["mode"] == "chase" and s["facing"] == "up":
            pinky = s["ghosts"][1]
            if pinky[3] != "reversal" and pinky[4:] == [s["pacman"][0] - 4, s["pacman"][1] - 4]:
                return True
    return False


# Each case: a name, a seed, the ghosts, Pac-Man's moves, and what it must show.
CASES = [
    ("walking-into-a-wall-stays", "Pac-Man starts on the bottom row; down is a wall, so he stays and keeps facing left, while Blinky takes his first scatter steps towards the top-right corner.",
     1, ["blinky"], ["down"] * 3, lambda t: t[-1]["pacman"] == [6, 7] and t[-1]["facing"] == "left"),
    ("no-ghost-four-pellets-won", "With no ghost, the four corners eaten in turn win the game on the last pellet, and a move after the end changes nothing.",
     1, [], ["left"] * 5 + ["up"] * 6 + ["right"] * 4 + ["down"] * 2 + ["right"] * 6 + ["up"] * 2 + ["down"] * 6 + ["up"],
     lambda t: t[-1]["outcome"] == "won" and t[-1] == t[-2]),
    ("the-first-scatter-ends-in-a-reversal", "Pac-Man paces the bottom row; after 14 scatter steps the mode turns to chase and Blinky reverses without choosing.",
     1, ["blinky"], (["left"] * 4 + ["right"] * 4) * 2, lambda t: "reversal" in kinds(t)),
    ("an-imprecise-turn-in-chase", "In chase, at a fork, a draw at or above the precision sends Blinky down a way picked by a second draw.",
     7, ["blinky"], (["left"] * 5 + ["right"] * 5) * 4, lambda t: "dice" in kinds(t)),
    ("pinky-aims-ahead-and-up-means-left-too", "Two ghosts. In chase Pinky's target is four cells ahead of where Pac-Man faces, and while he faces up four to the left as well: the Dossier's overflow bug, kept.",
     40, ["blinky", "pinky"], ["down"] * 4 + ["up"] * 5 + ["left"] * 4 + ["down"] * 5 + ["left"] * 5 + ["up"] * 6 + ["left"], pinky_up),
    ("walking-at-blinky-is-a-catch", "Pac-Man walks up the left side and along the top while Blinky circles its scatter corner, and they meet: caught, and the game stays over.",
     1, ["blinky"], ["left"] * 5 + ["up"] * 4 + ["right"] * 5 + ["down"] * 4 + ["right"] * 6 + ["left"] * 6,
     lambda t: t[-1]["outcome"] == "caught"),
]


def main(out):
    for name, about, seed, ghosts, moves, shows in CASES:
        trace = play(seed, ghosts, moves)
        if not shows(trace):
            sys.exit(f"derive: {name} does not show what it says")
        vector = {"description": about, "seed": seed, "ghosts": ghosts, "moves": moves, "trace": trace}
        lines = ",\n  ".join(json.dumps(snapshot) for snapshot in trace)
        head = json.dumps({key: vector[key] for key in ("description", "seed", "ghosts", "moves")}, indent=1)[:-2]
        (pathlib.Path(out) / f"{name}.json").write_text(head + ',\n "trace": [\n  ' + lines + "\n ]\n}\n")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else pathlib.Path(__file__).parent)
