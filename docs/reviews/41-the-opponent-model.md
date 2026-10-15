# Review: wave/41-the-opponent-model

One fresh context reviewed it, in its own git worktree, at 9a270b6.

What it read: CLAUDE.md, T17, ADR 0016, the survey's n-gram section and what
the kit takes from it, the wave 39 record, the vectors and their README, the
diff, and the fighting files around it.

What it ran: `make check` (755 cases), `make test-python` (268), the
vectors, the properties script, `check_no_training.py --self-test`; its own
exact-fraction n-gram against all four vectors (15 cases, agreeing to
1e-15); the properties under other habits, levels, orders and decays; a
scripted habitual player against the fixed and the learning opponent at
each level, 40 fights a cell; a probe of the panel over 2,438 frames; a
planted table saved past N9; 27 mutations.

## What was reviewed

Commit 9a270b6: `ai_opponent` and its `NGramPredictor`, `gameaikit.ngram`,
the four vectors and their README, `fight_model_opponent.gd`, the changes to
`fight_opponent.gd`, `fighting.gd` and `fighting_panel.gd`, the vector
runner and validator, the four new suites, `opponent_properties.gd`, N9 in
`check_no_training.py`, ADR 0016, CLAUDE.md, the Makefile and T17.

## Checked and true

- The learner watches only the copy `FightDelay` hands it; the panel reads
  only what it learnt from that. A step read off `held_before` is on screen:
  the walk is drawn from the same field.
- In the game a restart, a swap and a mode change each seat a new learner.
  The table depends only on player one's drawn states, so it can be rebuilt
  from the log given the seat's frame and reaction.
- GDScript and Python do the same arithmetic in the same order; the vectors
  agree with an independent exact-fraction run.
- The properties measure what they say, under easy, hard, order 3 and
  other two-action habits too; the never-forgets plant fails for the stated
  reason.
- At hard the learner beats a habitual player more often than the fixed
  opponent: low, high, throw 10 to 5; throw alone 22 to 14.

## Findings

### Must fix

1. **`LEAN` 8 was unreachable.** At decay 0.8 a row holds at most 5, so the
   surest prediction is 6 in 16 and the lean, normalised against 1, never
   passed 2 -- while the text said "LEAN when certain" and "makes the
   answer the likely draw". A mutation to `LEAN = 2` survived.
2. **"Starts empty every fight" had no test.** A learner keeping the last
   one's table survived every gate.

### Should fix

3. N9 could be dodged by the file that holds the table, writing it under
   another name; `ConfigFile.save` was not in the net at all.
4. The panel paired the current context with the expectation of the last
   decision: 16% of frames read "after low it expects step in" above
   "low -> high".
5. Easy and medium often have no answer among their options: learner:easy
   against a low habit was bit-identical to opponent:easy while the panel
   printed an expectation.
6. "Replays from the input log" was unheld, and the log alone does not say
   when a learner was seated.
7. The vector validator dropped claims: a duplicated `seen`, a fractional
   one (which the two languages read differently), a sequence action not
   in `actions`, unworkable settings.
8. The decay vector's text put its numbers after the second throw; they are
   after the first.
9. The sorting test did not test sorting, and the sort was not stable.

### Notes

10. The order-1 plant fails for a tie, not for its decay.
11. A habit with a repeated action is near chance at order 2; a real low
    held down adds a crouch after it.
12. The predictor shared its caller's action list; prior 0 with one action
    divided by zero; nothing called `problem()`; " > " in an action name
    would collide (not reachable).
13. "Agree to the last place of a double" was never tested.
14. The vector generator was not committed.
15. Stale text: a comment in `fighting.gd`, no README row, STATUS, the
    CLAUDE.md row for invariant 6, the order of N9 in the docstring.
16. A seat reused across a restart forgot its frames but not the learner's
    table.

### The mutations

27, 21 killed. Survived: `LEAN = 2`, rows unsorted, the learner's seed
fixed (cosmetic), take-off not read as a jump (near-equivalent), the answer
to a low made "step out", a restart keeping the table.

## What was done about them

1. The lean is measured against the predictor's `ceiling` -- the surest a
   row can be at its decay -- so it reaches 8. A test holds that a sure
   prediction gains exactly `LEAN` and that each answer then outweighs
   every other option; `LEAN = 2` is now caught.
2. `FightOpponent.new_fight`, which `FightDelay` calls when the fights it
   is handed stop following on; the learner's empties its table. Tested
   through a seat and through the training mode's restart.
3. N9 covers any file written by a script that names `NGramPredictor` or
   `FightModelOpponent`, and `ConfigFile.save` and `ModeFlags.WRITE` joined
   the net; planted cases for both. The text says it is a net.
4. The learner keeps the context it decided after; the panel prints "at
   its last decision, after X it expected Y" and the context now, apart.
5. The choice and the panel say "no answer among its options" when the
   level has none; T17 says which levels that is, with the review's fight
   numbers, which were taken before the rescale and are marked so.
6. A test plays the recorded fight twice through a learner and compares
   the tables; ADR 0016 says what the log does not record.
7. V6 to V9 on both sides, each with a planted vector.
8. The text says after the first; `derive.py`, now committed, rewrote the
   description.
9. The rows sort heaviest first and ties by `actions`; the test has a heavier
   action seen later, and a tie. Rows unsorted is now caught.

Notes: 10 and 11 are in T17's text; 12 -- the list is copied, prior must be
above 0, the learner checks `problem()`; 13 -- the claim is gone; 14 and
15 -- done; 16 is finding 2's fix. Not done: the take-off-as-jump and the
seed mutations, judged equivalent and cosmetic; the answer to a low is now
pinned by a test.
