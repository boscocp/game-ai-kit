"""Write the perception vectors in this directory.

Imports nothing from the repository, so the answers come from neither
implementation the vectors hold -- `ai_perception` and
`gameaikit.perception` -- but from a third copy of the rules, here, in
plain dictionaries:

    python3 spec/vectors/perception/derive.py spec/vectors/perception
"""
import json, math, pathlib, sys

# --- the vision shape ------------------------------------------------------

COFFIN = {"zones": [
    {"name": "beside", "near": 0.0, "far": 2.5, "half_angle": 110.0, "certainty": 1.0},
    {"name": "ahead", "near": 2.5, "far": 10.0, "half_angle": 50.0, "certainty": 0.8},
    {"name": "far", "near": 10.0, "far": 18.0, "half_angle": 20.0, "certainty": 0.4}],
    "dark_share": 0.3, "motion_bonus": 0.15}


def zone_at(shape, distance, angle):
    best = -1
    for i, z in enumerate(shape["zones"]):
        if z["near"] <= distance < z["far"] and abs(angle) <= z["half_angle"]:
            if best == -1 or z["certainty"] > shape["zones"][best]["certainty"]:
                best = i
    return best


def certainty(shape, look):
    zone = zone_at(shape, look["distance"], look["angle"])
    if zone == -1 or look["points"].count(True) < look["needed"]:
        return zone, 0.0
    light = min(max(look["light"], 0.0), 1.0)
    lit = shape["dark_share"] + (1.0 - shape["dark_share"]) * light
    shown = shape["zones"][zone]["certainty"] * lit + (shape["motion_bonus"] if look["moving"] else 0.0)
    return zone, min(max(shown * (1.0 - min(max(look["hidden"], 0.0), 1.0)), 0.0), 1.0)


def look(distance, angle, points=(True, True, True), needed=1, light=1.0, moving=False, hidden=0.0):
    return {"distance": distance, "angle": angle, "points": list(points), "needed": needed,
            "light": light, "moving": moving, "hidden": hidden}


def shape_vector(name, why, looks, shape=COFFIN):
    answers = [certainty(shape, each) for each in looks]
    return {"name": name, "why": why, "kind": "shape", "shape": shape, "query": {"looks": looks},
            "expect": {"zones": [z for z, _ in answers], "certainties": [c for _, c in answers]}}

# --- hearing along a path --------------------------------------------------


def loudness(path_length, radius, factor):
    within = radius * min(max(factor, 0.0), 1.0)
    if path_length < 0 or within <= 0:
        return 0.0
    return min(max(1.0 - path_length / within, 0.0), 1.0)


def loudness_vector(name, why, heard):
    return {"name": name, "why": why, "kind": "loudness", "query": {"heard": heard},
            "expect": {"loudness": [loudness(*each) for each in heard]}}

# --- awareness -------------------------------------------------------------

ROW = {"peak": 1.0, "decay": 0.1,
       "phases": [{"name": "unaware", "at": 0.0}, {"name": "suspicious", "at": 0.25},
                  {"name": "searching", "at": 0.625}, {"name": "alert", "at": 1.0}],
       "caution": {"floor": 0.25, "seconds": 30.0}}


def phase(number, row):
    found = 0
    for i, p in enumerate(row["phases"]):
        if number >= p["at"] * row["peak"]:
            found = i
    return found


def aware_step(state, row, perceived, rate, seconds, now):
    value, until = state
    peak = row["peak"]
    if perceived:
        value = min(peak, value + max(rate, 0.0) * peak * seconds)
    else:
        lowest = row["phases"][max(phase(value, row) - 1, 0)]["at"] * peak
        if now < until:
            lowest = max(lowest, row["caution"]["floor"] * peak)
        decay = row["phases"][phase(value, row)].get("decay", row["decay"])
        value = max(value - decay * peak * seconds, min(lowest, value))
    if phase(value, row) == len(row["phases"]) - 1:
        until = now + row["caution"]["seconds"]
    return value, until


