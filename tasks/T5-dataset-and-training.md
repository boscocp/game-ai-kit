# T5 — The dataset, and training in plain Python

Size: L · Prereqs: T2, T3 · Files: `python/gameaikit/dataset/`, `python/gameaikit/training/`

## Goal

Simulate games with a fixed policy, extract one row per combat, and fit a
logistic regression that predicts whether the attacker wins. Then fit a linear
regression that predicts how many turns a node takes to capture.

Standard library only — no numpy, no sklearn. Gradient descent written out is
the lesson here; `.fit()` hides exactly the part worth seeing. It also keeps
this task on tier 1, where someone with no GPU and no `pip` can still run it.

## Steps

1. A simulator that plays the fixed policy against itself and logs each combat:
   health difference, numeric advantage, terrain, distance to the nearest
   reinforcement, and whether the attacker won.
2. A train/holdout split with a fixed seed, so a result is reproducible.
3. Logistic regression by gradient descent, and linear regression likewise.
4. Emit `weights.json` **and** a readable text dump — the weights are the
   explanation, and a reader should be able to see that numeric advantage
   outweighs terrain, or that it does not.

## Acceptance

```bash
make test-python
python3 -m gameaikit.training.report --check
```

Three properties, because an accuracy number alone proves very little:

```bash
python3 -m gameaikit.training.evaluate --assert-beats-majority-baseline
python3 -m gameaikit.training.evaluate --shuffled-labels --assert-no-better-than-baseline
python3 -m gameaikit.training.evaluate --assert-runs-under-seconds 30
```

The second is the control: a model trained on shuffled labels must collapse to
the baseline. Without it, an accuracy above chance proves nothing, because a
leak in the features produces the same number.

## Manual check

Read the weight dump. Decide whether you could explain to someone, from those
numbers alone, what the model learned about this game.
