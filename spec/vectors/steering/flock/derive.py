"""Write the flock vectors in this directory.

Imports nothing from the repository, so the numbers come from neither
implementation the vectors hold -- a third copy of the three rules, in plain
tuples and 64-bit floats:

    python3 spec/vectors/steering/flock/derive.py spec/vectors/steering/flock

Two shapes. A "forces" vector is one boid and the neighbours it was handed,
with the three rules' forces and the flock's sum written out; the first is
the case worked by hand on docs/concepts/steering.md. A "steps" vector is a
small flock flying: every boid sees every other, in id order, every force is
worked out from one snapshot before any boid moves, and the samples say
where each one is.
"""
import json, math, sys

def add(a, b): return (a[0] + b[0], a[1] + b[1])
def sub(a, b): return (a[0] - b[0], a[1] - b[1])
def mul(a, k): return (a[0] * k, a[1] * k)
def length(a): return math.hypot(a[0], a[1])
def unit(a):
    n = length(a)
    return (0.0, 0.0) if n == 0 or not math.isfinite(n) else (a[0] / n, a[1] / n)
def limit(a, top):
    n = length(a)
    return mul(a, top / n) if n > top and n > 0 else a
def toward(p, q):
    o = sub(q, p)
    big = max(abs(o[0]), abs(o[1]))
    return (0.0, 0.0) if big == 0 else unit(mul(o, 1.0 / big))
def steer(boid, want, seconds):
    return limit(mul(sub(want, boid["v"]), 1.0 / max(seconds, 0.001)), boid["force"])

def separation(boid, others, radius):
    push = (0.0, 0.0)
    for o in others:
        d = length(sub(o["p"], boid["p"]))
        if d < radius: push = add(push, mul(toward(o["p"], boid["p"]), 1.0 - d / radius))
    return limit(mul(push, boid["force"]), boid["force"])
def alignment(boid, others, seconds):
    heading = (0.0, 0.0)
    for o in others: heading = add(heading, toward((0.0, 0.0), o["v"]))
    heading = toward((0.0, 0.0), heading)
    return (0.0, 0.0) if heading == (0.0, 0.0) else steer(boid, mul(heading, boid["top"]), seconds)
def cohesion(boid, others, seconds):
    if not others: return (0.0, 0.0)
    centre = mul(sum_of([o["p"] for o in others]), 1.0 / len(others))
    return steer(boid, mul(toward(boid["p"], centre), boid["top"]), seconds)
def sum_of(points):
    total = (0.0, 0.0)
    for p in points: total = add(total, p)
    return total
def three(boid, others, v):
    seconds = v.get("time_to_target", 1.0)
    return [separation(boid, others, v["separation_radius"]), alignment(boid, others, seconds), cohesion(boid, others, seconds)]
def flock(boid, others, v):
    weights = v.get("weights", [1.5, 1.0, 1.0])
    total = (0.0, 0.0)
    for f, w in zip(three(boid, others, v), weights): total = add(total, mul(f, w))
    return limit(total, boid["force"])

def boid_of(spec, top, force): return {"p": tuple(spec["position"]), "v": tuple(spec["velocity"]), "top": top, "force": force}
def forces_vector(v):
    b = v["boid"]; boid = boid_of(b, b["max_speed"], b["max_force"])
    others = [boid_of(n, 0.0, 0.0) for n in v["neighbours"]]
    s, a, c = three(boid, others, v)
    v["expected"] = {"separation": list(s), "alignment": list(a), "cohesion": list(c), "flock": list(flock(boid, others, v))}
