# Minimax and alpha-beta: and then what will they do?

<!-- doc-meta
half_life: concept
verified_on: 2026-11-05
tier: 0
source: book:Russell & Norvig, Artificial Intelligence: A Modern Approach, 4th edition, chapter 5 (5.4 for Monte Carlo tree search, 5.5 for expectiminimax)
invalidated_if: ai_adversarial stops returning minimax's value and move from alpha-beta, MonteCarloSearch stops being UCT with one child per outcome, ExpectiminimaxSearch stops summing outcomes by their chances, the squad duel is measured again, or the checkers evaluation stops being pieces, kings and advancement
teaches: adversarial-search
-->

> Why the computer in `make run` plays the checkers move it plays, why
> alpha-beta finds the same move as minimax after looking at far less, and
> how Monte Carlo tree search chooses with no evaluation at all. Needs
> nothing but reading. The code is in
> [`godot/addons/ai_adversarial/`](../../godot/addons/ai_adversarial/).

## The question nothing else in the kit asks

Every other decision in this kit is one side choosing alone. A search finds
the cheapest route, and the map does not fight back. A game has an opponent,
and the opponent is trying to make your plan fail. So "which move is best?"
turns into "which move is best, **given that they will then reply as well as
they can?**"

## Minimax

Call the player the search is for **MAX** and the opponent **MIN**. Lay out
every move, every reply to each, every reply to those, as a tree. Then fill
it in from the bottom:

- a position at the bottom gets a number: how good it is for MAX;
- a position where MIN is to move is worth the **lowest** of its children,
  because MIN will pick that one;
- a position where MAX is to move is worth the **highest** of its children.

The move at the top whose child holds the highest number is the move to
play. That number is the **minimax value**. It is what MAX is guaranteed if
both sides play as well as the tree can see.

A small example, the one Russell & Norvig use (figure 5.2). MAX has three
moves. MIN then has three replies to each, and the leaves are worth:

| MAX plays | MIN's replies are worth | MIN picks | so the move is worth |
|---|---|---|---|
| a1 | 3, 12, 8 | 3 | **3** |
| a2 | 2, 4, 6 | 2 | 2 |
| a3 | 14, 5, 2 | 2 | 2 |

MAX plays a1. The 14 under a3 is a trap: MIN would never let MAX have it.
`test/checkers/adversarial_test.gd` holds both searches to this tree.

## Stopping early, and the evaluation

Checkers has around 10^20 positions. Nobody searches it to the end, so the
search stops after a fixed number of **plies** (one ply is one player's
move) and asks an **evaluation function** how good the position looks. Here
it is three counts, white's minus red's:

- a man is worth 1;
- a king is worth 1.5;
- a man earns 0.05 for each row it has advanced.

That is all the computer knows about checkers. Everything that looks like
cleverness -- avoiding a capture that gets recaptured, setting up a double
jump -- comes from looking ahead and applying those three counts at the end.
T32 replaces them with weights fitted from games, after Arthur Samuel's
checkers program, and the search does not change.

### Why depth matters, in one position

In `make run`, white sometimes has two captures and must take one. Say one
lands where a red man jumps straight back, and the other is safe:

- **at depth 1** the search sees only its own capture, and both look the
  same: one red man fewer. It takes the first one listed, and loses its man;
- **at depth 2** it sees red's recapture, and the first capture now gives
  its man straight back. It takes the safe one.

`test/checkers/checkers_rules_test.gd` holds exactly this -- in its position the
recapture takes white's last man, so the wrong capture loses the game -- and
checks that depth 1 gets it wrong. Without that check, the test would also pass for a search
that never looked ahead at all.

## Alpha-beta: the same answer for less work

Look again at a2 in the table. MIN's first reply is worth 2. MAX already has
a1, worth 3. Whatever MIN's other replies are worth, MIN will pick something
worth **at most 2**, so a2 can never beat a1. The 4 and the 6 do not need
looking at. That is a **cut**.

