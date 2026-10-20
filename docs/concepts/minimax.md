# Minimax and alpha-beta: and then what will they do?

<!-- doc-meta
half_life: concept
verified_on: 2026-10-14
tier: 0
source: book:Russell & Norvig, Artificial Intelligence: A Modern Approach, 4th edition, chapter 5
invalidated_if: ai_adversarial stops returning minimax's value and move from alpha-beta, or the checkers evaluation stops being pieces, kings and advancement
teaches: adversarial-search
-->

> Why the computer in `make run` plays the checkers move it plays, and why
> alpha-beta finds the same move as minimax after looking at far less. Needs
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

## When not to use either

- **Chance.** Dice or shuffled cards need a third kind of node that
  averages, not picks: expectiminimax.
- **Hidden information.** In poker you do not know the position you are in,
  and minimax assumes you do.
- **Very wide games.** Go has around 250 moves a position, and even b^(d/2)
  is out of reach. Monte Carlo tree search is the usual answer.
- **Opponents who are not perfect.** Minimax assumes the best reply. Against
  a beginner, a move that sets a trap they will fall into can be better than
  the move minimax picks. That is an opponent model, T17's subject.
