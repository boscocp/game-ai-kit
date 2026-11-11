"""Write the teamwork vectors in this directory.

Imports nothing from the repository, so the answers come from neither
implementation the vectors hold -- a third copy of the rules, in plain
dictionaries:

    python3 spec/vectors/teamwork/derive.py spec/vectors/teamwork
"""
import json, math, pathlib, sys

# --- tactical positions ----------------------------------------------------

WEIGHTS = {"partial_cover": 40.0, "line_of_fire": 20.0, "other_cover": 20.0, "nearness": 20.0,
           "preferred_range": 10.0, "preferred_metres": 15.0, "range_band": 10.0, "max_travel": 20.0}

def candidate(id, travel, threat=0.0, covered=False, fires=False, others=0.0, area=True, claimed=-1, hidden=False):
    return {"id": id, "travel": travel, "threat_distance": threat, "covered_from_main": covered,
            "fires_on_main": fires, "covered_from_others": others, "in_area": area, "claimed_by": claimed,
            "hidden_from_all": hidden}

def status(bot, c, w, threat, claims):
    if c["travel"] > w["max_travel"]: return "too_far"
    if not c["in_area"]: return "outside_area"
    if claims and c["claimed_by"] not in (-1, bot): return "claimed"
    if threat and w.get("cover_from_all", False) and not c["hidden_from_all"]: return "seen"
    if threat and not c["covered_from_main"] and not c["fires_on_main"]: return "exposed"
    return "kept"

def score(c, w, threat):
    s = w["nearness"] * (1 - c["travel"] / w["max_travel"])
    if not threat: return s
    if c["fires_on_main"]: s += w["partial_cover"] if c["covered_from_main"] else w["line_of_fire"]
    s += w["other_cover"] * c["covered_from_others"]
    return s + w["preferred_range"] * max(0.0, 1 - abs(c["threat_distance"] - w["preferred_metres"]) / w["range_band"])

def positions(name, why, bot, candidates, threat, claims, weights=WEIGHTS):
    statuses = [status(bot, c, weights, threat, claims) for c in candidates]
    scores = [score(c, weights, threat) if s == "kept" else 0.0 for c, s in zip(candidates, statuses)]
    kept = [i for i, s in enumerate(statuses) if s == "kept"]
    chosen = max(kept, key=lambda i: (scores[i], -i)) if kept else -1
    return {"name": name, "why": why, "kind": "positions", "weights": weights,
            "query": {"bot": bot, "has_threat": threat, "use_claims": claims, "candidates": candidates},
            "expect": {"statuses": statuses, "scores": scores, "chosen": chosen}}

# --- influence -------------------------------------------------------------

def influence(name, why, width, height, cell, origin, radius, sources, asked):
    values = [0.0] * (width * height)
    def cell_of(p): return (math.floor((p[0] - origin[0]) / cell), math.floor((p[1] - origin[1]) / cell))
    for place, strength in sources:
        reach, (cx, cy) = math.ceil(radius / cell), cell_of(place)
        for row in range(max(cy - reach, 0), min(cy + reach + 1, height)):
            for col in range(max(cx - reach, 0), min(cx + reach + 1, width)):
                centre = (origin[0] + (col + 0.5) * cell, origin[1] + (row + 0.5) * cell)
                d = math.dist(place, centre)
                if d < radius: values[row * width + col] += strength * (1 - d / radius)
    def at(p):
        col, row = cell_of(p)
        return values[row * width + col] if 0 <= col < width and 0 <= row < height else 0.0
    return {"name": name, "why": why, "kind": "influence",
            "map": {"width": width, "height": height, "cell_size": cell, "origin": list(origin), "radius": radius},
            "query": {"sources": [{"place": list(p), "strength": s} for p, s in sources],
                      "asked": [list(p) for p in asked]},
            "expect": {"values": [at(p) for p in asked]}}

# --- commander -------------------------------------------------------------

COMMAND = {"take": 3.0, "hold": 1.0, "defend": 2.0, "nearest_metres": 1.0}

def priority(o, w):
    if o["held_by"] != 1: return w["take"] / (1 + max(0.0, -o["influence"]))
    return w["hold"] + w["defend"] * max(0.0, -o["influence"])

def assign(squads, objectives, w):
    worth = [priority(o, w) for o in objectives]
    room = [o["ideal"] for o in objectives]
    waiting, orders = list(squads), {}
    while waiting:
        open_ = [i for i, r in enumerate(room) if r > 0] or list(range(len(objectives)))
        pairs = [(max(math.dist(s["position"], objectives[i]["position"]), w["nearest_metres"]) / worth[i], si, i)
                 for si, s in enumerate(waiting) for i in open_]
        cost = min(p[0] for p in pairs)
        _, si, i = next(p for p in pairs if p[0] == cost)
        squad = waiting.pop(si)
        orders[squad["id"]] = objectives[i]["id"]
        room[i] -= squad["size"]
    return orders

def nearest(squads, objectives):
    orders = {}
    for s in squads:
        pool = [o for o in objectives if o["held_by"] != 1] or objectives
        best = None
        for o in pool:
            if best is None or math.dist(s["position"], o["position"]) < math.dist(s["position"], best["position"]):
                best = o
        orders[s["id"]] = best["id"]
    return orders

def objective(id, x, y, held=0, ideal=2, influence=0.0):
    return {"id": id, "position": [x, y], "held_by": held, "ideal": ideal, "influence": influence}