def steps_vector(v):
    boids = [boid_of(b, v["max_speed"], v["max_force"]) for b in v["boids"]]
    dt = 1.0 / v["steps_per_second"]; wanted = set(v.pop("sample_steps")); v["samples"] = []
    for step in range(max(wanted) + 1):
        if step in wanted:
            v["samples"].append({"step": step, "positions": [list(b["p"]) for b in boids], "velocities": [list(b["v"]) for b in boids]})
        pushes = [flock(b, [o for o in boids if o is not b], v) for b in boids]
        for b, f in zip(boids, pushes):
            b["v"] = limit(add(b["v"], mul(f, dt)), b["top"]); b["p"] = add(b["p"], mul(b["v"], dt))

boid = lambda p, v: {"position": p, "velocity": v, "max_speed": 10.0, "max_force": 20.0}
other = lambda p, v: {"position": p, "velocity": v}
vectors = {
 "two-neighbours-by-hand": dict(shape="forces", why="The case worked on docs/concepts/steering.md. A is 2 away inside the separation radius of 4 and pushes at half strength: (-0.5, 0) times 20 is (-10, 0). Headings (0, 1) and (1, 0) add to the diagonal: wanted (7.071, 7.071), minus the velocity (5, 0). The centre is (1, 3): wanted (3.162, 9.487), minus (5, 0). Weighted 1.5, 1, 1 they add to (-14.767, 16.558), longer than 20, so the flock's force is clamped to (-13.312, 14.926).",
   boid=boid([0.0, 0.0], [5.0, 0.0]), neighbours=[other([2.0, 0.0], [0.0, 8.0]), other([0.0, 6.0], [6.0, 0.0])], separation_radius=4.0),
 "two-close-on-one-side-are-clamped": dict(shape="forces", why="Two neighbours a unit away on the same side push at three-quarter strength each: 1.5 times 20 is 30, clamped to 20. They fly opposite ways, so their headings cancel and alignment asks for nothing.",
   boid=boid([0.0, 0.0], [0.0, 0.0]), neighbours=[other([1.0, 0.0], [0.0, 3.0]), other([1.0, 0.0], [0.0, -3.0])], separation_radius=4.0),
 "nobody-in-sight": dict(shape="forces", why="No neighbour: no push, no heading, no centre. All three rules ask for nothing, and so does the flock -- a lone boid flies on as it was.",
   boid=boid([3.0, 4.0], [2.0, 1.0]), neighbours=[], separation_radius=4.0),
 "far-neighbours-only-pull": dict(shape="forces", why="Both neighbours outside the separation radius: separation is zero, cohesion and alignment pull. Weights 0, 2, 0 and a time_to_target of 0.5: only alignment counts, twice, and the gap is closed twice as hard.",
   boid=boid([0.0, 0.0], [0.0, 4.0]), neighbours=[other([8.0, 2.0], [3.0, 0.0]), other([7.0, -3.0], [4.0, 3.0])], separation_radius=4.0,
   weights=[0.0, 2.0, 0.0], time_to_target=0.5),
 "four-boids-flying": dict(shape="steps", why="Four boids, every one seeing every other in id order, all forces worked out from one snapshot before any moves. Started apart and heading four ways, by step 240 they fly one way, each about 3.1 from its nearest, a little inside the separation radius of 4, and at about half their top speed: alignment asks for top speed, and cohesion's seek of a centre that flies with them asks to shed the velocity, so the two settle halfway.",
   boids=[other([0.0, 0.0], [5.0, 0.0]), other([6.0, 1.0], [0.0, 5.0]), other([2.0, 7.0], [-3.0, -3.0]), other([-4.0, 3.0], [2.0, -4.0])],
   max_speed=10.0, max_force=20.0, separation_radius=4.0, steps_per_second=60, sample_steps=[0, 1, 30, 120, 240]),
}
for name, v in vectors.items():
    shape = v.pop("shape")
    vector = {"name": name, "shape": shape, **v}
    forces_vector(vector) if shape == "forces" else steps_vector(vector)
    open(f"{sys.argv[1]}/{name}.json", "w").write(json.dumps(vector, indent=1) + "\n")
    print(name, vector.get("expected", {}).get("flock") or vector["samples"][-1]["velocities"])