Two numbers carry it down the tree:

- **alpha**, the best MAX is already sure of on this path;
- **beta**, the best MIN is already sure of on this path.

When a position's value falls outside the window between them, the player
choosing above it will never let play reach it, so the rest of its moves are
skipped. The answer is exactly minimax's -- same value, same move -- because
only positions that could not change the answer were skipped.

Three things to notice on the screen:

- **"≤ -0.10"**: a move alpha-beta cut short. It proved the move no better
  than one it already had, and stopped. The number is an upper bound, not
  the move's value, and the board says so. A move it searched to the end
  shows its value even when it lost -- the bound is only where it stopped;
- **"searched 123 positions; skipped 78 replies"**: the cost. Each skipped
  reply is a whole branch below it never searched. Press 1 to 6 and watch
  the positions grow. After red opens a3-b4, white searches 8, 55, 96,
  254, 737 and 1702 positions at depths 1 to 6: two to three times more per
  ply, where minimax would pay about eight;
- **"the line it expects"**: the chosen move and the replies each side would
  pick, to the depth searched. The value is the evaluation at the end of
  that line, which is what turns one number into a reason.

### How much it saves

Minimax visits every position down to the depth: about b^d, where b is the
moves per position (around 8 in checkers) and d is the depth. Alpha-beta
visits the same number in the worst case, when the best moves come last.
With the best moves first it visits about b^(d/2) -- the same cost buys
**twice the depth**. Measured on this kit's opening position, red to move,
at depth 4: minimax visits 1828 positions and alpha-beta 545, for the same
move.

## The horizon

The search sees exactly as far as its depth, and nothing beyond. Two things
follow, and both can be watched in `make run`:

- **Trouble just past the horizon is invisible.** At depth 1 the computer
  walks into a recapture that depth 2 sees.
- **A win too far away is invisible too.** With white several kings up and
  red down to one king, every move looks the same to a search that cannot
  see the chase end, so white can shuffle a king back and forth. The
  evaluation counts material and advancement, and none of that changes
  while kings wander. The 40-move rule then draws a won game, and the status
  line counts down to it.

Better evaluations -- or deeper searches -- are the cures. T32 fits one from
games instead of writing it by hand.

## Monte Carlo tree search: play it out, many times

Everything above leans on the evaluation. Take it away -- a game nobody
knows how to score halfway, a game with dice, a game too wide for even
alpha-beta -- and minimax has nothing to stop on. **Monte Carlo tree
search** (MCTS) needs no evaluation before the end: to judge a move, it
plays the game out from there with **random moves**, many times, and
counts who won. A move that wins three playouts in four is probably better
than one that wins one in four -- not certainly, and the more playouts, the
less "probably". That is the first thing it teaches: **sampling instead of
an evaluation function**.

It does not spread the playouts evenly. It grows a tree from the current
position, one node per playout, and each **iteration** has four phases --
Russell & Norvig's names, AIMA 5.4, figure 5.11, and the names of the
functions in `godot/addons/ai_adversarial/mcts.gd`:

1. **Select.** From the root, walk down the tree, at each node taking the
   move with the highest **UCB1** bound, until a node with a move never
   tried.
2. **Expand.** Try one of those untried moves, and add the position it
   leads to as a new node.
3. **Simulate.** From the new node, play random moves to the end of the
   game (the **playout**). Nothing of it is kept.
4. **Back-propagate.** Walk back up the path, and add the result to every
   move on it -- for the player who chose that move.

UCB1 is what decides where the next playout goes:

    mean value of the move  +  C * sqrt( ln(visits of the position) / visits of the move )

