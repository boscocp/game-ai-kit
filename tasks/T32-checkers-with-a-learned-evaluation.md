# T32 — Checkers with a learned evaluation

Size: M · Prereqs: T27, T5 · Files: `python/gameaikit/`, `godot/game/checkers/`, `spec/`

## Goal

In 1959 Arthur Samuel wrote a checkers program that searched with minimax
and **learned the weights of its evaluation**: how much a king is worth
against a man, how much the centre matters. That is where the phrase
"machine learning" comes from. T27 builds the search with a hand-written
evaluation. This task replaces the hand with data, and measures what that
buys.

## Steps

1. Positions from games played by the T27 AI against itself, labelled with
   the result, in Python, standard library only (tier 1).
2. A linear evaluation over the same features T27 hand-weighted, fitted in
   Python, with the trainer from T5. Published as data, read in Godot, and
   never trained there (invariant 6).
3. **A match**: hand-written against learned, at the same depth, over many
   seeded games, with the score published beside the weights. The
   comparison is the task, as in T18.
4. In the game, a toggle between the two evaluations. The decision overlay
   shows each feature's contribution to a position's score, so a person can
   see *why* the learned one prefers a move.

## Acceptance

```bash
make test-python
make test-godot
make lint-no-training
make test-vectors
```

The suite must include:
- the Godot and Python evaluations agree on a shared vector of positions;
- the published match result is reproduced from its seed.

## Manual check

Toggle between the two evaluations on the same position. A person should be
able to name the feature the learned weights value differently, and say
whether that makes it play better.
