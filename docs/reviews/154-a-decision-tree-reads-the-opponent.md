# Review: wave/154-a-decision-tree-reads-the-opponent

T113 adds a decision tree. Python fits it by CART (`gameaikit.training.tree`)
and the game walks it (`ai_learning`'s `LearnedTree`). `ModelFile` reads
`kind: "tree"` in both languages, with refusals M11 to M15. The tree has a
new vector family, `spec/vectors/tree/`. The fighting game gains a
`FightTreeOpponent` whose path is shown on the panel, and invariant 6 gains
two rules, N16 and N17.

A fresh context reviewed PR #108 at head 46fbe4e. **Verdict: approve once
finding 1 is fixed; two shoulds and four nits.**

## What was reviewed

- The PR title and body, and the task file.
- `python/gameaikit/training/tree.py` and `model_file.py`, and
  `godot/addons/ai_learning/learned_tree.gd` and `model_file.gd`: the fit,
  the walk and the refusals, side by side.
- `spec/vectors/tree/` (derive.py, the README worked by hand, the runner)
  and the new cases in `spec/vectors/model_file/refusals.json`.
- `godot/game/fighting/fight_tree_opponent.gd`, the panel, the overlay, the
  locale rows, and the refactor of `FightModelOpponent`.
- `scripts/check_no_training.py`: N16 and N17 and their planted cases.
- `docs/concepts/learning.md` and the `ai_learning` technique page in both
  languages.

## Findings

1. **Should.** No test pins the `at_most` boundary. Changing `<=` to `<`
   left every check green in GDScript (`learned_tree.gd`) and in Python
   (`tree.py`).
2. **Should.** The tree was scored on the guess from its last decision,
   which can be several actions old. The n-gram was scored on its table at
   the frame each action appears. The panel presented the two scores as a
   head-to-head contest, which they were not.
3. **Nit.** `docs/concepts/learning.md` should say that the published
   depth-3 tree scores 20.3% held-out against a 21.1% floor. The technique
   pages said "a deeper tree scores worse", but held-out accuracy is not
   monotonic in depth, and they did not say that the n-gram beats the tree.
4. **Nit.** The headers of `learned_tree.gd` and `tree.py` pointed at the
   fighting game's report. Someone taking `ai_learning` alone does not have
   that game.
5. **Nit, optional.** The pt-BR panel prints the feature names raw.
6. **Nit.** `_decide` and `_expect` walked the tree three times for one
   decision. A tie between leaf counts on the panel was not ordered by
   `classes`.

## What was done about them

1. `fit-by-hand` gains the case `{"distance": "close", "health": 2.5}`,
   whose expected path is `[0, 2, 3]`. The vectors were regenerated with
   `derive.py`. The mutation `<=` to `<` now fails both `make
   test-tree-vectors` (3 failures) and `tests.test_tree`; both were measured
   and then restored.
2. `FightTreeOpponent` now records, in the same `watch`, whether the
   n-gram's guess at the same decision was right (`ngram_guesses`,
   `ngram_score()`). The panel and the overlay show that score beside
   `tree_score()`. The panel line now reads "the n-gram, asked at the same
   decisions", with its pt-BR row changed to match, and a test holds the
   new score.
3. Done. The concept page states the 20.3% against the 21.1% floor. Both
   technique pages now say that no deeper tree does better on fights it
   never saw and that the n-gram beats them all. `translation_of` was
   refreshed.
4. Both headers now point at `docs/concepts/learning.md#a-decision-tree`.
5. Left as it is. The clone's panel prints the same feature words raw, and
   the code identifiers stay in English, as the pt-BR scope says.
6. `LearnedTree` gains `likeliest_in(counts)` and `shares_of(counts)`, and
   `likeliest` and `probabilities` use them. `_expect` reads the leaf from
   `walked`, so there is one walk per decision. The panel orders leaf
   counts that tie by `classes`.