def squad(id, x, y, size=2):
    return {"id": id, "position": [x, y], "size": size}

def commander(name, why, squads, objectives):
    return {"name": name, "why": why, "kind": "commander", "weights": COMMAND,
            "query": {"squads": squads, "objectives": objectives},
            "expect": {"priorities": [priority(o, COMMAND) for o in objectives],
                       "assigned": assign(squads, objectives, COMMAND),
                       "nearest": nearest(squads, objectives)}}

# --- confidence ------------------------------------------------------------

THRESHOLDS = {"attack_at": 1.3, "keep_attacking_at": 1.1, "retreat_at": 0.7, "recover_at": 1.0,
              "per_kill": 0.25, "per_loss": 0.25, "least_enemy": 0.5}

def value(f, t):
    return f["friendly_strength"] / max(f["enemy_strength"], t["least_enemy"]) + t["per_kill"] * f["kills"] - t["per_loss"] * f["losses"]

def step(previous, v, t, may):
    if previous == "retreat" and v < t["recover_at"] and may: return "retreat"
    if v <= t["retreat_at"]: return "retreat" if may else "hold"
    if v >= t["attack_at"]: return "attack"
    if previous == "attack" and v >= t["keep_attacking_at"]: return "attack"
    return "hold"

def confidence(name, why, facts, members, phases):
    out = {"name": name, "why": why, "kind": "confidence", "thresholds": THRESHOLDS,
           "query": {"facts": facts, "members": members, "phases": phases}, "expect": {}}
    for may in (True, False):
        state, values, states = "hold", [], []
        for f in facts:
            v = value(f, THRESHOLDS)
            state = step(state, v, THRESHOLDS, may)
            values.append(v)
            states.append(state)
        out["expect"]["values"] = values
        out["expect"]["states_with_retreat" if may else "states_without_retreat"] = states
    waves = []
    for phase in phases:
        moving = [m for i, m in enumerate(members) if len(members) == 1 or i % 2 == phase % 2]
        waves.append({"phase": phase, "moving": moving, "covering": [m for m in members if m not in moving]})
    out["expect"]["waves"] = waves
    return out

def facts(friendly, enemy, kills=0, losses=0):
    return {"friendly_strength": friendly, "enemy_strength": enemy, "kills": kills, "losses": losses}

# --- passage ---------------------------------------------------------------

# JSON has no infinity: an impossible way, or a fact with no bound, is null.
WAYS = ["wait", "go round", "ask to pass", "another spot"]
PRICES = {"step_seconds": 0.5, "per_enemy_seen": 2.0, "shooting": 1.5, "reloading": 0.5, "covering_a_retreat": 3.0}

def way_costs(f):
    inf = float("inf")
    detour = inf if f["detour_metres"] is None else f["detour_metres"]
    loss = inf if f["spot_loss"] is None else f["spot_loss"]
    return [f["gap"] / f["leaving_speed"] if f["leaving_speed"] > 0 else inf,
            detour / max(f["speed"], 1e-6),
            f["ask_seconds"] if f["teammate"] and not f["refused"] else inf,
            loss / max(f["points_a_second"], 1e-6)]

def nulled(values):
    return [None if v == float("inf") else v for v in values]

def passage_facts(gap=0.0, leaving=0.0, detour=None, speed=4.5, teammate=False, refused=False, ask=1.0,
                  loss=None, points=10.0):
    return {"gap": gap, "leaving_speed": leaving, "detour_metres": detour, "speed": speed, "teammate": teammate,
            "refused": refused, "ask_seconds": ask, "spot_loss": loss, "points_a_second": points}

def request(saves, enemies=0, shooting=False, reloading=False, covering=False, person=False, room=True):
    return {"saves": saves, "enemies_in_sight": enemies, "shooting": shooting, "reloading": reloading,
            "covering_a_retreat": covering, "driven_by_a_person": person, "room_to_step": room}

def step_aside_cost(r, p):
    if r["driven_by_a_person"] or not r["room_to_step"]:
        return None
    return (p["step_seconds"] + p["per_enemy_seen"] * r["enemies_in_sight"] + p["shooting"] * r["shooting"]
            + p["reloading"] * r["reloading"] + p["covering_a_retreat"] * r["covering_a_retreat"])

def passage(name, why, facts, requests):
    costs, chosen = [], []
    for f in facts:
        c = way_costs(f)
        best, way = float("inf"), "wait"
        for w, cost in zip(WAYS, c):
            if cost < best:
                best, way = cost, w
        costs.append(nulled(c))
        chosen.append(way)
    answers = []
    for r in requests:
        cost = step_aside_cost(r, PRICES)
        saves = float("inf") if r["saves"] is None else r["saves"]
        answers.append({"cost": cost, "granted": cost is not None and saves > cost})
    return {"name": name, "why": why, "kind": "passage", "prices": PRICES,
            "query": {"facts": facts, "requests": requests}, "expect": {"costs": costs, "chosen": chosen, "answers": answers}}

