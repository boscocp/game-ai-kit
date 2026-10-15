"""Write the cloning vectors in this directory.

Imports nothing from the repository, so the numbers come from neither
implementation the vectors hold:

    python3 spec/vectors/cloning/derive.py spec/vectors/cloning
"""
import json, math, sys
def softmax(classes, columns, weights, bias, situation):
    present = [columns.index(f"{k}={v}") for k, v in situation.items() if f"{k}={v}" in columns]
    scores = [bias[a] + sum(weights[a][i] for i in present) for a in range(len(classes))]
    exps = [math.exp(s - max(scores)) for s in scores]
    p = {c: e / sum(exps) for c, e in zip(classes, exps)}
    best = classes[0]
    for c in classes:
        if p[c] > p[best]: best = c
    return {"situation": situation, "probabilities": p, "likeliest": best}
def lookup(features, cases, situation):
    words = [situation.get(f, "") for f in features]
    key = " | ".join(words)
    closest, keys = -1, []
    for k in cases:
        apart = sum(a != b for a, b in zip(words, k.split(" | ")))
        if closest == -1 or apart < closest: closest, keys = apart, [k]
        elif apart == closest: keys.append(k)
    pooled = {}
    for k in keys:
        for a, n in cases[k].items(): pooled[a] = pooled.get(a, 0) + n
    return {"situation": situation, "exact": cases.get(key, {}), "distance": closest, "nearest": pooled}
model = dict(classes=["high", "low", "throw"], columns=["distance=close", "distance=far", "last=high", "last=low"],
             weights=[[0.0, 1.0, -0.5, 0.5], [0.5, 0.0, 1.0, -1.0], [2.0, -2.0, 0.0, 0.0]], bias=[0.25, 0.0, -0.25])
cases = {"close | high": {"throw": 3, "low": 1}, "close | low": {"high": 2}, "far | high": {"low": 2, "high": 1}}
vectors = {
 "softmax-by-hand": dict(description="Three answers, four columns. A situation adds its columns' weights to each answer's bias; a word with no column adds nothing; with no word at all only the biases are left.",
   model=model, cases=[softmax(**model, situation=s) for s in [
     {"distance": "close", "last": "high"}, {"distance": "far", "last": "low"},
     {"distance": "near", "last": "high"}, {}]]),
 "ghost-by-hand": dict(description="Three situations met. Exact lookup finds one or nothing; nearest pools every case at the fewest differing features -- 'far | low' is one word from two cases, so their counts add.",
   features=["distance", "last"], table=cases, cases=[lookup(["distance", "last"], cases, s) for s in [
     {"distance": "close", "last": "high"}, {"distance": "far", "last": "low"}, {"distance": "near", "last": "jump"}]]),
}
for name, v in vectors.items():
    open(f"{sys.argv[1]}/{name}.json", "w").write(json.dumps(v, indent=1) + "\n")
    print(name, [c.get("likeliest", c.get("distance")) for c in v["cases"]])
