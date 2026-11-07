# Conformance vectors: the decision tree

<!-- doc-meta
half_life: structure
verified_on: 2026-11-06
tier: 1
source: https://github.com/boscocp/game-ai-kit
invalidated_if: the impurity, the order candidate tests are tried in, the tie rule, the node format or what stops a walk changes
teaches: none
-->

> One tree, two languages: Python fits it, the game walks it, and these
> files say both got the same answers.

`gameaikit.training.tree` (Python) fits a tree by CART and walks it to
score held-out rows; `ai_learning`'s `LearnedTree` (GDScript) walks the
published one in the game. Each vector holds:

- **the fit** -- `rows`, `max_depth` and `min_leaf` in, `model` out. Only
  Python fits (invariant 6), so only `make test-python` checks this half;
- **the walk** -- each case's `situation`, the `path` of node indices from
  the root, the leaf's `counts` and the `likeliest` answer. Both languages
  check it: `make test-tree-vectors` in the game, `make test-python` in
  Python.

The rules both follow:

- a node is a test -- `feature` with `is` (a word, by equality) or
  `at_most` (a number, by threshold), and the indices of its `yes` and
  `no` children -- or a leaf, whose `counts` are the training rows that
  reached it, by answer;
- the impurity of a set of rows is Gini's times the number of rows,
  n - (sum of each count squared) / n, so a split's is the sum of its two
  sides' and is computed exactly, in fractions;
- the candidate tests are tried feature by feature in `features` order --
  a word feature's words sorted, a number feature's thresholds halfway
  between neighbouring values -- and a test replaces the best so far only
  when it is strictly better: of equal tests, the first wins;
- a node becomes a leaf at `max_depth`, when no test leaves `min_leaf`
  rows on both sides, or when none makes the rows purer;
- the likeliest answer is the leaf's highest count; of equal counts, the
  first in `classes`;
- a walk that meets a test whose feature is missing, or holds the wrong
  kind of value -- a number where a word is asked, or the reverse -- stops
  there: the path ends on that test, the counts are empty and the answer
  is "". It does not guess "no".

## The root of `fit-by-hand`, by hand

Eight rows: `distance` a word, `health` a number, three answers. All eight
together hold high 2, low 4, throw 2: impurity 8 - (4 + 16 + 4) / 8 = 5.

| test | yes side | no side | impurity |
|---|---|---|---|
| distance is close | throw 2, low 2: 4 - 8/4 = 2 | low 2, high 2: 2 | 4 |
| distance is far | high 2: 0 | throw 2, low 4: 6 - 20/6 = 8/3 | **8/3** |
| distance is near | low 2: 0 | throw 2, low 2, high 2: 6 - 12/6 = 4 | 4 |
| health at most 0.5 | throw, low, high: 3 - 3/3 = 2 | throw 1, low 3, high 1: 5 - 11/5 = 2.8 | 4.8 |
| health at most 2 | throw 2, low 1, high 1: 4 - 6/4 = 2.5 | low 3, high 1: 4 - 10/4 = 1.5 | 4 |
| health at most 3.5 | throw 2, low 1, high 2: 5 - 9/5 = 3.2 | low 3: 0 | 3.2 |
| health at most 4.5 | throw 2, low 2, high 2: 4 | low 2: 0 | 4 |
| health at most 5.5 | throw 2, low 3, high 2: 7 - 17/7 = 32/7 | low 1: 0 | 32/7 |

`distance is far` is the lowest, so it is the root. Its yes side is pure,
a leaf; on its no side, the same arithmetic finds `health at most 2.5`
(4/3, against 2 for `distance is close`), and depth 2 stops there.

## Where the numbers came from

From neither implementation: `derive.py`, which imports nothing from this
repository, wrote them:

    python3 spec/vectors/tree/derive.py spec/vectors/tree