def awareness_vector(name, why, steps, row=ROW):
    state, values, phases = (0.0, -math.inf), [], []
    for s in steps:
        state = aware_step(state, row, s["perceived"], s["rate"], s["seconds"], s["now"])
        values.append(state[0])
        phases.append(phase(state[0], row))
    return {"name": name, "why": why, "kind": "awareness", "row": row, "query": {"steps": steps},
            "expect": {"values": values, "phases": phases}}


def step(perceived, rate, seconds, now):
    return {"perceived": perceived, "rate": rate, "seconds": seconds, "now": now}


def phase_vector(name, why, numbers, row=ROW):
    return {"name": name, "why": why, "kind": "phase", "row": row, "query": {"numbers": numbers},
            "expect": {"phases": [phase(n, row) for n in numbers]}}

# --- the belief ------------------------------------------------------------


def belief_vector(name, why, neighbours, steps):
    shares = [1.0 / len(neighbours)] * len(neighbours)
    all_shares, reseeded = [], []
    for s in steps:
        if "collapse" in s:
            shares = [1.0 if i == s["collapse"] else 0.0 for i in range(len(neighbours))]
            again = False
        else:
            shares, again = unseen_step(shares, neighbours, s["seen"], s["spread"])
        all_shares.append(shares)
        reseeded.append(again)
    return {"name": name, "why": why, "kind": "belief", "query": {"neighbours": neighbours, "steps": steps},
            "expect": {"shares": all_shares, "reseeded": reseeded}}


def unseen_step(shares, neighbours, seen, spread):
    spread = min(max(spread, 0.0), 1.0)
    moved = [0.0] * len(shares)
    for i, edges in enumerate(neighbours):
        given = spread if edges else 0.0
        moved[i] += shares[i] * (1.0 - given)
        for j in edges:
            moved[j] += shares[i] * given / len(edges)
    for i in seen:
        moved[i] = 0.0
    total = sum(moved)
    if total <= 0.0:
        unseen = [i for i in range(len(shares)) if i not in seen]
        return [1.0 / len(unseen) if i in unseen else 0.0 for i in range(len(shares))], True
    return [m / total for m in moved], False


LINGERING = {"peak": 1.0, "decay": 0.1,
             "phases": [{"name": "unaware", "at": 0.0}, {"name": "suspicious", "at": 0.25},
                        {"name": "searching", "at": 0.625, "decay": 0.02}, {"name": "alert", "at": 1.0, "decay": 0.02}],
             "caution": {"floor": 0.0, "seconds": 0.0}}

# --- the particle filter ---------------------------------------------------
# Marsaglia's xorshift, and the filter written out once more, plainly.


def xorshift(state):
    state ^= (state << 13) & 0xFFFFFFFF
    state ^= state >> 17
    state ^= (state << 5) & 0xFFFFFFFF
    return state


class Draw:
    def __init__(self, seed):
        self.state = (seed & 0xFFFFFFFF) or 1

    def uniform(self):
        self.state = xorshift(self.state)
        return self.state / 4294967296.0

    def pick(self, options):
        if len(options) <= 1:
            return options[0]
        self.state = xorshift(self.state)
        return options[self.state % len(options)]


