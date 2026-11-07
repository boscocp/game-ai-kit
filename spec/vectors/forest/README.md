# Conformance vectors: the random forest

<!-- doc-meta
half_life: structure
verified_on: 2026-11-07
tier: 1
source: https://github.com/boscocp/game-ai-kit
invalidated_if: the bootstrap, the feature subset's size or draw order, the vote or its tie rule, or the forest's file format changes
teaches: none
-->

> Many trees, two languages: Python fits them, the game asks each for its
> vote, and these files say both counted the same votes.

`gameaikit.training.forest` (Python) fits a forest and asks it about
held-out rows; `ai_learning`'s `LearnedForest` (GDScript) asks the
published one in the game. Each vector holds:

- **the fit** -- `rows`, `trees`, `max_depth`, `min_leaf` and `seed` in,
  `model` out. Only Python fits (invariant 6), so only `make test-python`
  checks this half;
- **the vote** -- each case's `situation`, every tree's `votes` in tree
  order ("" for a tree that abstains), the `tally` and the `likeliest`
  answer. Both languages check it: `make test-forest-vectors` in the game,
  `make test-python` in Python.

The rules both follow, on top of the tree's (`spec/vectors/tree/README.md`):

- one `Xorshift` (T109), seeded once, draws everything, in this order: for
  each tree, its bootstrap -- as many draws as there are rows, each
  `index(rows)` -- then, as each node is grown (the node, then its `yes`
  subtree, then its `no` subtree), that node's features;
- a node draws the square root of the number of features, rounded down and
  at least one, without replacement: `index` of what is left in the pool,
  each drawn feature taken out of it. The drawn features are then put back
  in `features` order, so a tie between two tests still goes to the first
  feature; a node at `max_depth` draws nothing;
- when none of the drawn features offers a test that makes the rows purer,
  the node is a leaf. It does not draw again;
- each tree votes its leaf's likeliest answer, or abstains when its walk
  stops at a value it cannot read; the forest's answer is the one with the
  most votes, and of equal tallies the first in `classes` -- not the one
  the first tree voted for. When every tree abstains, the answer is "".

The file format: `kind` "forest", `features` and `classes`, which every
tree shares, and `trees`, a list holding each tree's `nodes` as a tree's
are published.

## Where the numbers came from

From neither implementation: `derive.py`, which imports nothing from this
repository and carries its own xorshift, wrote them:

    python3 spec/vectors/forest/derive.py spec/vectors/forest
