"""Write the random-forest vectors in this directory.

Imports nothing from the repository, so the numbers come from neither
implementation the vectors hold -- `gameaikit.training.forest`, which fits,
and `ai_learning`'s `LearnedForest`, which votes:

    python3 spec/vectors/forest/derive.py spec/vectors/forest
"""
import json, math, sys
from fractions import Fraction

class Xorshift:  # Marsaglia's 32-bit xorshift, as ai_core's GakXorshift
    def __init__(self, seed): self.s = (seed & 0xFFFFFFFF) or 1
    def index(self, count):
        if count <= 1: return 0
        self.s ^= (self.s << 13) & 0xFFFFFFFF; self.s ^= self.s >> 17; self.s ^= (self.s << 5) & 0xFFFFFFFF
        return self.s % count

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

def drawn(features, g):  # isqrt(len) features, without replacement, back in feature order
    pool, out = list(features), []
    for _ in range(min(max(1, math.isqrt(len(features))), len(features))): out.append(pool.pop(g.index(len(pool))))
    return sorted(out, key=features.index)

def grow(rows, features, classes, depth, min_leaf, nodes, g):
    index = len(nodes); nodes.append(None)
    best, low = None, gini_n(rows, classes)
    for f in (drawn(features, g) if depth > 0 else []):
        for t in tests(rows, f):
            yes = [r for r in rows if answer(t, r[0])]; no = [r for r in rows if not answer(t, r[0])]
            if len(yes) >= min_leaf and len(no) >= min_leaf and gini_n(yes, classes) + gini_n(no, classes) < low:
                best, low = t, gini_n(yes, classes) + gini_n(no, classes)
    if best is None:
        nodes[index] = {"counts": {c: n for c in classes if (n := sum(1 for _, a in rows if a == c))}}
        return index
    y = grow([r for r in rows if answer(best, r[0])], features, classes, depth - 1, min_leaf, nodes, g)
    n = grow([r for r in rows if not answer(best, r[0])], features, classes, depth - 1, min_leaf, nodes, g)
    nodes[index] = {**best, "yes": y, "no": n}
    return index

def vote(nodes, classes, situation):  # a tree's likeliest answer, "" when its walk stops
    i = 0
    while "counts" not in nodes[i]:
        a = answer(nodes[i], situation)
        if a is None: return ""
        i = nodes[i]["yes"] if a else nodes[i]["no"]
    counts, best = nodes[i]["counts"], ""
    for c in classes:
        if counts.get(c, 0) > counts.get(best, 0): best = c
    return best

def asked(model, situation):
    votes = [vote(nodes, model["classes"], situation) for nodes in model["trees"]]
    tally = {c: votes.count(c) for c in model["classes"] if votes.count(c)}
    best = ""
    for c in model["classes"]:
        if tally.get(c, 0) > tally.get(best, 0): best = c
    return {"situation": situation, "votes": votes, "tally": tally, "likeliest": best}

def fitted(name, description, rows, features, classes, trees, max_depth, min_leaf, seed, questions):
    g, table, grown = Xorshift(seed), [(dict(zip(features, r[:-1])), r[-1]) for r in rows], []
    for _ in range(trees):
        sample = [table[g.index(len(table))] for _ in table]
        nodes = []; grow(sample, features, classes, max_depth, min_leaf, nodes, g); grown.append(nodes)
    model = {"kind": "forest", "features": features, "classes": classes, "trees": grown}
    return name, dict(description=description, rows=rows, trees=trees, max_depth=max_depth, min_leaf=min_leaf,
                      seed=seed, model=model, cases=[asked(model, s) for s in questions])

rows = [["close", 0, "throw"], ["close", 1, "throw"], ["close", 5, "low"], ["close", 6, "low"],
        ["near", 0, "low"], ["near", 4, "low"], ["far", 0, "high"], ["far", 3, "high"]]
vectors = dict([
 fitted("three-trees", "The tree vectors' eight rows, three trees, depth 2, seed 7. Two features, so each node may look at one "
        "of them (the square root of two, rounded down), drawn at random, and each tree sees its own bootstrap: eight rows "
        "drawn with replacement. So the three trees differ from each other and from the single tree the same rows fit. "
        "Asked: a row it was fitted on and one it never saw, where the trees disagree; a number where a word is asked -- "
        "every root here tests health, and the trees that reach a distance test abstain there; and a situation where "
        "all three agree.",
        rows, ["distance", "health"], ["high", "low", "throw"], 3, 2, 1, 7,
        [{"distance": "close", "health": 1}, {"distance": "near", "health": 3.5}, {"distance": 7, "health": 0},
         {"distance": "far", "health": 5}]),
 fitted("a-tied-vote", "Four trees, depth 1, seed 1: an even number of voters can split two and two, and then the first "
        "answer in classes wins, as a tie between leaf counts does in one tree. Twice here the first vote cast is throw "
        "and the tie goes to the answer before it in classes -- low, then high -- not to whichever tree voted first.",
        rows, ["distance", "health"], ["high", "low", "throw"], 4, 1, 1, 1,
        [{"distance": "close", "health": 0}, {"distance": "near", "health": 6}, {"distance": "far", "health": 2},
         {"distance": "close", "health": 5}]),
])
for name, v in vectors.items():
    open(f"{sys.argv[1]}/{name}.json", "w").write(json.dumps(v, indent=1) + "\n")
    print(name, [len(t) for t in v["model"]["trees"]], "nodes", [(c["votes"], c["likeliest"]) for c in v["cases"]])
