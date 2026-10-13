# Review: fix/16-numbers-the-report-did-not-measure

A third review of wave 15, which arrived **after** wave 15 had merged. Its
findings were against `main`, so they are fixed here on their own branch rather
than folded into a wave that had already landed.

Worth recording about the review itself: it withdrew one of its own findings
after checking it in a detached worktree at the exact commit it had measured,
and said plainly that it had no account of how it got the original number. A
reviewer that retracts with evidence is worth more than one that is never
wrong, and the retraction is the reason the remaining four were easy to trust.

## What was reviewed

`python/gameaikit/training/` and `python/gameaikit/dataset/rows.py` as they
landed in wave 15, against the numbers they print.

## Findings

**The lookup table scores 0.8177 and the docstring said 0.848.** Both numbers
are real and they measure different things: 0.848 is what voting a twin's label
scores *over the twinned rows alone*, and 0.8177 is what it scores *over the
whole holdout*, with the rows that have no twin answered by the commoner
outcome. The pipeline prints the second; two docstrings quoted the first, and
one of them went on to conclude that the majority baseline flatters the model
by "about fifteen points" when the figure is 12.8. The number came from the
previous review's measurement and was copied without re-deriving it from the
code that would publish it.

**W4 lost its infinity check while it was being widened.** The rewrite that
made W3/W5 cover both published weight columns left the bias checked for `nan`
only, so a published bias of `inf` returned no finding at all -- and
`json.dump` writes `Infinity` quite happily for the game to load. A regression
introduced by a fix, in a rule that **had no planted case**: removing the
infinity branch left all 137 tests green, which is how it was possible to drop
it without noticing.

**The report printed measured constants inside generated output.**
`report.dump(run(games=60))` claimed "83% of them" and "976 distinct
situations" beside the line "Trained on 60 simulated games". Those were prose
in the caveat rather than numbers from the run.

**Two copies of the half-way threshold**, in the file that defines what the
scores mean: `_accuracy` took a model and `_share_right` took predictions, and
each carried its own `>= 0.5`. The same split existed for the mean error.

**One finding was already fixed**, and that reviewer had read a working tree
mid-edit: the stale counts in the Makefile and the task file were corrected
before wave 15 merged.

## What was done about them

Both twin numbers are written out beside each other, labelled by what they
measure, in both places that quote them. The infinity check is one function
used by every path that validates a published number, and it has a planted case
for each half -- deleting either is red.

The caveat's numbers are carried on the result and come from the run that
prints them; the censoring figures stay constant and now say what they are, a
property of the simulator measured over 2000 games rather than of any one run.
The scoring goes through one path: the model, the lookup table and the constant
guess all become predictions first, and one function holds the threshold.

Measured while fixing it, and now a test: **the twin share is saturation, not a
defect.** 60 games give 0%, 200 give 25.5%, 600 give 65.9%, 1500 give 83.0%.
Four small integers have only so many combinations and more games keep landing
on the same ones.

## A hazard in how these reviews are run

The reviewer's mutation harness ran `git checkout --` on five files **while
this session was editing them uncommitted**. It reported the tree clean after
each run and the edits reappearing afterwards, and nothing was in fact lost --
`make check` is green and the committed history is coherent -- but it could
have been, and neither side could prove it after the fact.

Reviews in this project run against the same working tree as the work. That is
cheap and it is why a reviewer can measure anything it likes, but a reviewer
that *writes* -- even to restore what it changed -- can destroy work it cannot
see. The rule that follows is for the reviewer's brief rather than for the
code: **mutate in a detached worktree or a clone, never in the tree somebody
is working in.** The same reviewer did exactly that when it went back to check
its withdrawn finding, which is the pattern to copy.