The first term favours moves that have done well (**exploitation**). The
second is large for a move tried little and shrinks as it is tried
(**exploration**), so a move that looked bad after three unlucky playouts
gets another look, and a move that is bad after three hundred does not.
UCB1 at every node of the tree is **UCT**, "UCB applied to trees" (Kocsis
and Szepesvári, 2006, as AIMA 5.4 cites them), the variant Roelofs used for
*Xenonauts 2* and calls "the most common and battle tested" (GAP3 ch. 28).
C = √2 is the usual default, and the kit's. It is the constant UCB1's
analysis gives for results between 0 and 1; the kit's toy games score
from -1 to 1, twice as wide, so at √2 they explore about half as much as
that analysis suggests -- `exploration` is the knob.

The second thing it teaches is that it is **anytime**. Alpha-beta at depth
6 has no answer until it has finished depth 6. MCTS has one after every
iteration -- the move tried most -- and every iteration makes it a little
better. So a game gives it a budget per frame, `step(iterations)`, and
asks again next frame; the tree carries over. Checkers' alpha-beta at depth
6 can stall a frame for ~730 ms; MCTS never has to.

The answer it gives is the **most visited** move, not the one with the
best mean: a mean from three playouts is a guess, and UCB1 has already
spent its playouts on the moves it believes in. In the kit's Nim, measured
over 40 seeds, 1000 iterations find the winning take from every pile up to
11 sticks; from 13 they need about 2000. After 300 from ten sticks, seed 1
still prefers taking one -- `spec/vectors/adversarial/mcts-nim.json` keeps
that case, because an anytime answer is not always a right one.

**Chance.** A game with dice tells the search what a move *may* lead to,
each with its probability (`GakAdversarialGame.outcomes`). After such a move
the tree keeps **one child per outcome**, and each iteration draws which
one it walks into. What the search learns under a lucky roll stays under
that roll. The other way, open-loop MCTS -- one child per move, the rolls
mixed together -- is lighter and is not in the kit.

**Where it is weak.** A random playout must say something about the
position. In a game where almost every random move loses at once -- a
tactical trap, a chess position with one saving move -- the playouts
measure the randomness, not the position, and alpha-beta with a decent
evaluation wins. Browne et al. (2012) survey the many repairs: smarter
playouts, a learned evaluation beside the playout or in place of it
(AlphaGo, then AlphaZero), and more.

## Expectiminimax: the dice, weighed

Minimax has two kinds of position, MAX's and MIN's. A game with dice has a
third, where nobody chooses: the **chance node**. Its value is not the best
or the worst of its children but their **expected value** -- each
outcome's value times its probability, summed. Russell & Norvig, AIMA 5.5,
call the result **expectiminimax**; `godot/addons/ai_adversarial/expectiminimax.gd`
is that, reading the same `outcomes` MCTS draws from. A shot that hits 55%
of the time for a position worth +0.4, and misses for one worth -0.1, is
worth 0.55 x 0.4 + 0.45 x (-0.1) = 0.175.

Two things change from minimax. **The evaluation's scale matters**, not
only its order (AIMA 5.5.1): with leaves 2, 3 and 1, 4 behind two 90/10
throws, the first move is worth 2.1 and the second 1.3; write the same
leaves as 20, 30 and 1, 400 -- the same order -- and the second is worth
40.9 and wins. `expectiminimax_test.gd` holds the book's example. And **the
dice multiply the branching**: b moves with n outcomes each is (b n)^d,
and alpha-beta's cut does not carry over -- an outcome not yet seen could
be worth anything, unless the evaluation's range is known (*-minimax, not
in the kit).

It is anytime by **iterative deepening**: search depth 1, then 2, then 3,
and always answer with the deepest finished. The walk is kept on a stack so
a frame can stop it after a few positions and pick it up next frame.

## Expectiminimax against MCTS, on the same positions

T88 put both in the XCOM mode of the tactical game, where every shot is a
die: `MctsSquad` (T87) samples, `ExpectiSquad` works out the odds, with an
evaluation written by hand -- health, the cover held, the enemies flanked,
each with a fixed weight -- which MCTS does without. Both search the same
board (one guess at the fog), and `make test-squad-duel` gave each the same
time on 30 positions drawn from seeded matches. On 2026-11-05, on a 12-core
machine running other work:

| a decision | the two agree | MCTS iterations | expectiminimax finished |
|---|---|---|---|
| 50 ms | 16 of 30 | 45-184 | depth 1 on 16, depth 2 on 14 |
| 200 ms | 16 of 30 | 179-1,018 | depth 1 on 7, 2 on 21, 3 on 2 |
| 1,000 ms | 15 of 30 | 891-6,638 | depth 2 on 22, 3 on 8 |

The shots are where they agree: 14 of the 16 shot questions at 50 and
200 ms, 15 at 1,000; of the 14 walk questions, 2, 2 and none. A shot question has two to four answers, so
MCTS spends hundreds of playouts on each and expectiminimax gets three
plies deep. The walks are where they part: some forty answers, so MCTS
has a handful of playouts each in 200 ms and its most visited walk is
noise, and expectiminimax, at a ply or two, sees only the next shot and
what its evaluation says of the cell. Neither is right by construction;
which is better is the matches' question:

| every decision 50 ms, 100 matches a seat | as red: won, lost, drawn | as blue: won, lost, drawn |
|---|---|---|
| expectiminimax against MCTS | 9, 5, 86 | 53, 43, 4 |
| expectiminimax against the weighed enemy | 2, 98, 0 | 1, 99, 0 |
| MCTS against the weighed enemy | 4, 96, 0 | 3, 97, 0 |

| every decision 200 ms, 20 matches a seat | as red: won, lost, drawn | as blue: won, lost, drawn |
|---|---|---|
| expectiminimax against MCTS | 3, 17, 0 | 4, 16, 0 |
| expectiminimax against the weighed enemy | 0, 20, 0 | 1, 19, 0 |
| MCTS against the weighed enemy | 8, 12, 0 | 9, 11, 0 |

Measured on 2026-11-05 alongside other worktrees' tests, load between 3
and 15 on 12 cores: 100 matches a seat at 50 ms, matches 1 to 100 in four
runs at once; 20 a seat at 200 ms, matches 101 to 120 in two. Not at
1,000 ms: some fifty decisions a side a match make each match a minute and
a half, and 600 of them most of a day. At 50 ms both searches lose almost
every match to the first enemy, which weighs one action ahead in about a
millisecond; between them, expectiminimax wins more than it loses, and as
red most games end drawn at the round limit (not looked into further). At
200 ms the order turns over: MCTS beats expectiminimax 33 to 7, and starts
taking games from the first enemy, as T87 measured -- MCTS gains from every
iteration, expectiminimax only from a whole ply more, forty times dearer.

When each wins, from this: **expectiminimax** where the choice is between
few options whose difference is in the odds -- a 45% shot against a 55%
one, worth 0.005 apart: it computes that exactly, where MCTS needs hundreds
of playouts to see it -- and where you can write an evaluation you trust.
**MCTS** where the options are many and the consequences far: it needs no
evaluation, and its answer improves smoothly with time, where
expectiminimax's improves a whole ply at a time, forty times dearer each.
The page of the mode, `docs/godot/squad.md`, keeps every position and one
disagreement worked through.

## When not to use either

- **Chance**, for minimax and alpha-beta. Dice or shuffled cards need a
  third kind of node that averages, not picks: expectiminimax, above. Or
  Monte Carlo tree search, which draws the dice as it plays them out.
- **Hidden information.** In poker you do not know the position you are in,
  and minimax assumes you do.
- **Very wide games.** Go has around 250 moves a position, and even b^(d/2)
  is out of reach. Monte Carlo tree search, above, is the usual answer.
- **Opponents who are not perfect.** Minimax assumes the best reply. Against
  a beginner, a move that sets a trap they will fall into can be better than
  the move minimax picks. That is an opponent model, T17's subject.
