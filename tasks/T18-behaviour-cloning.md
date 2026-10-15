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

1. Record human matches to a dataset, one row per decision: what the player
   saw, and what they did. T5's rows, one per combat, cannot be cloned from.
   T25 records the tactical board in the same shape of row; the data differs,
   and only the method is shared, which is how T25's Cloned team uses it. The replay determinism from T16 is what makes
   a recorded match reusable.
2. Train in Python, standard library only — no pip, no numpy, no install step.
   A small MLP or multinomial logistic regression over the same context the
   n-gram sees, so the comparison is fair.
3. Emit weights as JSON, committed. GDScript loads and infers: invariant 6,
   no training at game time.
4. Inference must not block a frame. Measure it, in the demo, on the slowest
   machine available, and write the number down.
5. **The comparison**, which is the task: the same opponent, played by the
   n-gram, by a **ghost** -- the recorded situation closest to this one, and
   what the player did there, as Killer Instinct's Shadows do it (the ghost
   papers in T36's survey look the situation up exactly, in ranges, which is
   the same thing at its simplest) -- and by the cloned model,
   over the same recorded sessions. Accuracy,
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
test -f godot/addons/ai_learning/clone_weights.json
make test-clone-rows
python3 scripts/check_no_training.py
./scripts/godot --headless --path godot -s res://test/inference_budget.gd
```

The weights ship as `clone_weights.json`, not `weights.json`: that file is
T6's combat model and existed before this task, so `test -f` on it passed on
an empty change (the owner's decision, 2026-10-15). `make test-clone-rows`
holds the committed rows to the recordings; N10 in `check_no_training.py`
holds the published file to a fresh fit of those rows. The budget script
asserts inference stays under a stated millisecond count per decision, and
first times a planted decision that must exceed it.

The data is the owner's play, recorded with `make record-fights`: nine
fights on 2026-10-15 (owner's decision). The pipeline was built first on
scripted stand-ins, which stay in `data/fights/` as the contrast the concept
page draws.

## Manual check

Play against both. If you cannot tell them apart, that is a result and it goes
in the README beside the technique, not in a footnote.
