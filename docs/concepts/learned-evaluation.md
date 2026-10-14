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

- **One weight was not learned.** Piece advantage was fixed by the
  programmer: "it must be fixed by the experimenter and, in effect, it is
  one of the instructions to the machine defining its task." Kings were worth
  more than men, "the relative weights assigned to them being three to two".
  That is T27's 1.5, which was chosen before anyone looked it up.
- **The target was a deeper search, not the game's result.** The program
  saved the score of each position it played into. One move later it
  compared that score with "the backed-up score for the current position. The
  difference between these scores, defined as delta, is used to check the
  scoring polynomial." Roughly: when delta was positive, the terms that had
  contributed positively gained weight, and the others lost it -- through a
  running correlation, with weights set at powers of two. A position's score
  was pulled towards what looking further ahead said it was worth. That is an ancestor of
  temporal-difference learning.
- **It chose its terms too.** The running program had 38 terms besides
  piece advantage, kept 16 in the polynomial at a time, and moved a term to
  the reserve once it had correlated worst with delta eight times.

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

Each of 50 openings is played twice, the learned weights red once and white
once, against the hand-written ones at the same depth. The score is points
per game, with a draw worth half, so 0.5 is even.

| depth | learned: won, drawn, lost | score | shuffled-labels control | score |
|---|---|---|---|---|
| 1 | 39, 26, 35 | 0.520 | 37, 29, 34 | 0.515 |
| 2 | 3, 19, 78 | **0.125** | 1, 19, 80 | 0.105 |

At one ply the two are even. At two plies the learned evaluation loses
nearly every game, and plays no better than the control: weights fitted to
labels shuffled into meaninglessness.

## Why: a weight measures the games that made it

Read the learned column against the hand column.

- **Advancement is negative.** The fit says a man that has advanced is a
  liability. In one-ply self-play it was one. A search that looks one move
  ahead walks a man forward without seeing the reply that takes it. In those
  games, the side with men further up the board was the side about to lose
  them.
- **A king is worth a third of a man.** A likely reason, not measured:
  kings come late, when the game is usually already decided on men. Once
  men are counted, a king then adds little to the prediction, and the fit
  gives kings little weight.

Both statements are true of the games played, and both are bad advice for
choosing a move. Searching two plies with them, white will not push a man
it could crown, and will not trade a man for a king. The hand-written
evaluation, which wants kings, simply gets them.

This is the general lesson, and the one Samuel's design avoids. **A weight
fitted to outcomes measures what went with winning in the games that
produced the data, under the player that played them.** It does not
measure what causes winning. A weak player's games teach a weak player's
values. Samuel's two choices are the fix for exactly this:

- he fixed the term he was sure of, so the fit could not argue piece
  advantage away;
- he pulled each score towards a deeper search's opinion of the same
  position, rather than towards a result decided many moves and many
  mistakes later.

## What to try

- Press E in `make run` on the same position. The panel lists the end of the
  line white expects, count by count, with what each count adds under each
  set of weights. The count where the two columns differ most is why the two
  choose different moves.
- Change `selfplay.DEPTH` to 2 and run `make train-checkers`. Fewer games end
  in a win (14 of 60 openings were decisive, against 46 at one ply), so there
  are fewer rows. Measured once, over 30 openings: the evaluation fitted
  that way scored 0.28 against the hand at two plies, and advancement was
  still negative.
- Hold the men weight fixed at 1 and fit only the other two, as Samuel did.

## When not to use it

A fitted linear evaluation is worth having when the features are right and
the games are good. With three features and self-play by the evaluation
being replaced, write the weights by hand and spend the effort on the
search. A program that learns its evaluation in earnest learns from a
deeper search or from strong play. TD-Gammon and its descendants learn from
the positions' own futures, which is where Samuel was already heading in
1959.