def passage_vectors():
    yield passage("wait-for-one-walking-off",
                  "A body 0.4 m from clearing, leaving at 2 m/s: 0.2 s of waiting beats a 3 m way round (0.67 s).",
                  [passage_facts(gap=0.4, leaving=2.0, detour=3.0)], [])
    yield passage("round-one-who-holds",
                  "A body holding (not leaving): waiting is never done, and 3 m round at 4.5 m/s is 0.67 s.",
                  [passage_facts(gap=0.4, detour=3.0)], [])
    yield passage("ask-a-teammate-when-round-is-long",
                  "A teammate holding, the way round 9 m (2 s): asking, 1 s, is cheaper. An enemy in the same "
                  "place may not be asked, and the bot goes round. A teammate that refused lately may not be "
                  "asked either.",
                  [passage_facts(gap=0.4, detour=9.0, teammate=True), passage_facts(gap=0.4, detour=9.0),
                   passage_facts(gap=0.4, detour=9.0, teammate=True, refused=True)], [])
    yield passage("another-spot-when-nothing-else",
                  "No way round, an enemy in the way: the next spot, 5 points less at 10 a second, is 0.5 s.",
                  [passage_facts(gap=0.4, loss=5.0)], [])
    yield passage("nobody-leaving-and-no-gap-is-no-wait",
                  "A body touching and not moving off: gap 0, leaving 0. Waiting is impossible, not free -- "
                  "a >= in place of the > would divide 0 by 0 -- and the way round is taken.",
                  [passage_facts(gap=0.0, leaving=0.0, detour=3.0)], [])
    yield passage("nothing-possible-waits",
                  "No way round, an enemy, no other spot: every way impossible, and the bot waits.",
                  [passage_facts(gap=0.4)], [])
    yield passage("equal-ways-go-to-the-first",
                  "Waiting and going round both 1 s: the first in the order, waiting, is taken. Numbers in "
                  "powers of two, so neither side rounds.",
                  [passage_facts(gap=0.5, leaving=0.5, detour=4.0, speed=4.0)], [])
    yield passage("a-teammate-weighs-the-request",
                  "Idle, its cost is the step, 0.5 s: a saving of 2 s is granted. Two enemies in sight and "
                  "shooting, 0.5 + 4 + 1.5 = 6 s: refused. Covering a retreat and reloading, 4 s, against a "
                  "saving of exactly 4: refused, the saving must be larger. With no other way the saving has "
                  "no end and even a fight gives way; a person at the controls, or no room to step, never.",
                  [], [request(2.0), request(2.0, enemies=2, shooting=True), request(4.0, reloading=True, covering=True),
                       request(None, enemies=2, shooting=True), request(None, person=True), request(None, room=False)])

# --- the vectors -----------------------------------------------------------

