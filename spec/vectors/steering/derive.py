"""Write the steering vectors in this directory.

Imports nothing from the repository, so the trajectories come from neither
implementation the vectors hold -- a third copy of the maths, in plain
tuples and 64-bit floats:

    python3 spec/vectors/steering/derive.py spec/vectors/steering
"""
import json, math, sys

def add(a, b): return (a[0] + b[0], a[1] + b[1])
def sub(a, b): return (a[0] - b[0], a[1] - b[1])
def mul(a, k): return (a[0] * k, a[1] * k)
def length(a): return math.hypot(a[0], a[1])
def dot(a, b): return a[0] * b[0] + a[1] * b[1]
def unit(a):
    n = length(a)
    return (0.0, 0.0) if n == 0 or not math.isfinite(n) else (a[0] / n, a[1] / n)
def limit(a, top):
    n = length(a)
    return mul(a, top / n) if n > top and n > 0 else a
def toward(p, q):
    o = sub(q, p)
    if all(math.isfinite(c) for c in o): return unit(o)
    return unit(tuple(math.copysign(1.0, c) if math.isinf(c) else 0.0 for c in o))

def seek(car, b):
    return limit(sub(mul(toward(car["p"], b["target"]), car["top"]), car["v"]), car["force"])
def arrive(car, b):
    d = length(sub(b["target"], car["p"]))
    s = car["top"] * (d / b["braking_radius"] if d < b["braking_radius"] else 1.0)
    want = mul(toward(car["p"], b["target"]), s)
    return limit(mul(sub(want, car["v"]), 1.0 / b.get("time_to_target", 0.1)), car["force"])
def pursue(car, b):
    q = b["quarry"]
    t = min(length(sub(q["position"], car["p"])) / car["top"], b.get("max_prediction", 1.0))
    return seek(car, {"target": add(q["position"], mul(q["velocity"], t))})
def avoid(car, b):
    h = unit(car["v"])
    if h == (0.0, 0.0): return (0.0, 0.0)
    reach = b["look_ahead"] * min(length(car["v"]) / car["top"], 1.0)
    best, best_along, best_point = -1, math.inf, None
    for i, (c, r) in enumerate(zip(b["centres"], b["radii"])):
        pt = add(car["p"], mul(h, min(max(dot(sub(c, car["p"]), h), 0.0), reach)))
        along = dot(sub(pt, car["p"]), h)
        if length(sub(pt, c)) <= r and along < best_along: best, best_along, best_point = i, along, pt
    if best < 0: return (0.0, 0.0)
    away = unit(sub(best_point, b["centres"][best]))
    if away == (0.0, 0.0): away = (h[1], -h[0])
    return mul(away, car["force"])
KINDS = {"seek": seek, "arrive": arrive, "pursue": pursue, "avoid": avoid}

def play(vector):
    v = vector["vehicle"]
    car = {"p": tuple(v["position"]), "v": tuple(v["velocity"]), "top": v["max_speed"], "force": v["max_force"]}
    behaviours = [dict(b) for b in vector["behaviours"]]
    for b in behaviours:
        for key in ("target", "centres"):
            if key in b: b[key] = tuple(b[key]) if key == "target" else [tuple(c) for c in b[key]]
        if "quarry" in b: b["quarry"] = {k: tuple(x) for k, x in b["quarry"].items()}
    dt = 1.0 / vector["steps_per_second"]
    wanted = set(vector["sample_steps"]); samples = []
    for step in range(max(wanted) + 1):
        total = (0.0, 0.0)
        for b in behaviours: total = add(total, mul(KINDS[b["kind"]](car, b), b.get("weight", 1.0)))
        force = limit(total, car["force"])
        if step in wanted:
            samples.append({"step": step, "position": list(car["p"]), "velocity": list(car["v"]), "force": list(force)})
        car["v"] = limit(add(car["v"], mul(force, dt)), car["top"]); car["p"] = add(car["p"], mul(car["v"], dt))
        for b in behaviours:
            if "quarry" in b: b["quarry"]["position"] = add(b["quarry"]["position"], mul(b["quarry"]["velocity"], dt))
    return samples

