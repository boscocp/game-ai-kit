"""Write the adversarial vectors in this directory.

Imports nothing from the repository, so the numbers come from neither
implementation the vectors hold -- this is a third MCTS, written short, from
the rules the README states:

    python3 spec/vectors/adversarial/derive.py spec/vectors/adversarial
"""
import json, math, sys

MASK = 0xFFFFFFFF


class Draws:
    def __init__(self, seed):
        self.x = (seed & MASK) or 1

    def next(self):
        self.x ^= (self.x << 13) & MASK
        self.x ^= self.x >> 17
        self.x ^= (self.x << 5) & MASK
        return self.x

    def pick(self, n):
        return 0 if n <= 1 else self.next() % n

    def face(self, chances):
        if len(chances) <= 1:
            return 0
        u, total = self.next() / 4294967296.0, 0.0
        for i, c in enumerate(chances):
            total += c
            if u < total:
                return i
        return len(chances) - 1


# A game is (player, moves, outcomes, over, value) on plain tuples.
def nim():
    moves = lambda s: list(range(1, min(3, s[0]) + 1))
    outs = lambda s, m: [(1.0, (s[0] - m, 1 - s[1]))]
    value = lambda s, p: 0.0 if s[0] > 0 else (1.0 if s[1] != p else -1.0)
    return (lambda s: s[1], moves, outs, lambda s: s[0] == 0, value)


def dice_race(goal=6):
    over = lambda s: max(s[0]) >= goal
    def go(s, n, again):
        q = list(s[0]); q[s[1]] += n
        return (tuple(q), s[1] if again else 1 - s[1])
    def outs(s, m):
        if m == "walk":
            return [(1.0, go(s, 1, False))]
        return [(0.5, go(s, 0, False)), (0.25, go(s, 2, False)), (0.25, go(s, 4, True))]
    def value(s, p):
        lead = s[0][p] - s[0][1 - p]
        return (1.0 if lead > 0 else -1.0) if over(s) else lead / goal
    return (lambda s: s[1], lambda s: [] if over(s) else ["walk", "roll"], outs, over, value)


def search(game, state, seed, steps, c, limit):
    player, moves, outs, over, value = game
    draws = Draws(seed)
    def node(s):
        ms = moves(s)
        return {"s": s, "p": player(s), "ms": ms, "end": over(s) or not ms, "b": [None] * len(ms),
                "todo": list(range(len(ms))), "n": 0}
    def child(b):
        k = draws.face([pr for pr, _ in b["o"]])
        if b["kids"][k] is None:
            b["kids"][k] = node(b["o"][k][1])
        return b["kids"][k]
    def ucb(b, parent):
        return math.inf if b["n"] == 0 else b["w"] / b["n"] + c * math.sqrt(math.log(float(parent)) / b["n"])
    root = node(state)
    for _ in range(sum(steps) if not root["end"] else 0):
        here, nodes, taken = root, [root], []
        while not here["end"] and not here["todo"]:
            best = None
            for b in here["b"]:
                if best is None or ucb(b, here["n"]) > ucb(best, here["n"]):
                    best = b
            taken.append(best); here = child(best); nodes.append(here)
        if not here["end"]:
            i = here["todo"].pop(draws.pick(len(here["todo"])))
            b = {"m": here["ms"][i], "p": here["p"], "o": outs(here["s"], here["ms"][i]), "n": 0, "w": 0.0}
            b["kids"] = [None] * len(b["o"]); here["b"][i] = b
            taken.append(b); here = child(b); nodes.append(here)
        s, played = here["s"], 0
        while played < limit and not over(s) and moves(s):
            ms = moves(s)
            o = outs(s, ms[draws.pick(len(ms))])
            s = o[draws.face([pr for pr, _ in o])][1]; played += 1
        for n in nodes:
            n["n"] += 1
        worth = {}
        for b in taken:
            worth.setdefault(b["p"], value(s, b["p"]))
            b["n"] += 1; b["w"] += worth[b["p"]]
    visits = [b["n"] if b else 0 for b in root["b"]]
    means = [b["w"] / b["n"] if b and b["n"] else 0.0 for b in root["b"]]
    chosen = root["ms"][visits.index(max(visits))] if visits else None
    return visits, means, chosen


def as_tuple(state):
    if "sticks" in state:
        return (state["sticks"], state["player"])
    return (tuple(state["squares"]), state["player"])


def case(name, game, state, seed, steps, c=math.sqrt(2.0), limit=200):
    visits, means, chosen = search(game, as_tuple(state), seed, steps, c, limit)
    return {"name": name, "state": state, "seed": seed, "steps": steps, "exploration": c,
            "playout_limit": limit, "visits": visits, "means": means, "action": chosen}


def main(out):
    draws = []
    for seed in (1, 0, 2463534242, 86):
        d = Draws(seed)
        draws.append({"seed": seed, "draws": [d.next() for _ in range(6)]})
    vectors = {
        "xorshift.json": {"description": "The first six draws from four seeds; seed 1 starts 270369, seed 0 is seed 1.",
                          "cases": draws},
        "mcts-nim.json": {"description": "UCT on Nim (take 1-3, last stick wins): visits and means at the root.",
                          "game": "nim", "cases": [
            case("one stick, one move", nim(), {"sticks": 1, "player": 0}, 1, [3]),
            case("ten sticks after 300: not sure yet", nim(), {"sticks": 10, "player": 0}, 1, [300]),
            case("ten sticks after 1000: take two", nim(), {"sticks": 10, "player": 0}, 1, [1000]),
            case("thirteen, in two steps", nim(), {"sticks": 13, "player": 0}, 7, [200, 300]),
            case("five, player one to move", nim(), {"sticks": 5, "player": 1}, 42, [60]),
            case("eight: every take loses", nim(), {"sticks": 8, "player": 0}, 9, [120]),
            case("ten, a narrow search", nim(), {"sticks": 10, "player": 0}, 5, [150], 0.5, 200),
        ]},
        "mcts-dice-race.json": {"description": "UCT on the dice race: one child per face drawn, a four plays again.",
                                "game": "dice_race", "cases": [
            case("from the start", dice_race(), {"squares": [0, 0], "player": 0}, 1, [400]),
            case("one square from home: walk", dice_race(), {"squares": [5, 0], "player": 0}, 3, [100, 100]),
            case("behind at the end: roll", dice_race(), {"squares": [4, 5], "player": 0}, 11, [300]),
            case("player one, midway", dice_race(), {"squares": [2, 4], "player": 1}, 5, [250]),
            case("short playouts, scored by the lead", dice_race(), {"squares": [1, 0], "player": 0}, 8, [200],
                 math.sqrt(2.0), 2),
        ]},
    }
    for name, vector in vectors.items():
        with open(f"{out}/{name}", "w", encoding="utf-8") as handle:
            json.dump(vector, handle, indent=1)
            handle.write("\n")


if __name__ == "__main__":
    main(sys.argv[1])