def vectors():
    shared = [candidate("A", 6.0, 14.0, True, True, 0.5), candidate("B", 4.0, 12.0, True, True, 0.0),
              candidate("C", 3.0, 16.0, False, True, 0.0)]
    yield positions("claims-spread-the-squad",
                    "A is the best spot (partial cover, half the others' cover) and bot 1 holds it; bot 2 "
                    "must take B, the next best, not stand beside bot 1.",
                    2, [dict(shared[0], claimed_by=1)] + shared[1:], True, True)
    yield positions("without-claims-they-bunch",
                    "The same query with claims off: bot 2 takes A, which bot 1 already holds.",
                    2, [dict(shared[0], claimed_by=1)] + shared[1:], True, False)
    yield positions("every-condition-once",
                    "One candidate per condition, in the order they are asked: too far, outside the area, "
                    "claimed by another, exposed (no cover and no line of fire); and a bot's own claim is no "
                    "obstacle to it.",
                    3, [candidate("far", 25.0, 10.0, True, True), candidate("out", 5.0, 10.0, True, True, area=False),
                        candidate("theirs", 5.0, 10.0, True, True, claimed=4), candidate("bare", 2.0, 10.0),
                        candidate("mine", 9.0, 30.0, True, False, claimed=3)], True, True)
    yield positions("open-fire-loses-to-partial-cover",
                    "Line of fire from the open is 20, from partial cover 40: the nearer open spot loses to "
                    "the farther one behind a low wall, at the same range.",
                    1, [candidate("open", 2.0, 15.0, False, True), candidate("wall", 10.0, 15.0, True, True)], True, True)
    yield positions("no-threat-nearest-wins",
                    "Nobody known: nothing is exposed, the threat terms say nothing, and the nearest wins.",
                    1, [candidate("near", 3.0), candidate("nearer", 1.0), candidate("far", 19.0)], False, True)
    yield influence("friends-add-enemies-subtract",
                    "Two friends of 1 at the same place make it 2 there; an enemy of 1 two cells away takes "
                    "its share off; off the map is zero.",
                    10, 10, 2.0, (0.0, 0.0), 6.0, [((5.0, 5.0), 1.0), ((5.0, 5.0), 1.0), ((9.0, 5.0), -1.0)],
                    [(5.0, 5.0), (9.0, 5.0), (7.0, 5.0), (15.0, 15.0), (-1.0, 3.0)])
    yield influence("an-offset-corner",
                    "A map whose corner is not the origin, a source near its edge clipped to the map.",
                    6, 4, 1.5, (-4.0, -3.0), 3.0, [((-3.9, -2.9), 2.0), ((4.0, 2.0), -0.5)],
                    [(-3.0, -2.0), (0.0, 0.0), (4.4, 2.9), (5.0, 3.0)])
    yield commander("take-before-hold",
                    "Three points, one ours: the two to take are worth 3, ours 1; each squad of two fills a "
                    "point's room of two, cheapest first.",
                    [squad("s1", 0, 0), squad("s2", 30, 0), squad("s3", 15, 20)],
                    [objective("A", 2, 2), objective("B", 28, 2), objective("C", 15, 18, held=1)])
    yield commander("defend-a-point-under-pressure",
                    "Ours, with enemy influence -1.5 on it: 1 + 2 x 1.5 = 4, more than a point to take; the "
                    "nearer squad is sent back to defend it.",
                    [squad("s1", 10, 0), squad("s2", 20, 0)],
                    [objective("A", 0, 0, held=1, influence=-1.5), objective("B", 30, 0, held=-1)])
    yield commander("more-squads-than-room",
                    "Four squads, room for four bots in all: the last two go where the priority is highest, "
                    "nearest first, not nowhere.",
                    [squad("s1", 0, 0), squad("s2", 1, 0), squad("s3", 2, 0), squad("s4", 40, 0)],
                    [objective("A", 0, 10, ideal=2), objective("B", 40, 10, held=1, ideal=2)])
    yield commander("equal-costs-go-to-the-first",
                    "One squad halfway between two points worth the same: the first listed wins, on both "
                    "sides, with and without the commander.",
                    [squad("s1", 0, 0)], [objective("east", 10, 0), objective("west", -10, 0)])
    yield commander("attack-where-they-are-not",
                    "Two points to take, the enemy strong on the nearer (influence -2): 3 / (1 + 2) = 1 against "
                    "3, so the one squad goes to the farther, weaker point.",
                    [squad("s1", 0, 0)], [objective("strong", 10, 0, held=-1, influence=-2.0), objective("weak", 25, 0)])
    yield commander("two-squads-tie-for-one-room",
                    "Two squads equally far from the one point with room for one of them: the first listed "
                    "gets it, the second is sent on to the far point.",
                    [squad("s1", -5, 0), squad("s2", 5, 0)], [objective("A", 0, 0), objective("B", 0, 30)])
    yield positions("hiding-drops-what-anyone-sees",
                    "Asked to hide, threat weights at zero, nearness alone: the nearest spot (2 m) is covered "
                    "from the main threat and fires on it, but a second threat sees it -- seen. The one at 6 m "
                    "is hidden from all, 14 of 20 by nearness; the one at 10 m too, 10. The nearest hidden wins.",
                    0, [candidate("near", 2.0, 8.0, True, True, 0.0), candidate("mid", 6.0, 12.0, True, False, 1.0, hidden=True),
                        candidate("far", 10.0, 16.0, True, False, 1.0, hidden=True)], True, True,
                    dict(WEIGHTS, partial_cover=0.0, line_of_fire=0.0, other_cover=0.0, preferred_range=0.0, cover_from_all=True))
    yield positions("equal-scores-go-to-the-first",
                    "Two candidates with the same facts score the same; the first listed wins.",
                    1, [candidate("left", 5.0, 15.0, True, True), candidate("right", 5.0, 15.0, True, True)], True, True)
    yield confidence("retreat-recover-attack",
                     "Strong, then losing members to a stronger enemy, then reinforced: attack, keep attacking "
                     "down to 1.1, hold, retreat at 0.7, stay retreating below 1.0, recover at 1.0, attack; and "
                     "an attacking squad that sees nobody, 0.5 over the floor of 0.5, drops to hold. Without "
                     "retreat the same squad holds where it would have fallen back.",
                     [facts(4.0, 2.0), facts(3.6, 3.0), facts(3.0, 3.0), facts(2.0, 3.0, losses=1),
                      facts(2.5, 3.0), facts(3.0, 3.0), facts(4.0, 2.0, kills=1), facts(0.5, 0.0)],
                     [7, 3, 9, 4, 1], [0, 1])
    yield confidence("on-every-threshold",
                     "Each value exactly on a threshold: 1.3 enters attack, 1.1 keeps it, 0.7 enters retreat, "
                     "1.0 leaves it. Each comparison's side is pinned, so >= and > cannot be swapped unseen.",
                     [facts(2.6, 2.0), facts(2.2, 2.0), facts(1.4, 2.0), facts(2.0, 2.0)], [1, 2], [0])
    yield confidence("a-lone-survivor",
                     "One member left: it moves in both phases, nobody is left to cover it.",
                     [facts(0.4, 2.0, losses=3)], [5], [0, 1])

# --- the search coordinator and the role arbiter (T70) --------------------

SEARCH_WEIGHTS = {"worth": 10.0, "travel": 0.2}

def search_score(spot, cost, w):
    if spot["searched"] or spot["worth"] <= 0 or cost is None:
        return None
    return spot["worth"] * w["worth"] - cost * w["travel"]

def search_assign(spots, costs, claims, w):
    def best_spot(row, taken):
        best = None
        for s, facts in enumerate(spots):
            v = search_score(facts, row[s], w)
            if s not in taken and v is not None and (best is None or v > best[1]):
                best = (s, v)
        return best
    if not claims:
        return [(best_spot(row, set()) or (-1, 0))[0] for row in costs]
    given, taken = [-1] * len(costs), set()
    while True:
        pair = None
        for g, row in enumerate(costs):
            found = best_spot(row, taken) if given[g] == -1 else None
            if found and (pair is None or found[1] > pair[2]):
                pair = (g, found[0], found[1])
        if pair is None:
            return given
        given[pair[0]] = pair[1]
        taken.add(pair[1])

def search(name, why, spots, costs, claims, cap, last_known):
    return {"name": name, "why": why, "kind": "search", "weights": SEARCH_WEIGHTS,
            "query": {"spots": spots, "costs": costs, "use_claims": claims, "cap": cap, "last_known": last_known},
            "expect": {"assigned": search_assign(spots, [[None if c is None else c for c in row] for row in costs], claims, SEARCH_WEIGHTS),
                       "granted": sorted(sorted(range(len(last_known)), key=lambda i: (last_known[i], i))[:cap])}}

