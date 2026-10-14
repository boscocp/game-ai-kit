# A learned evaluation: checkers after Samuel, and what fitting results buys

<!-- doc-meta
half_life: concept
verified_on: 2026-10-14
tier: 1
source: book:Arthur L. Samuel, "Some Studies in Machine Learning Using the Game of Checkers", IBM Journal of Research and Development 3(3), July 1959
invalidated_if: gameaikit.checkers changes its features, its self-play, its fit or its match, or checkers_weights.json is regenerated
teaches: learned-evaluation
-->

> A search is only as good as the number it puts on a position it stops at.
> T27 wrote that number by hand. This page is about fitting it to games
> instead, after Arthur Samuel, and about what the fit got wrong. Tier 1:
> the whole pipeline is Python's standard library, in
> [`python/gameaikit/checkers/`](../../python/gameaikit/checkers/), and E in
> `make run` switches white between the two evaluations.

## What Samuel did

Samuel's checkers program, described in his 1959 paper, searched ahead with
minimax and scored the positions where it stopped with a weighted sum of
board measurements: a "scoring polynomial". The paper's abstract opens: "Two
machine-learning procedures have been investigated in some detail using the
game of checkers." One was rote learning, which saved scored positions. The
other, "learning procedure involving generalizations", changed the weights.

Three things about it matter here, each checked against the paper. The copy
read was the reprint of the July 1959 article, and the quotations below
correct its scanning errors and nothing else.

- **One weight was not learned.** The paper is about the sign of the
  piece-advantage term when it says "it must be fixed by the experimenter
  and, in effect, it is one of the instructions to the machine defining its
  task"; elsewhere it adjusts every coefficient "other than the
  piece-advantage term". Kings were worth more than men, "the relative
  weights assigned to them being three to two". That is T27's 1.5, which was
  chosen before anyone looked it up.
- **The target was a deeper search, not the game's result.** The program
  saved the score of each position it played into. At its next move it
  compared that saved score with "the backed-up score for the current
  position. The difference between these scores, defined as delta, is used
  to check the scoring polynomial." Roughly: when delta was positive, the
  terms that had contributed positively gained weight, and the others lost
  it -- through a running correlation, with weights set at powers of two.
  The score of a position was pulled towards what a search from the
  position one move later said. That is an ancestor of temporal-difference
  learning.
- **It chose its terms too.** The running program had 38 terms besides
  piece advantage, kept 16 in the polynomial at a time, and moved a term to
  the reserve once it had correlated worst with delta, usually eight times.

## What this kit does instead

The same search, alpha-beta to a fixed depth, and the same three counts
T27 weighed by hand, each the player's minus the opponent's:

| count | hand | learned | learned, in standard deviations |
|---|---|---|---|
| men | 1 | +0.629 | +1.72 |
| kings | 1.5 | +0.218 | +0.26 |
| advancement (rows advanced by men) | 0.05 | −0.212 | −2.43 |

The learned column comes from **fitting game results**, not a deeper
search:

1. **Self-play.** The hand-written evaluation plays itself 400 times, one ply
   deep. A fixed-depth search with a fixed move order plays the same game
   every time, so each game opens with 8 random moves from a recorded seed
   (1959). That gave 394 distinct games: red won 180, white 97, and 123 were
   drawn.
2. **Rows.** Every third position after the opening of each decisive game,
   6,347 in all, is labelled 1 if the side to move went on to win and 0 if it
   lost. Drawn games say nothing about who was ahead, so they are left out.
3. **The fit.** Logistic regression with T5's trainer
   ([learning](learning.md)): the probability that the side to move wins,
   given the three counts.

Every weight is fitted, including the one Samuel held fixed. The weights
are written to `godot/game/checkers/checkers_weights.json`, and the game
only multiplies by them (invariant 6). `check_no_training.py` runs the whole
pipeline again from its seed and fails if the file differs (N7).

## What it bought: the match

Each of 50 openings is played twice, the weights being tried red once and
white once, against the hand-written ones at the same depth. The score is
points per game, with a draw worth half. The hand against itself scores
exactly 0.5 this way (measured in the wave 33 review), so the colours are
fair.