car = lambda p, v: {"position": p, "velocity": v, "max_speed": 10.0, "max_force": 20.0}
vectors = {
 "seek-turns-and-overshoots": dict(why="Seek from a start moving away: it turns towards the target and reaches it near step 225 still at speed, so by step 260 it is past it, and by 300 coming back. The defect arrive exists to fix.",
   vehicle=car([0.0, 0.0], [0.0, -5.0]), behaviours=[{"kind": "seek", "target": [20.0, 15.0]}], sample_steps=[0, 1, 90, 225, 260, 300]),
 "arrive-slows-and-stops": dict(why="Arrive from a moving start: seek while far, then the desired speed falls inside the braking radius of 6, and by step 300 it is at the target and still.",
   vehicle=car([0.0, 0.0], [3.0, 4.0]), behaviours=[{"kind": "arrive", "target": [12.0, 5.0], "braking_radius": 6.0}], sample_steps=[0, 1, 45, 120, 300]),
 "pursue-a-crossing-quarry": dict(why="The quarry crosses the vehicle's front at 4 units a second, moving on after every step; pursue aims ahead of it, never more than a second ahead.",
   vehicle=car([0.0, 0.0], [0.0, 0.0]), behaviours=[{"kind": "pursue", "quarry": {"position": [20.0, -10.0], "velocity": [0.0, 4.0]}, "max_prediction": 1.0}], sample_steps=[0, 1, 30, 90, 150]),
 "avoid-swerves-alone": dict(why="Nothing to go to, only something to miss: an obstacle just off the line ahead. While it is in the look-ahead, avoid pushes at full force away from it from the far end of the stretch -- back and aside, so the vehicle slows and turns; once the way is clear it asks for nothing and coasts past.",
   vehicle=car([0.0, 0.0], [8.0, 0.0]), behaviours=[{"kind": "avoid", "centres": [[6.0, -0.5]], "radii": [2.0], "look_ahead": 5.0}], sample_steps=[0, 1, 15, 30, 60]),
 "seek-and-avoid-go-round": dict(why="Seek and avoid added with weights 1 and 2 and clamped once (Steering.combined): an obstacle sits a little off the straight line to the target, and the two together go round it.",
   vehicle=car([0.0, 0.0], [10.0, 0.0]), behaviours=[{"kind": "seek", "target": [24.0, 0.0], "weight": 1.0},
     {"kind": "avoid", "centres": [[10.0, 0.6]], "radii": [2.5], "look_ahead": 6.0, "weight": 2.0}], sample_steps=[0, 1, 20, 60, 120, 180]),
 "seek-and-avoid-tie-on-the-line": dict(why="The weighted sum's failure, pinned so it is a measurement: the obstacle exactly on the line. Avoid pushes straight back from the end of its look-ahead, seek pulls straight on, and the vehicle stalls in front of the obstacle, inching to and fro about x = 7.4, and never gets past -- a tie a weighted sum cannot break (see Steering's header).",
   vehicle=car([0.0, 0.0], [10.0, 0.0]), behaviours=[{"kind": "seek", "target": [24.0, 0.0], "weight": 1.0},
     {"kind": "avoid", "centres": [[10.0, 0.0]], "radii": [2.5], "look_ahead": 6.0, "weight": 2.0}], sample_steps=[0, 1, 60, 180, 300, 600]),
}
for name, v in vectors.items():
    vector = {"name": name, "why": v["why"], "steps_per_second": 60, "vehicle": v["vehicle"],
              "behaviours": v["behaviours"], "sample_steps": v["sample_steps"]}
    vector["samples"] = play(vector)
    del vector["sample_steps"]
    open(f"{sys.argv[1]}/{name}.json", "w").write(json.dumps(vector, indent=1) + "\n")
    last = vector["samples"][-1]
    print(name, [round(c, 3) for c in last["position"]], round(length(last["velocity"]), 4))
