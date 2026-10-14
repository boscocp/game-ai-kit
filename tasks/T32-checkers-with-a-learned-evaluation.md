# T32 — Checkers with a learned evaluation

Size: L · Prereqs: T27, T5 · Files: `python/gameaikit/`, `godot/game/checkers/`, `spec/`, `Makefile`, `scripts/check_no_training.py`

## Goal

Arthur Samuel's checkers program, begun on IBM machines in the early 1950s
and described in his 1959 paper "Some Studies in Machine Learning Using the
Game of Checkers", searched with minimax and **learned the weights of its
evaluation**. He is widely credited with popularising the phrase "machine
learning". T27 builds the search with a hand-written evaluation. This task
replaces the hand with data, and measures what that buys.

**This is after Samuel, not Samuel.** As the paper describes it:
- the piece-advantage term was held fixed while the other coefficients were
  learned;
- the program moved its evaluation towards the values a deeper search
  backed up, an ancestor of temporal-difference learning, rather than
  fitting game results.

This task fits game results, because that is the trainer T5 already has.
The concept page says which is which. Check every claim about the 1959
paper against the paper itself before it goes on a page.

## Steps

1. **The rules and the search in Python too**, standard library only
   (tier 1). Self-play happens where training happens, so checkers needs a
   Python port. A rules vector, a set of positions with their legal moves,
   is read by both languages, so the two cannot drift.
2. **Self-play that is not one game replayed.** Fixed-depth minimax with a
   fixed move order plays the same game every time. Randomise the opening
   moves, by a recorded seed, and record how many distinct games resulted.
   Positions are labelled with the game's result.
3. **A linear evaluation** over the same features T27 hand-weighted, fitted
   in Python with the trainer from T5. Published as data, read in Godot,
   and never trained there (invariant 6). Beside it, a shuffled-labels
   control, as T5 has: weights fitted to scrambled results must play no
   better than chance against the hand-written evaluation.
4. **The gate learns about it.** `check_no_training.py` knows only
   `ai_learning`'s `weights.json`. Extend it to the checkers weights:
   regenerated from their seed, and never written in GDScript. Each new
   rule gets a planted case.
5. **A match**: hand-written against learned, at the same depth, over many
   seeded games, with the score published beside the weights. The
   comparison is the task, as in T18.
6. In the game, a toggle between the two evaluations. The decision overlay
   shows each feature's contribution to a position's score, so a person can
   see *why* the learned one prefers a move.

## Acceptance

```bash
make test-python
make test-godot
make lint-no-training
make lint-selftests
make test-checkers-vectors
make test-vectors
```

`test-checkers-vectors` is a new sub-target, added to `test-vectors`'
prerequisites. That list is fixed, and a family left out of it never runs.

The suite must include:
- the rules vector: both languages produce the same legal moves for every
  position in it;
- the Godot and Python evaluations agree on a shared vector of positions;
- the shuffled-labels control does no better than chance;
- the published match result is reproduced from its seed.

## Manual check

Toggle between the two evaluations on the same position. A person should be
able to name the feature the learned weights value differently, and say
whether that makes it play better.

## Decided on the way (2026-10-14)

- **The paper was read** (the reprint of IBM Journal 3(3), July 1959) and
  both caveats above hold. It also gives kings to men as "three to two",
  T27's 1.5. The concept page quotes it: `docs/concepts/learned-evaluation.md`.
- **Self-play searches one ply.** Measured on 60 openings: at one ply 46
  games were decisive, at two 14, at three 11; the rest were drawn with
  kings circling, and a drawn game has no label. Draws are left out.
- **The match is published at two depths**, one and two plies, because the
  answer differs: even at one, lost 3-19-78 at two.
- **The result is negative, and published as it is.** The fit counts
  advancement against a man and a king as a third of a man, because in
  one-ply games that is what went with winning. The comparison is the task;
  the concept page explains it, and three other ways of making the data
  (draws as half, depth 2, both) lost at two plies too.
- **"No better than chance"** is held as a score of at most 0.6 over 100
  games: 0.5, plus two standard errors.
- **The game builds a new `CheckersGame` to switch weights** rather than
  assigning them: assigning another object's weights is N3's update step.