def roles_grant(requests, use, most):
    granted = ["shooter" if r["can_shoot"] else "none" for r in requests]
    if not use:
        return granted
    order = sorted(range(len(requests)), key=lambda i: (-requests[i]["score"], i))
    flankers = 0
    for i in order:
        if requests[i]["role"] == "flanker" and flankers < most:
            granted[i] = "flanker"
            flankers += 1
    if "shooter" not in granted:
        for i in order:
            if requests[i]["can_shoot"] and granted[i] == "flanker":
                granted[i] = "shooter"
                break
    return granted

def roles(name, why, requests, use, most=1):
    return {"name": name, "why": why, "kind": "roles",
            "query": {"requests": requests, "use_arbiter": use, "max_flankers": most},
            "expect": {"granted": roles_grant(requests, use, most)}}

def ask(role, score, can_shoot=True):
    return {"role": role, "score": score, "can_shoot": can_shoot}

def coordination_vectors():
    spots = [{"worth": 0.5, "searched": False}, {"worth": 0.3, "searched": False},
             {"worth": 0.2, "searched": True}, {"worth": 0.0, "searched": False}]
    yield search("claims-divide-the-search",
                 "Two guards, both nearer the best spot. With claims, guard 0 (nearest) takes it and guard 1 the "
                 "next; the searched spot and the worthless one go to no one. Two of three wanting the last known "
                 "position go: the nearest.",
                 spots, [[2.0, 9.0, 1.0, 1.0], [3.0, 4.0, 1.0, 1.0]], True, 2, [5.0, 1.0, 3.0])
    yield search("without-claims-they-search-the-same-spot",
                 "The same query with claims off: both guards go to the best spot. The cap of one sends only the "
                 "nearest, and of equal walks the earlier.",
                 spots, [[2.0, 9.0, 1.0, 1.0], [3.0, 4.0, 1.0, 1.0]], False, 1, [2.0, 2.0])
    yield search("no-spot-left-no-search",
                 "Every spot searched or worthless: no one is given a spot, and a cap of zero sends no one.",
                 [{"worth": 0.4, "searched": True}, {"worth": 0.0, "searched": False}], [[1.0, 1.0]], True, 0, [1.0])
    yield roles("one-flanker-and-the-rest-shoot",
                "Three ask to flank, one to shoot: the best flank is granted, the others refused and shoot.",
                [ask("flanker", 0.4), ask("flanker", 0.9), ask("shooter", 0.5), ask("flanker", 0.6)], True)
    yield roles("someone-always-shoots",
                "The only one who can shoot asks to flank, the other cannot shoot: the flank is refused, it shoots.",
                [ask("flanker", 0.9), ask("flanker", 0.5, False)], True)
    yield roles("without-the-arbiter-everyone-shoots",
                "The arbiter off: everyone who can shoot does, flank requests or not.",
                [ask("flanker", 0.9), ask("shooter", 0.5), ask("flanker", 0.4, False)], False)

# --- attack tokens (T154) ----------------------------------------------------

def fnv(text):
    h = 2166136261
    for b in text.encode("utf-8"):
        h = ((h ^ b) * 16777619) & 0xFFFFFFFF
    return h

def run_tokens(config, script):
    pools, free = config["pools"], dict(config["pools"])
    waiting, holding, events, answers = [], {}, [], []
    next_grant, now = {k: -math.inf for k in pools}, 0.0
    def key(w):
        patient = w["passed"] >= config["patience"]
        return (0.0 if patient else 1.0, 0.0 if patient else -float(w["priority"]), w["asked_at"], w["distance"],
                float(fnv(f"{config['tie_seed']}:{w['id']}")), w["id"])
    def give_back(id, what):
        h = holding.pop(id)
        free[h["kind"]] += h["cost"]
        events.append([now, id, h["kind"], what])
    for e in script:
        now = e.get("at", now)
        if e["do"] == "request":
            mine = [w for w in waiting if w["id"] == e["id"]]
            if e["kind"] not in pools: answers.append("refused_kind")
            elif not 1 <= e["cost"] <= pools[e["kind"]]: answers.append("refused_cost")
            elif e["id"] in holding:
                answers.append("holding" if holding[e["id"]]["kind"] == e["kind"] else "refused_holding")
            elif mine and mine[0]["kind"] == e["kind"] and mine[0]["cost"] == e["cost"]:
                mine[0].update(priority=e["priority"], distance=e["distance"])
                answers.append("waiting")
            else:
                if mine:
                    waiting.remove(mine[0])
                    events.append([now, e["id"], mine[0]["kind"], "withdrawn"])
                waiting.append(dict(e, asked_at=now, passed=0))
                answers.append("waiting")
        elif e["do"] == "withdraw":
            mine = [w for w in waiting if w["id"] == e["id"]]
            if mine:
                waiting.remove(mine[0])
                events.append([now, e["id"], mine[0]["kind"], "withdrawn"])
            answers.append(bool(mine))
        elif e["do"] == "release":
            if e["reason"] in ("died", "interrupted"): waiting = [w for w in waiting if w["id"] != e["id"]]
            ok = e["id"] in holding and e["reason"] in ("ended", "interrupted", "died", "revoked")
            if ok: give_back(e["id"], e["reason"])
            answers.append(ok)
        elif e["do"] == "revoke":
            gone = sorted(i for i, h in holding.items() if h["kind"] == e["kind"])
            for i in gone: give_back(i, "revoked")
            answers.append(gone)
        else:
            for i in sorted(i for i, h in holding.items() if now - h["since"] >= config["timeouts"][h["kind"]]):
                give_back(i, "timed_out")
            granted = []
            for kind in sorted(pools):
                factor = config["multipliers"].get(e["state"], {}).get(kind, 1.0)
                while now >= next_grant[kind]:
                    queue = sorted((w for w in waiting if w["kind"] == kind), key=key)
                    if not queue or queue[0]["cost"] > free[kind]: break
                    head = queue[0]
                    waiting.remove(head)
                    for w in queue[1:]: w["passed"] += 1
                    holding[head["id"]] = {"kind": kind, "cost": head["cost"], "since": now}
                    free[kind] -= head["cost"]
                    events.append([now, head["id"], kind, "granted"])
                    granted.append(head["id"])
                    next_grant[kind] = now + config["delays"][kind] * factor
            answers.append({"granted": granted, "free": dict(free),
                            "holders": {k: sorted(i for i, h in holding.items() if h["kind"] == k) for k in pools}})
    return answers, events

