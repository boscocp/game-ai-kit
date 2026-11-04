# T113 — A decision tree reads the fighting opponent

Size: M · Prereqs: T112 · Files: `godot/addons/ai_learning/`, `godot/test/ai_learning/`, `python/gameaikit/training/`, `python/tests/`, `spec/vectors/learning/`, `godot/game/fighting/`, `godot/test/fighting/`, `docs/techniques/`, `docs/concepts/learning.md`, `Makefile`

## Goal

The kit learns one shape of model: `LearnedModel`, one weight per feature.
Its header says when not to use it: "a tree, a hidden layer, anything
with structure". Decision trees are absent, and they are among the first
learned models a game programmer meets. They read as rules a person can
follow. The owner asked for them on 2026-11-04.

They fit the fighting game. Reading the opponent is what entrants to the
fighting-game AI competition did with k-NN and decision trees
(`docs/concepts/fighting-game-ai.md`, the 2015 row). ADR 0017's
recordings are the data.

## Decisions written down first

- **Python fits, GDScript reads** (invariant 6). Training runs in
  `gameaikit.training`, CART with Gini impurity, depth and leaf size
  capped. It writes the tree to a model file that `ModelFile` reads. A
  `LearnedTree` beside `LearnedModel` walks it: a comparison per level,
  so the cost is the depth.
- **The question:** from the situation (distance, both energies, the
  opponent's last two moves), what will the opponent do next? The
  fighting opponent uses the answer to choose its own reply. It does not
  replace the n-gram (T17). It is a second reader, and the page compares
  the two.
- **Shown, not only used** (invariant 13): the path taken through the
  tree, each test and which way it went, and the leaf's counts.
- **Vectors in both languages:** a hand-worked tree in the README, and
  `derive.py` with no import from the repository.
- **When not to use it:** a decision tree alone overfits; the page shows
  that, and T114 is the answer.

## Acceptance

```bash
make test-learning-vectors
make test-python
make test-godot-some SUITES="test/ai_learning test/fighting"
python3 scripts/check_no_training.py
python3 scripts/check_readability.py
make test-demo-overlays
```

## Manual check

In `make demo-fighting`, with the tree reader on: answer the same
situation the same way three times. Does the path on screen end at the
leaf that predicts it, and does the reply change?
