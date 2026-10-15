"""Write the n-gram vectors in this directory, in exact fractions.

Imports nothing from the repository, so the numbers come from neither
implementation the vectors hold:

    python3 spec/vectors/ngram/derive.py spec/vectors/ngram
"""
import json, sys
from fractions import Fraction as F
def run(order, actions, decay, prior, seq, checkpoints):
    counts, recent, out = {}, [], []
    def probs():
        row = counts.get(" > ".join(recent), {}) if len(recent) == order-1 else {}
        total = prior*len(actions) + sum(row.values())
        return {a: (row.get(a, 0) + prior)/total for a in actions}
    for k in range(len(seq)+1):
        if k in checkpoints:
            p = probs(); best = actions[0]
            for a in actions:
                if p[a] > p[best]: best = a
            out.append({"seen": k, "context": " > ".join(recent), "probabilities": {a: float(v) for a, v in p.items()}, "likeliest": best})
        if k == len(seq): break
        a = seq[k]
        if len(recent) == order-1:
            row = counts.setdefault(" > ".join(recent), {})
            for s in row: row[s] *= decay
            row[a] = row.get(a, 0) + 1
        recent.append(a)
        if len(recent) > order-1: recent.pop(0)
    return out
vectors = {
 "order-two-by-hand": dict(description="Order 2, no decay, Laplace smoothing: small enough to check by hand (the README does). A context never seen predicts every action alike.", order=2, actions=["high","low","throw"], decay=F(1), prior=F(1), sequence=["high","low","high","low","high","throw"], checkpoints=[0,1,4,5,6]),
 "decay-follows-a-change": dict(description="Order 2, decay 1/2: the player answered high with low three times, then with throw twice. With decay the table prefers throw after the first throw; without it, it would still say low, three to one.", order=2, actions=["high","low","throw"], decay=F(1,2), prior=F(1), sequence=["high","low","high","low","high","low","high","throw","high","throw","high"], checkpoints=[2,7,9,11]),
 "order-one": dict(description="Order 1 is a plain frequency count with no context; this one, at prior 1/2, sees a run of jumps.", order=1, actions=["jump","low","throw","guard"], decay=F(9,10), prior=F(1,2), sequence=["jump","jump","low","jump","guard","jump"], checkpoints=[0,3,6]),
 "order-three": dict(description="Order 3: the context is the last two actions, so 'low > high' and 'high > high' are different rows, and each is seen only once or twice in a short fight.", order=3, actions=["high","low","throw"], decay=F(1), prior=F(1), sequence=["low","high","throw","high","high","low","low","high","throw","low","high"], checkpoints=[2,6,11]),
}
for name, v in vectors.items():
    cases = run(v["order"], v["actions"], v["decay"], v["prior"], v["sequence"], set(v["checkpoints"]))
    doc = {"description": v["description"], "order": v["order"], "actions": v["actions"], "decay": float(v["decay"]), "prior": float(v["prior"]), "sequence": v["sequence"], "cases": cases}
    open(f"{sys.argv[1]}/{name}.json", "w").write(json.dumps(doc, indent=1) + "\n")
    print(name, [(c["seen"], c["context"], c["likeliest"]) for c in cases])
