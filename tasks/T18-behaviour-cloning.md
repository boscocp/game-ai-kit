# T18 — Behaviour cloning, and what a learned model buys

Size: L · Prereqs: T17, T5 · Files: `python/gameaikit/cloning/`, `godot/addons/ai_learning/`

## Goal

Train a small model on recorded human play, ship the weights, infer in
GDScript — and then answer the question the kit has been setting up: **what did
that buy over the frequency table in T17?**

The honest answer may be "not much, here", and if the measurements say so the
task says so. A kit that claims machine learning always wins is a kit that
teaches people to reach for it when they should not.

## Steps

1. Record human matches to a dataset, reusing T5's format. The replay
   determinism from T16 is what makes a recorded match reusable.
2. Train in Python, standard library only — no pip, no numpy, no install step.
   A small MLP or multinomial logistic regression over the same context the
   n-gram sees, so the comparison is fair.
3. Emit weights as JSON, committed. GDScript loads and infers: invariant 6,
   no training at game time.
4. Inference must not block a frame. Measure it, in the demo, on the slowest
   machine available, and write the number down.
5. **The comparison**, which is the task: the same opponent, played by the
   n-gram and by the cloned model, over the same recorded sessions. Accuracy,
   win rate, size, training cost, and whether a person can tell which is which.

## Acceptance

```bash
make test-godot
make test-python
make test-vectors
```

```bash
python3 python/gameaikit/cloning/compare.py --report
```

That command prints the comparison table and exits non-zero if the cloned model
has not been evaluated on a held-out set. Training accuracy is not a result,
and a comparison with no held-out split is a sales pitch.

```bash
test -f godot/addons/ai_learning/weights.json
./scripts/godot --headless --path godot -s res://test/inference_budget.gd
```

The budget script asserts inference stays under a stated millisecond count per
decision.

## Manual check

Play against both. If you cannot tell them apart, that is a result and it goes
in the README beside the technique, not in a footnote.
