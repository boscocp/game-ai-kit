# T114 — A random forest votes on the same question

Size: S · Prereqs: T113 · Files: `godot/addons/ai_learning/`, `godot/test/ai_learning/`, `python/gameaikit/training/`, `python/tests/`, `spec/vectors/learning/`, `godot/game/fighting/`, `godot/test/fighting/`, `docs/techniques/`, `docs/concepts/learning.md`, `Makefile`

## Goal

T113's single tree overfits: it learns the recordings, not the opponent.
A random forest is the textbook answer, and the lesson is variance: many
trees, each fitted on a bootstrap sample with a random subset of
features at each split, vote. The owner asked for it on 2026-11-04. It
answers the same question in the same game, so the reader can compare
one tree against many, on the same data.

## Decisions written down first

_The decisions below are this session's proposal, written on 2026-11-04; the owner has not ratified them. The wave that takes the task confirms them, or brings them back to the owner._

- **Fitted in Python, read in GDScript** (invariant 6), seeded, using
  T109's `Xorshift` on the Python side so a forest is reproducible. The
  model file holds the trees, and `LearnedForest` reads them.
- **The measurement is the lesson:** held-out accuracy of one tree against
  forests of 5, 25 and 100 trees, on recordings the fit never saw, in
  a table on the page.
- **Shown:** each tree's vote and the tally (invariant 13).
- **The cost is stated:** one walk per tree, per decision.

## Acceptance

```bash
make test-learning-vectors
make test-python
make test-godot-some SUITES="test/ai_learning test/fighting"
python3 scripts/check_no_training.py
make test-demo-overlays
```

## Manual check

In the fighting demo, switch between tree and forest: does the forest's
tally move less from one exchange to the next than the tree's prediction?
