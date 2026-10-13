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
PYTHONPATH=python python3 -m gameaikit.training.report --check
```

Four properties, because an accuracy number alone proves very little:

```bash
PYTHONPATH=python python3 -m gameaikit.training.evaluate --assert-beats-majority-baseline
PYTHONPATH=python python3 -m gameaikit.training.evaluate --shuffled-labels --assert-no-better-than-baseline
PYTHONPATH=python python3 -m gameaikit.training.evaluate --assert-no-leak
PYTHONPATH=python python3 -m gameaikit.training.evaluate --assert-runs-under-seconds 30
```

All five are `make test-models`, which is what `make check` runs. The
`PYTHONPATH` is there so the commands work from the repository root rather than
only from `python/` — a criterion that has to be run from a particular
directory to pass is a criterion somebody will run from the wrong one.

**The fourth command exists because the second does not do what this file said
it did.** The claim was that the shuffled-label control catches a leak in the
features. It does not, and both halves were planted and measured in wave 15:

- the label itself appended to every feature row — the honest run scores
  **1.0000** and the control still lands exactly on the baseline, so it passes;
- the holdout rows left in the training set as well — the honest run scores
  0.8794 against an uncontaminated 0.8780, and the control passes again.

Shuffling the training labels destroys the leaked relationship along with every
honest one, so the model collapses to the base rate whatever was wrong with the
data. The control is still worth running — it tests that the score is computed
against labels the fitting never saw — but the leaks themselves need the
structural checks in `--assert-no-leak`, which ask the two questions directly:
is any game on both sides of the split, and is the score suspiciously perfect.

The second is the control: a model trained on shuffled labels must collapse to
the baseline. It checks the measuring apparatus rather than the data — see the
note under the commands, which is there because this paragraph used to claim
more than the control delivers.

## Manual check

Read the weight dump. Decide whether you could explain to someone, from those
numbers alone, what the model learned about this game.
