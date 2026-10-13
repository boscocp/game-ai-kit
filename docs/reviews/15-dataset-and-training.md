# Review: wave/15-dataset-and-training

Two fresh contexts, one per half — the simulated dataset, and the fitting with
its evaluation. Neither wrote the code. Both were asked to mutate rather than
read, and between them they found that **the two places this wave is actually
about were the two places nothing tested**: where a feature is read off a
board, and whether a leak check looks at both models.

## What was reviewed

The three commits that built T5: `python/gameaikit/dataset/` and
`python/gameaikit/training/`, their three test files, the `test-models` and
`train` targets, and the acceptance block in `tasks/T5-dataset-and-training.md`.

## Findings

### Two docstrings that were measurably false

**The capture rows are not censored the way the file said.** It claimed the
missing games were the slowest, unfinished at the turn limit. Over 2000 games:
1392 captures, 608 wipe-outs, **zero** games reaching the limit, and the
longest capture took 10 turns of a permitted 40. The censoring is by wipe-out,
which is a worse bias than the documented one — a wipe-out is likelier when the
sides are uneven, and `own_units` and `enemy_units` are the features that
measure being uneven.

**Splitting the holdout by game does not make it unseen.** The four features
are small integers, so 2937 rows cover only 976 distinct vectors and **83% of
held-back rows have an exact twin among the rows trained on**. The split does
what it was built for — no shared board, no shared dice — but the sentence
claiming the model is scored on situations it has not seen was too strong.

### The dataset's feature extraction was pinned by nothing

Eight mutations changed the data and left the whole suite green: the sign of
`numeric_advantage` flipped, terrain read from the attacker's cell, the
reinforcement measured from the defender, the health difference reversed, the
capture row taken from the losing side, the loser wounded instead of killed
(which doubled the dataset with near-copies — the exact failure the rule exists
to prevent), the hold counter never reset, and the defender swinging first.

No test had ever built a board and looked at the row it produced. Every test
about fighting called `combat.resolve` with hand-written arguments, so the
whole path from board to dataset was unexamined.

### A leak check that only looked at half the kit

`--assert-no-leak`'s "suspiciously perfect" rule was gated on the model being
logistic. Planting `turns_taken` into the capture features produced a model
wrong by **0.0000 turns**, and both `--assert-beats-majority-baseline` and
`--assert-no-leak` returned nothing at all. The check written to catch a leak
passed a leak, on the model it had not been written for.

### A number that was about the probe rather than the pipeline

The contaminated-split measurement published as 0.8808 does not reproduce: the
pipeline gives **0.8794**. The original was measured with a 500-step fit while
the pipeline fits 2000. The conclusion it supports is unchanged — the control
passes a contaminated split either way — but the number was wrong in a
docstring and in the task file.

### Rules that could not fail

* `training_games` and `holdout_games` defaulted to the empty set, so E4 — *was
  this scored on a game it was trained on* — passed without looking at anything
  for every `Fitted` built without them, including the one the tests build;
* W3 and W5 read only the `weights` column while the report publishes two, the
  second being the one a person reads to decide what the model learned;
* E3, the clock assertion, had **no planted case anywhere**: disabling it left
  the unit suite and all five acceptance commands green;
* four scoring rules — the standardisation, the threshold in `_accuracy`, the
  `max` in `_majority_share`, and the negated errors the capture model is
  scored with — were caught only by `make test-models`, which takes twenty
  seconds and reports "the model got worse" rather than which line was wrong.

### Smaller, and still true

A guard in the turn loop that fired 0 times in 500 games. A `TURN_LIMIT` that
has never been reached. The gradient claim, which holds exactly for log loss
and up to a factor of two for squared error, in the one file written to be
rederived by its reader. `numeric_advantage` positive on 8.4% of rows, so its
weight is almost entirely an estimate about being *out*numbered. A sentinel for
"no friends left" carried on a fifth of the rows, out beyond every real
distance — a category wearing a number. Three stale counts.

## What was done about them

Every finding above is fixed, in two commits, each with the mutation that would
have caught it.

The feature-building functions are public and named, and **thirteen** dataset
mutations now run red where eight ran green. Three of the tests written for
that were themselves too weak to see their own mutation — a friend parked eight
cells away when the radius was two, a rough cell where paying one per cell
stopped in the same place, and a rigged game that ended in a wipe-out before
anybody held anything — and each had to be tightened until it failed.

The leak check has a rule in each model's own units. E3 and the four scoring
rules have planted cases, the vacuous defaults are gone, and both published
weight columns are checked. Nine training-half mutations now run red.

The twin finding became a published number rather than an argument: the report
carries what a lookup table of the training rows scores on the same holdout —
**0.8177 against the model's 0.8780 and the majority class's 0.6900**. The
majority baseline flatters this model by about fifteen points. Both models
still beat memorisation, which is the result worth having, and a model with
capacity (T18) will have to be read against the table instead.

## What was not done, and why

**One finding does not reproduce.** The training reviewer reported that
`make test-python` is red on a clean checkout, with `collect(120, 4242)`
returning 67 combats. On this tree it returns **248**, the suite is green at 134
tests, and 248 is the same baseline that reviewer's own mutation table quotes
throughout. It was reported back rather than fixed, with an offer to reopen it
on a reproduction.

**The line-length nit is left alone.** Nothing in this repository enforces a
width: the readability gate reads `.gd` files and checks function length,
nesting and types, not columns. The wave-14 Python files break 88 columns on 14
lines where this wave's break it on 13, and wrapping them mechanically produced
breaks like `[False,\n True])` that read worse than the long line did. That is
a question for the owner — either a width becomes a rule with a gate, or it
stops being raised in review — and not something to impose from inside a wave.

## What is still open

**The manual check has not been done by a person.** "Read the weight dump and
decide whether you could explain to someone, from those numbers alone, what the
model learned about this game" is not a question its author can answer.

**The sentinel stays, documented rather than fixed.** Capping it at the largest
real distance scores 0.885 against 0.878 — five rows in seven hundred, not
enough to choose on. Every principled alternative is arbitrary in its own way,
so the measurement is written down beside the feature and T18 inherits the
decision.

**A trap worth adopting, from the dataset reviewer's method.** It ran its
mutants in an isolated clone with a per-run bytecode cache, because mutating a
file in place can alias a `.pyc` written in the same second and **fake a
green**. Every mutation sweep in this repository is exposed to that, including
the ones in this record, which were re-run with `PYTHONDONTWRITEBYTECODE`.
It belongs in `CLAUDE.md`'s list of traps, and that is the owner's file to
change.