def even(candidates, count):
    return [candidates[i * len(candidates) // count] for i in range(count)]


def tally(nodes, size):
    shares = [0.0] * size
    for n in nodes:
        shares[n] += 1.0 / len(nodes)
    return shares


def particle_step(cloud, graph, knobs, draw, step):
    count = len(cloud["nodes"])
    if "collapse" in step:
        return {"nodes": [step["collapse"]] * count, "from": [-1] * count, "weights": [1.0 / count] * count,
                "emptied": [], "reseeded": False}
    nodes, came = list(cloud["nodes"]), list(cloud["from"])
    for i in range(count):
        u = draw.uniform()
        edges = graph[nodes[i]]
        if u < knobs["walk_on"]:
            options = [n for n in edges if n != came[i]] or edges
        elif u < knobs["walk_on"] + knobs["turn"]:
            options = edges
        else:
            continue
        if options:
            came[i], nodes[i] = nodes[i], draw.pick(options)
    raw, emptied = [], []
    for n in nodes:
        raw.append(0.0 if n in step["seen"] else knobs["unheard"] if n in step["unheard"] else 1.0)
        if n in step["seen"] and n not in emptied:
            emptied.append(n)
    total = sum(raw)
    if total <= 0:
        unseen = [n for n in range(len(graph)) if n not in step["seen"]] or list(range(len(graph)))
        return {"nodes": even(unseen, count), "from": [-1] * count, "weights": [0.0] * count,
                "emptied": emptied, "reseeded": True}
    weights = [w / total for w in raw]
    stride = 1.0 / count
    start, picked, src, acc = draw.uniform() * stride, [], 0, weights[0]
    for i in range(count):
        while start + i * stride > acc and src < count - 1:
            src += 1
            acc += weights[src]
        picked.append(src)
    return {"nodes": [nodes[j] for j in picked], "from": [came[j] for j in picked], "weights": weights,
            "emptied": emptied, "reseeded": False}


def particle_vector(name, why, graph, count, seed, steps, knobs=None):
    knobs = knobs or {"walk_on": 0.7, "turn": 0.2, "unheard": 0.3}
    draw = Draw(seed)
    cloud = {"nodes": even(list(range(len(graph))), count), "from": [-1] * count}
    out = {"nodes": [], "weights": [], "shares": [], "emptied": [], "reseeded": []}
    for step in steps:
        cloud = particle_step(cloud, graph, knobs, draw, step)
        for key in ("nodes", "weights", "emptied", "reseeded"):
            out[key].append(cloud[key])
        out["shares"].append(tally(cloud["nodes"], len(graph)))
    return {"name": name, "why": why, "kind": "particles",
            "query": {"neighbours": graph, "count": count, "seed": seed, "knobs": knobs, "steps": steps},
            "expect": out}


CORRIDOR = [[1], [0, 2], [1, 3], [2]]
ROOMS = [[1, 2], [0, 3], [0, 3], [1, 2, 4], [3]]
LONG_CORRIDOR = [[1], [0, 2], [1, 3], [2, 4], [3, 5], [4]]


def vectors():
    return [
        shape_vector("a-coffin-wide-near-narrow-far", "Beside the eye a body is seen wide; far off only "
                     "straight ahead. The edge of a band belongs to the next one out.",
                     [look(1.0, 100.0), look(5.0, 100.0), look(5.0, 40.0), look(2.5, 0.0), look(12.0, 25.0),
                      look(12.0, 15.0), look(18.0, 0.0)]),
        shape_vector("light-movement-and-hiding", "The same zone in the dark, in the light, moving, and "
                     "half behind a hiding spot; certainty never passes 1.",
                     [look(5.0, 0.0, light=0.0), look(5.0, 0.0, light=0.5), look(5.0, 0.0, moving=True),
                      look(5.0, 0.0, moving=True, hidden=0.5), look(1.0, 0.0, moving=True)]),
        shape_vector("the-stance-counts-points", "One point clear is enough standing, not crouched; "
                     "no point clear is never seen.",
                     [look(5.0, 0.0, (True, False, False), 1), look(5.0, 0.0, (True, False, False), 2),
                      look(5.0, 0.0, (False, False, False), 0)]),
        loudness_vector("loudness-along-the-path", "Loud at the source, nothing at the radius and with "
                        "no path, half the radius when off screen, a factor above one read as one.",
                        [[0.0, 10.0, 1.0], [4.0, 10.0, 1.0], [10.0, 10.0, 1.0], [-1.0, 10.0, 1.0],
                         [4.0, 10.0, 0.5], [4.0, 10.0, 3.0], [2.0, 0.0, 1.0]]),
        awareness_vector("awareness-rises-only-while-perceived", "Half a peak a second for a second, then "
                         "a step with nothing perceived and a high rate: it falls, never rises.",
                         [step(True, 0.5, 1.0, 1.0), step(False, 9.0, 1.0, 2.0), step(True, 0.25, 2.0, 4.0)]),
        awareness_vector("a-fall-stops-a-phase-at-a-time", "From searching, a hundred-second fall stops "
                         "at the floor of suspicious, and the next at nothing.",
                         [step(True, 0.7, 1.0, 1.0), step(False, 0.0, 100.0, 101.0),
                          step(False, 0.0, 100.0, 201.0)]),
        awareness_vector("caution-holds-after-an-alert", "Alerted at ten, it falls to the caution floor "
                         "and stays there until forty, then falls to nothing.",
                         [step(True, 2.0, 1.0, 10.0)] + [step(False, 0.0, 5.0, 10.0 + 5 * k) for k in range(1, 11)]),
        awareness_vector("a-search-lingers-and-suspicion-fades", "With a slow decay set for searching and alert "
                         "and the row's fast one below, a fall from the peak lingers while searching and drops fast "
                         "once suspicious.",
                         [step(True, 2.0, 1.0, 0.0)] + [step(False, 0.0, 5.0, 100.0 + 5 * k) for k in range(1, 9)],
                         row=LINGERING),
        phase_vector("the-phases-are-read-from-the-row", "Each threshold is the start of its phase.",
                     [0.0, 0.24, 0.25, 0.6, 0.625, 0.99, 1.0]),
        belief_vector("belief-spreads-along-a-corridor", "Seen at one end, then unseen: it spreads one "
                      "edge a step and is zeroed where a guard looks.",
                      CORRIDOR, [{"collapse": 0}, {"seen": [], "spread": 0.5}, {"seen": [1], "spread": 0.5},
                                 {"seen": [], "spread": 0.5}]),
        belief_vector("belief-reseeds-when-searched-out", "The only nodes it could be in are seen: the "
                      "belief is reseeded over the rest, evenly.",
                      ROOMS, [{"collapse": 4}, {"seen": [3, 4], "spread": 0.5}, {"seen": [], "spread": 0.3}]),
        particle_vector("particles-walk-on-along-a-corridor", "Collapsed at one end of a corridor, unseen and "
                        "unheard: most particles walk on away from where they were, a few stay.",
                        LONG_CORRIDOR, 8, 7, [{"collapse": 0}] + [{"seen": [], "unheard": []}] * 3),
        particle_vector("particles-thin-where-a-guard-looks-and-hears-nothing", "Spread evenly over the rooms; "
                        "a guard sees one room and would have heard another: the seen room is emptied, the "
                        "unheard one keeps fewer.",
                        ROOMS, 10, 3, [{"seen": [3], "unheard": [1]}, {"seen": [3], "unheard": [1]}]),
        particle_vector("particles-reseed-when-every-one-is-seen", "Collapsed in a dead end the guard then "
                        "sees: every weight is 0, so the cloud is reseeded evenly over the unseen nodes.",
                        ROOMS, 6, 11, [{"collapse": 4}, {"seen": [3, 4], "unheard": []},
                                       {"seen": [], "unheard": [0]}]),
        particle_vector("particles-without-a-sighting-start-even", "No collapse first: the cloud starts spread "
                        "over every node, and walks from there.",
                        CORRIDOR, 7, 0, [{"seen": [], "unheard": [3]}],
                        knobs={"walk_on": 0.5, "turn": 0.4, "unheard": 0.5}),
    ]


if __name__ == "__main__":
    folder = pathlib.Path(sys.argv[1])
    for each in vectors():
        (folder / f"{each['name']}.json").write_text(json.dumps(each, indent=1) + "\n")
