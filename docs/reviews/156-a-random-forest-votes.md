# Review: wave/156-a-random-forest-votes

T114 adds a random forest. Python fits it (`gameaikit.training.forest`):
each tree is CART on a bootstrap sample, with a random subset of features
at each node, all drawn from one seeded `Xorshift`. The game asks every
tree for its vote (`ai_learning`'s `LearnedForest`). `ModelFile` reads
`kind: "forest"` in both languages, with a new refusal, M16. The forest
has its own vector family, `spec/vectors/forest/`. The fighting game gains
three "forest:" modes whose votes and tally are shown on the panel, and
invariant 6 gains two rules, N18 and N19.

A fresh context reviewed PR #113 at head f37878a, stacked on #108.
**Verdict: approve once findings 1 and 2, both about what the docs claim,
are fixed; five nits.**

## What was reviewed

- The PR title and body, and the task file.
- `python/gameaikit/training/forest.py`, the forest half of `model_file.py`,
  `godot/addons/ai_learning/learned_forest.gd` and `model_file.gd`: the
  fit, the vote and the refusals, side by side.
- `spec/vectors/forest/` (derive.py, the README, the runner) and the new
  cases in `spec/vectors/model_file/refusals.json`.
- `python/gameaikit/cloning/opponent_forest.py`, its report, and the
  published `opponent_forest.json`.
- `godot/game/fighting/fight_forest_opponent.gd`, the hooks added to
  `FightTreeOpponent`, the panel, the overlay and the locale rows.
- `scripts/check_no_training.py`: N18 and N19 and their planted cases.
- `docs/concepts/learning.md`, and the `ai_learning` technique page and
  the glossary in both languages.

## Findings

1. **Should.** `learning.md`'s "It does not find what is not there", and
   the PR body, say every forest lands within a row or two of the floor
   and the n-gram beats them all by eleven points. That holds only for
   seed 1. Over the five seeds, one bootstrapped tree at depth 3 reaches
   26.3%, five points over the floor, and against that the n-gram leads
   by 6.0 points, not eleven.
2. **Should.** The same section does not say what the forest's steadiness
   looks like. The published 25-tree forest answers "step in" on 129 of
   the 133 held-out decisions, and 100 trees answer it on all 133 on every
   seed. Without that, a tally that barely moves in the demo reads like a
   bug.
3. **Nit.** The case descriptions in `derive.py` for `three-trees` are
   wrong. Case 4 is where all three trees agree, while cases 1 and 2 are
   where they disagree. Every root tests health, and the trees abstain at
   the distance node.
4. **Nit.** The docstring of `_self_test_the_opponent_forest` says "a moved
   test"; the plant changes a count.
5. **Nit.** The technique page's "When not to use it" still lists only
   "one weight per feature or one tree" as what the classes hold.
6. **Nit.** The doc comment of `has_read()` should say it is true even
   when every tree abstained.
7. **Nit, optional.** Nothing checks `shares_of` on a split vote.

## What was done about them

1. The section now says "on seed 1" and that, over five seeds, forests of
   5 or more trees never pass 21.8%. It adds that a lucky bootstrapped
   tree reaches 26.3%, still six points under the n-gram, and that a draw
   moving a single tree so far is itself the variance lesson. The PR body
   has the same correction.
2. Stated in the section: 129 of 133 for the published forest, and 133 of
   133 for 100 trees on seeds 1 to 5, measured again before writing it.
   The page says a steady tally here means a forest close to the floor's
   constant guess. The figure is mirrored in both technique pages.
3. The description is reworded and the vectors regenerated with
   `derive.py`; only the description changed.
4. Changed to "a changed count in its second tree".
5. Both pages now add "or trees voting" ("nem árvores votando").
   `translation_of` is refreshed.
6. Reworded as asked.
7. `learned_forest_test.gd` gains a test of `shares_of` on a split vote:
   1 to 3 gives 0.25 and 0.75, and an answer nobody voted for is at zero.