TOKENS = {"pools": {"melee": 2, "ranged": 1}, "delays": {"melee": 0.5, "ranged": 2.0},
          "timeouts": {"melee": 4.0, "ranged": 6.0},
          "multipliers": {"busy": {"melee": 1.0, "ranged": 2.0}, "idle": {"melee": 0.5, "ranged": 0.5}},
          "patience": 3, "tie_seed": 7}

def tokens(name, why, script, config=TOKENS):
    answers, events = run_tokens(config, script)
    return {"name": name, "why": why, "kind": "tokens", "query": {"config": config, "script": script},
            "expect": {"answers": answers, "events": events}}

def want(id, at, kind="melee", cost=1, priority=0, distance=5.0):
    return {"do": "request", "at": at, "id": id, "kind": kind, "cost": cost, "priority": priority, "distance": distance}

def tick(at, state="normal"):
    return {"do": "step", "at": at, "state": state}

def done(id, at, reason="ended"):
    return {"do": "release", "at": at, "id": id, "reason": reason}

def token_vectors():
    yield tokens("two-melee-tokens-the-third-waits",
                 "Three ask to strike and one to shoot. Melee 2, ranged 1, melee spaced 0.5 s: at 0 the nearest "
                 "melee and the archer, at 0.5 the next nearest, at 1.0 the pool is full and the third circles. "
                 "One attack ends, and at 1.5 the third strikes.",
                 [want("far", 0.0, distance=9.0), want("near", 0.0, distance=2.0), want("mid", 0.0, distance=4.0),
                  want("archer", 0.0, "ranged", distance=20.0), tick(0.0), tick(0.5), tick(1.0), done("near", 1.25),
                  tick(1.5)])
    yield tokens("the-boss-goes-first-and-is-not-overtaken",
                 "A boss's heavy attack costs both melee tokens and has priority 5. Two minions hold them; when "
                 "one ends, the boss is first and does not fit, and the waiting minion m3 may not take the token "
                 "past it. When the second ends, the boss strikes.",
                 [want("m1", 0.0, distance=1.0), want("m2", 0.0, distance=2.0), tick(0.0), tick(0.5),
                  want("boss", 1.0, cost=2, priority=5, distance=6.0), want("m3", 1.0, distance=1.5),
                  done("m1", 1.0), tick(1.0), done("m2", 1.25), tick(1.5)])
    yield tokens("the-longest-waiting-before-the-nearest",
                 "One melee token, held. 'early' has waited since 0 at 8 m; 'late' asks at 0.5 from 1 m. Equal "
                 "priority: the one waiting longest is next, though the other is nearer.",
                 [want("holder", 0.0, distance=2.0), tick(0.0), want("early", 0.0, distance=8.0),
                  want("late", 0.5, distance=1.0), done("holder", 1.0), tick(1.0)],
                 dict(TOKENS, pools={"melee": 1, "ranged": 1}))
    yield tokens("withdrawn-and-interrupted-leave-the-queue",
                 "One melee token, held. w1 changes its mind and withdraws, logged; w2 is staggered while waiting "
                 "and is interrupted, which takes it out too; withdrawing one not waiting answers false. When the "
                 "holder ends, w3 -- the farthest -- is the one granted.",
                 [want("holder", 0.0), tick(0.0), want("w1", 0.0, distance=1.0), want("w2", 0.0, distance=2.0),
                  want("w3", 0.0, distance=3.0), {"do": "withdraw", "at": 0.25, "id": "w1"},
                  done("w2", 0.3, "interrupted"), {"do": "withdraw", "at": 0.3, "id": "nobody"},
                  done("holder", 0.75), tick(1.0)],
                 dict(TOKENS, pools={"melee": 1, "ranged": 1}))
    yield tokens("asking-again-for-another-cost-waits-from-now",
                 "Melee 2, one held by h. The troll asks for a swing (1) at 0.1, then for its charge (2) at 0.3: "
                 "the swing is withdrawn and the charge waits from 0.3, behind mid, who asked at 0.2. mid gets "
                 "the free token at 0.5; when h and mid end, the troll charges with both.",
                 [want("h", 0.0), tick(0.0), want("troll", 0.1, distance=1.0), want("mid", 0.2, distance=5.0),
                  want("troll", 0.3, cost=2, distance=1.0), tick(0.5), done("h", 0.75), done("mid", 0.9),
                  tick(1.0)])
    yield tokens("a-holder-asking-for-another-kind-is-refused",
                 "a1 holds the ranged token. Asking for melee while holding it is refused by name; asking for "
                 "ranged again is told it holds.",
                 [want("a1", 0.0, "ranged"), tick(0.0), want("a1", 0.5, "melee"), want("a1", 0.5, "ranged"),
                  tick(0.5)])
    yield tokens("a-cost-above-the-pool-is-refused",
                 "A cost of 3 against a melee pool of 2 is refused at once, by name, and never queued; a kind the "
                 "pool does not have is refused too; a holder asking again is told it holds.",
                 [want("giant", 0.0, cost=3), want("ghost", 0.0, "magic"), want("m1", 0.0), tick(0.0),
                  want("m1", 0.2), tick(0.5)])
    yield tokens("revoked-is-free-on-the-same-step",
                 "a1 holds the ranged token. At 2.0 melee pressure starts: the game revokes the ranged kind, the "
                 "token is free at once, and a2, waiting since 0, takes it on the step at that same moment. The "
                 "player busy, the next ranged grant waits 2 x 2 = 4 s: nothing at 4.0, a1 again at 6.0.",
                 [want("a1", 0.0, "ranged", distance=20.0), want("a2", 0.0, "ranged", distance=25.0), tick(0.0),
                  {"do": "revoke", "at": 2.0, "kind": "ranged"}, tick(2.0, "busy"), done("a2", 2.5),
                  want("a1", 2.5, "ranged", distance=20.0), tick(4.0, "busy"), tick(6.0, "busy")])
    yield tokens("death-and-timeout-give-tokens-back",
                 "m1 dies holding at 0.75: its token is back at once, and m3 takes it at 1.0. m4 dies waiting, and "
                 "is never served. m2 never releases: at 4.5, 4 s after its grant, the timeout takes it back.",
                 [want("m1", 0.0, distance=1.0), want("m2", 0.0, distance=2.0), want("m3", 0.0, distance=3.0),
                  want("m4", 0.0, distance=4.0), tick(0.0), tick(0.5), done("m1", 0.75, "died"),
                  done("m4", 0.75, "died"), tick(1.0), tick(4.5)])
    yield tokens("patience-serves-the-passed-over",
                 "One melee token. A low minion waits while h1, h2 and h3, priority 3, strike in turn, the player "
                 "idle so the delay is halved to 0.25 s. Passed over three times, the patience, the minion is "
                 "served before h4, priority 3, who came later -- no starvation. Then h4.",
                 [want("low", 0.0, priority=0, distance=1.0), want("h1", 0.0, priority=3, distance=2.0),
                  want("h2", 0.0, priority=3, distance=3.0), want("h3", 0.0, priority=3, distance=4.0),
                  tick(0.0, "idle"), done("h1", 0.2), tick(0.25, "idle"), done("h2", 0.45), tick(0.5, "idle"),
                  want("h4", 0.6, priority=3, distance=1.0), done("h3", 0.7), tick(0.75, "idle"),
                  done("low", 0.9), tick(1.0, "idle")],
                 dict(TOKENS, pools={"melee": 1, "ranged": 1}))
    for seed, order in ((7, ("left", "right")), (7, ("right", "left")), (8, ("left", "right"))):
        yield tokens(f"equal-facts-go-by-the-seed-{seed}-{order[0]}-first",
                     f"Two requests equal in every fact, asked {order[0]} first, seed {seed}: the seeded hash "
                     "decides, not the order they were stored in. The same seed either way round gives the same "
                     "token; another seed may give the other.",
                     [want(order[0], 0.0), want(order[1], 0.0), tick(0.0)],
                     dict(TOKENS, pools={"melee": 1, "ranged": 1}, tie_seed=seed))