| weights | depth 1: won, drawn, lost | score | depth 2: won, drawn, lost | score |
|---|---|---|---|---|
| learned | 39, 26, 35 | 0.520 | 3, 19, 78 | **0.125** |
| learned, advancement set to 0 | 21, 47, 32 | 0.445 | 14, 78, 8 | **0.530** |
| control 1, labels shuffled | 37, 29, 34 | 0.515 | 1, 19, 80 | 0.105 |
| control 2 | 39, 26, 35 | 0.520 | 4, 34, 62 | 0.210 |
| control 3 | 27, 38, 35 | 0.460 | 1, 12, 87 | 0.070 |
| control 4 | 34, 27, 39 | 0.475 | 1, 24, 75 | 0.130 |

At one ply everything is even with the hand. At two plies the learned
weights lose nearly every game. Without their advancement weight they are
even again.

## Reading the controls: what this match cannot tell apart

A control is meant to be chance: weights fitted to labels shuffled into
meaninglessness. Here it is not, and the reason is the search, not the fit.

**Alpha-beta only compares scores.** It never asks how large a score is,
only which of two is larger. So multiplying every weight by a hundred, or
dividing by one, plays exactly the same game. A fit to noise comes out
small -- the controls' weights are a thirtieth to a hundredth of the
learned ones --
and plays at full strength in whatever direction it happens to point.

**That direction is not random either.** In these rows men and advancement
move together (correlation 0.89, measured in the wave 33 review: a side
with more men has more men to advance), and a fit to noise tends to trade one against the other. Three of
the four controls point men up and advancement down, like the learned
weights; the fourth points men *down*.

So the match cannot tell weights fitted to results from weights fitted to
noise: the learned 0.125 sits inside the controls' spread, 0.07 to 0.21.
What the controls do show is that at two plies, almost any direction other
than the hand's loses to the hand. The test the task asked for -- no control
better than chance -- holds (every control scores at most 0.52), but it is a
weak test here, and this page says so rather than leaning on it.

## Why the learned weights lose

What is measured:

- **The advancement weight is the cause.** Set it to zero, keep the other
  two, and the learned weights score 0.530 at two plies instead of 0.125.
- **Under the learned weights, an advanced man is worth less than nothing.**
  A man is +0.629 and each row it has advanced −0.212, so a man three rows
  up counts −0.007 and a man six rows up −0.64: worse than losing it. A
  search with those weights holds its men back and does not walk them to the
  crowning row. In the review's count over the 100 two-ply games, the
  learned side crowned 26 times to the hand side's 247.

What is not measured, and is a hypothesis: why the fit came out that way.

- **The weights are not separately interpretable.** Men alone correlate
  *negatively* with winning in these rows (−0.17, the review's measurement: crowning takes a man off
  the men count and puts a king on the other). The fit gives men +1.72
  standard deviations only beside advancement's −2.43. Read either weight on
  its own and it says something the data does not.
- **A likely story for advancement:** in one-ply self-play, a search that
  looks one move ahead walks a man forward without seeing the reply that
  takes it, so the side with men further up the board was often the side
  about to lose them. Plausible; not isolated here.

The general lesson is stated as what this experiment suggests, not what it
proves: **a weight fitted to outcomes measures what went with winning in the
games that produced the data, under the player that played them, and
alongside the other weights it was fitted with.** It does not measure what
causes winning. Samuel's design guarded against both halves of that: he
fixed the term he was sure of, so the fit could not argue piece advantage
away, and he pulled each score towards a search from one move later rather
than towards a result decided many moves and many mistakes after.

## What to try

- Press E in `make run` on the same position. The panel lists the end of the
  line white expects, count by count, with what each count adds under each
  set of weights. The marked column adds up to the chosen move's value. It
  shows what that value is made of; why one move beat another is in the
  difference between the ends of their lines, which the panel does not draw.
- Change `selfplay.DEPTH` to 2 and run `make train-checkers`. Fewer games end
  in a win -- with seed 1959, 41 of 60 at one ply, 12 at two, 18 at three --
  so there are fewer rows.
- Hold the men weight fixed at 1 and fit only the other two, as Samuel did.
- Fit with advancement left out altogether, and play it.

## When not to use it

A fitted linear evaluation is worth having when the features are right and
the games are good. With three features and self-play by the evaluation
being replaced, write the weights by hand and spend the effort on the
search. A program that learns its evaluation in earnest learns from a
deeper search or from strong play. TD-Gammon and its descendants learn from
the positions' own futures, which is where Samuel was already heading in
1959.
