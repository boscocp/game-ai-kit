"""Write the decision-tree vectors in this directory.

Imports nothing from the repository, so the numbers come from neither
implementation the vectors hold -- `gameaikit.training.tree`, which fits,
and `ai_learning`'s `LearnedTree`, which walks:

    python3 spec/vectors/tree/derive.py spec/vectors/tree
"""
import json, sys
from fractions import Fraction

def number(v): return isinstance(v, (int, float)) and not isinstance(v, bool)

def answer(node, situation):
    v = situation.get(node["feature"])
    if "at_most" in node: return v <= node["at_most"] if number(v) else None
    return v == node["is"] if isinstance(v, str) else None

def gini_n(rows, classes):  # Gini impurity times the number of rows
    if not rows: return Fraction(0)
    return len(rows) - Fraction(sum(sum(1 for _, a in rows if a == c) ** 2 for c in classes), len(rows))

def tests(rows, feature):
    vs = [s.get(feature) for s, _ in rows]
    if all(isinstance(v, str) for v in vs): return [{"feature": feature, "is": w} for w in sorted(set(vs))]
    if all(number(v) for v in vs):
        u = sorted(set(vs)); return [{"feature": feature, "at_most": (a + b) / 2} for a, b in zip(u, u[1:])]
    return []

def grow(rows, features, classes, depth, min_leaf, nodes):
    index = len(nodes); nodes.append(None)
    best, low = None, gini_n(rows, classes)
    for f in (features if depth > 0 else []):
        for t in tests(rows, f):
            yes = [r for r in rows if answer(t, r[0])]; no = [r for r in rows if not answer(t, r[0])]
            if len(yes) >= min_leaf and len(no) >= min_leaf and gini_n(yes, classes) + gini_n(no, classes) < low:
                best, low = t, gini_n(yes, classes) + gini_n(no, classes)
    if best is None:
        nodes[index] = {"counts": {c: n for c in classes if (n := sum(1 for _, a in rows if a == c))}}
        return index
    y = grow([r for r in rows if answer(best, r[0])], features, classes, depth - 1, min_leaf, nodes)
    n = grow([r for r in rows if not answer(best, r[0])], features, classes, depth - 1, min_leaf, nodes)
    nodes[index] = {**best, "yes": y, "no": n}
    return index

def walk(model, situation):
    path, i = [], 0
    while True:
        path.append(i); node = model["nodes"][i]
        if "counts" in node: break
        a = answer(node, situation)
        if a is None: break
        i = node["yes"] if a else node["no"]
    counts = model["nodes"][path[-1]].get("counts", {})
    best = ""
    for c in model["classes"]:
        if counts.get(c, 0) > counts.get(best, 0): best = c
    return {"situation": situation, "path": path, "counts": counts, "likeliest": best}

def fitted(name, description, rows, features, classes, max_depth, min_leaf, asked):
    nodes = []
    grow([(dict(zip(features, r[:-1])), r[-1]) for r in rows], features, classes, max_depth, min_leaf, nodes)
    model = {"kind": "tree", "features": features, "classes": classes, "nodes": nodes}
    return name, dict(description=description, rows=rows, max_depth=max_depth, min_leaf=min_leaf,
                      model=model, cases=[walk(model, s) for s in asked])

rows = [["close", 0, "throw"], ["close", 1, "throw"], ["close", 5, "low"], ["close", 6, "low"],
        ["near", 0, "low"], ["near", 4, "low"], ["far", 0, "high"], ["far", 3, "high"]]
vectors = dict([
 fitted("fit-by-hand", "Eight rows, a word and a number, depth 2, a leaf of one row allowed. The README works the root by hand: "
        "of every test, 'distance is far' leaves the two sides least mixed; below it, 'health at most 2.5'. Asked: a row it "
        "was fitted on, one it never saw, a word it never saw (it goes 'no'), a number where a word is asked (the walk stops "
        "at the root, and answers nothing), a feature missing that no test on the path asks about, one that the root asks, and a health of exactly "
        "2.5 -- at most includes the threshold, so it goes 'yes'.",
        rows, ["distance", "health"], ["high", "low", "throw"], 2, 1,
        [{"distance": "close", "health": 1}, {"distance": "near", "health": 3.5}, {"distance": "corner", "health": 0},
         {"distance": 7, "health": 0}, {"distance": "far"}, {"health": 1}, {"distance": "close", "health": 2.5}]),
 fitted("fit-capped", "The same rows, held back: depth 1, and no leaf under three rows. The cap is what keeps a tree from "
        "learning the rows themselves: one test, and a leaf where high and throw tie at two -- the first in classes, high, "
        "is its answer.",
        rows, ["distance", "health"], ["high", "low", "throw"], 1, 3,
        [{"distance": "close", "health": 5}, {"distance": "far", "health": 0}]),
 fitted("fit-a-tie", "Two tests split equally well: the first in feature order wins, so the tree is the same on every machine. "
        "And a pure node is a leaf whatever the depth allows.",
        [["a", "x", "yes"], ["a", "x", "yes"], ["b", "y", "no"], ["b", "y", "no"]], ["first", "second"], ["yes", "no"], 3, 1,
        [{"first": "a", "second": "y"}, {"first": "b", "second": "x"}]),
])
for name, v in vectors.items():
    open(f"{sys.argv[1]}/{name}.json", "w").write(json.dumps(v, indent=1) + "\n")
    print(name, len(v["model"]["nodes"]), "nodes", [c["likeliest"] for c in v["cases"]])