# --- engagement rings (T155) -------------------------------------------------

RINGS = {"rings": [{"name": "inner", "radius": 2.0, "count": 4, "phase": 0.0},
                   {"name": "waiting", "radius": 4.5, "count": 8, "phase": math.pi / 8},
                   {"name": "ranged", "radius": 9.0, "count": 6, "phase": 0.0}],
         "spacing": 1.5, "weights": dict(WEIGHTS, max_travel=30.0)}

def ring_points(config, at):
    found = []
    for ring in config["rings"]:
        for i in range(ring["count"]):
            angle = ring["phase"] + 2 * math.pi * i / ring["count"]
            found.append({"id": f"{ring['name']}-{i}", "ring": ring["name"],
                          "at": (at[0] + math.cos(angle) * ring["radius"], at[1] + math.sin(angle) * ring["radius"])})
    return found

def crowding(points, claims, enemy, point, spacing):
    for other in points:
        holder = claims.get(other["id"], -1)
        if holder in (-1, enemy): continue
        if other is point or math.dist(other["at"], point["at"]) < spacing: return holder
    return -1

def ring_choice(config, points, claims, blocked, target, enemy, ring, start, view_from, forward, front_only):
    cands = []
    for p in points:
        ahead = (p["at"][0] - view_from[0]) * forward[0] + (p["at"][1] - view_from[1]) * forward[1] > 0
        cands.append(candidate(p["id"], math.dist(start, p["at"]), threat=math.dist(target, p["at"]),
                               covered=False, fires=p["id"] not in blocked,
                               area=p["ring"] == ring and (ahead or not front_only),
                               claimed=crowding(points, claims, enemy, p, config["spacing"])))
    w = config["weights"]
    statuses = [status(enemy, c, w, True, True) for c in cands]
    kept = [i for i, s in enumerate(statuses) if s == "kept"]
    chosen = max(kept, key=lambda i: (score(cands[i], w, True), -i)) if kept else -1
    return statuses, chosen

def run_rings(config, target, view_from, forward, blocked, script):
    points, claims, answers = ring_points(config, target), {}, []
    for event in script:
        if event["do"] == "place":
            target = tuple(event["target"])
            points = ring_points(config, target)
            answers.append(None)
            continue
        enemy = event["id"]
        mine = [k for k, v in claims.items() if v == enemy]
        for k in mine: del claims[k]
        if event["do"] == "release":
            answers.append(bool(mine))
            continue
        args = (config, points, claims, blocked, target, enemy, event["ring"], tuple(event["from"]), view_from, forward)
        statuses, chosen = ring_choice(*args, True)
        if chosen == -1: statuses, chosen = ring_choice(*args, False)
        if chosen != -1: claims[points[chosen]["id"]] = enemy
        answers.append({"point": points[chosen]["id"] if chosen != -1 else "", "statuses": statuses})
    return points, claims, answers

def rings(name, why, script, blocked=(), target=(0.0, 0.0), view_from=(0.0, -3.0), forward=(0.0, 1.0), config=RINGS):
    points, claims, answers = run_rings(config, target, view_from, forward, set(blocked), script)
    return {"name": name, "why": why, "kind": "rings",
            "query": {"config": config, "target": list(target), "view_from": list(view_from),
                      "view_forward": list(forward), "blocked": list(blocked), "script": script},
            "expect": {"points": [list(p["at"]) for p in points], "answers": answers,
                       "claims": {k: claims[k] for k in sorted(claims)}}}

def stand(id, ring, x, y):
    return {"do": "choose", "id": id, "ring": ring, "from": [x, y]}

def ring_vectors():
    yield rings("the-nearest-free-point-in-front",
                "A waiting enemy behind the player's camera: the waiting point nearest it is behind the view, so it "
                "is outside the area, and the nearest point in front is taken. A second enemy close by does not "
                "take the first one's point.",
                [stand(1, "waiting", 0.7, -6.0), stand(2, "waiting", 0.9, -6.2)])
    yield rings("behind-only-when-the-front-is-full",
                "Six waiting enemies take every waiting point in front of the view; the seventh is sent behind, "
                "where the only free points are left.",
                [stand(i, "waiting", 0.3 + i, 7.0 - 0.4 * i) for i in range(1, 8)])
    yield rings("a-claim-crowds-its-neighbours",
                "With a spacing wider than two neighbours on the waiting ring, a claim leaves its neighbours "
                "claimed by it: the second enemy, closest to the first's neighbour, takes the point after.",
                [stand(1, "waiting", 4.4, 1.6), stand(2, "waiting", 3.4, 3.0)],
                config=dict(RINGS, spacing=3.5))
    yield rings("the-ranged-band-needs-a-line-of-sight",
                "Two of the four ranged points in front of the view are behind cover: they are exposed, and the "
                "first ranged enemy takes the nearest it can shoot from, the second the other. The third finds "
                "nothing free in front and is sent behind, to a point with a line of sight.",
                [stand(7, "ranged", 7.2, 6.4), stand(8, "ranged", -6.0, 2.5), stand(9, "ranged", 8.0, -2.0)],
                blocked=["ranged-1", "ranged-0"])
    yield rings("a-ranged-enemy-with-no-line-has-no-point",
                "Every point of the ranged band is behind cover: no point is left, and the answer is none.",
                [stand(7, "ranged", 7.2, 6.4)], blocked=[f"ranged-{i}" for i in range(6)])
    yield rings("a-token-holder-steps-in-and-back-out",
                "A melee enemy waits, is granted a token and steps into the inner ring -- its waiting point is free "
                "again for another -- then gives the token back and goes out.",
                [stand(1, "waiting", 1.0, 5.5), stand(1, "inner", 1.6, 4.0), stand(2, "waiting", 1.2, 5.6),
                 stand(1, "waiting", 0.4, 2.2)])
    yield rings("level-with-the-camera-is-behind",
                "The camera stands on the target, looking along +y: inner-0, at (2, 0), is exactly level with it, "
                "so it counts as behind. The token holder beside it takes inner-1, in front, not inner-0 nor "
                "inner-3, the nearer of the other two.",
                [stand(1, "inner", 2.5, -0.5)], view_from=(0.0, 0.0))
    yield rings("the-rings-follow-the-target",
                "The target moves: every point moves with it and the claims stay. A second enemy then avoids the "
                "first one's point where it is now; a released point is free.",
                [stand(1, "waiting", 4.2, 1.5), {"do": "place", "target": [3.0, 1.0]},
                 stand(2, "waiting", 7.4, 3.0), {"do": "release", "id": 1}, {"do": "release", "id": 1},
                 stand(3, "waiting", 7.4, 3.0)])

def main(directory):
    folder = pathlib.Path(directory)
    for vector in list(vectors()) + list(passage_vectors()) + list(coordination_vectors()) + list(token_vectors())\
            + list(ring_vectors()):
        (folder / f"{vector['name']}.json").write_text(json.dumps(vector, indent=1) + "\n", encoding="utf-8")

if __name__ == "__main__":
    main(sys.argv[1])
