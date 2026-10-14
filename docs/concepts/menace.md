# MENACE: a machine that learns noughts and crosses from matchboxes

<!-- doc-meta
half_life: concept
verified_on: 2026-10-14
tier: 1
source: book:Donald Michie, "Experiments on the mechanization of game-learning, part I", The Computer Journal 6(3), 1963
invalidated_if: gameaikit.menace stops using Michie's starting beads or rewards, or the published snapshots change ages
teaches: reinforcement-learning
-->

> How 304 matchboxes and a bag of beads learnt to play noughts and crosses
> in 1961, and what that machine can and cannot learn. Tier 1: the whole
> thing is Python's standard library, in
> [`python/gameaikit/menace/`](../../python/gameaikit/menace/). `make
> demo-tictactoe` plays it in Godot.

## The machine

Donald Michie had no computer to hand, so he built one out of matchboxes.
MENACE -- the Machine Educable Noughts And Crosses Engine -- plays crosses
and moves first:

- **one matchbox for every position** MENACE can face with itself to move.
  A position and its mirror image or rotation are the same position, so they
  share a box. That folds the positions down to **304**: 1 for its first
  move, 12 for its second, 108 for its third and 183 for its fourth. With one
  square left the move is forced, and there is no box for it;
- **beads in each box, one colour per move.** On the empty board there are
  only three colours -- a corner, an edge, the centre -- because the four
  corners are one move turned;
- **to move**, shake the box for the position on the board and draw a bead.
  The more beads of a colour, the likelier that move.

New boxes start with 4 beads of each colour for the first move, 3 for the
second, 2 for the third and 1 for the fourth.

## How it learns

After each game, every box MENACE drew from is told how the game went:

| outcome | the bead drawn |
|---|---|
| a win | goes back, with **3 more** of its colour |
| a draw | goes back, with **1 more** |
| a loss | **stays out** |

That is the whole algorithm. A move that led to wins becomes likelier, a
move that led to losses rarer. A box with no beads left has learnt that
every move from there loses, and MENACE **resigns**.

It is reinforcement learning, with no network, no gradient and no
equations: the outcome of a game, handed back to every decision that led to
it. The credit is shared out crudely -- a good move made early in a game
lost through a blunder later is punished just the same. Given enough games
much of that washes out, but not all of it, as the next section measures.

## What it learnt, measured

`make train-menace` plays 5,000 games against a random player and then
5,000 against a perfect one (minimax, searched to the end -- see
[minimax.md](minimax.md)). The game keeps MENACE at four ages, and each one
is measured playing its **favourite** bead every time, over 1,000 games
against each opponent (`python3 -m gameaikit.menace.report`):

| after | vs random: won / drew / lost | vs perfect: won / drew / lost |
|---|---|---|
| 10 games | 535 / 152 / 313 | 0 / 0 / 1000 |
| 100 games | 783 / 129 / 88 | 0 / 1000 / 0 |
| 1,000 games | 969 / 22 / 9 | 0 / 1000 / 0 |
| 10,000 games | 968 / 22 / 10 | 0 / 1000 / 0 |

That is one training run, from the seed the game uses. The same training
from ten seeds (`python3 -m gameaikit.menace.report --seeds 10`), as losses
in 1,000 games:

| | lost, fewest to most |
|---|---|
| 10 games, vs random | 91 to 396 |
| 10,000 games, vs random | 0 to 77; fewer than at 10 games on every seed |
| 10 games, vs perfect | 294 to 1000 |
| 10,000 games, vs perfect | 0 on nine seeds; **1000 on one** |

Two things in that table are not bugs in the code. They are what Michie's
rules do.

### It locks in a move that wins often enough

In the published machine, one box -- crosses on the centre and the bottom
left, noughts on the top right and the middle right -- holds 191 beads for the
top left and 56 for the bottom right. Played on against a random player, the
top left wins three games in four and loses the fourth. The bottom right
wins every time.

The rules cannot tell those apart well enough. Three wins add nine beads and
the loss takes one away, so the worse move gains beads steadily and the
better one never catches up: its head start in beads is what decides which
one gets drawn, and so which one gets the next nine. A favourite box can hold
hundreds of beads, and the rare loss it allows is never trained away.
Training against the perfect player afterwards does not help either: a
perfect player never walks into the position, so the box is never drawn from
again.

### A box can run dry

On one seed of ten, the box for a position MENACE can still draw empties.
Each move there led, sooner or later, to a loss -- the blocking move
included, lost through a blunder later in the same game -- and every loss
took its bead. An empty box resigns, so that machine resigns every game that
reaches it, against any opponent.

### What the tests hold

The task asked for a machine that never loses to a random player. Michie's
rules do not give one, on most seeds. The owner chose to keep his rules and
hold what the published machine does, against what it is weakest and
strongest at:

- after 10,000 games it loses no game of 1,000 to perfect play;
- after 10 games it loses some;
- against a random player, it loses fewer games after 10,000 than after 10.

## The same game, the other way: minimax

Noughts and crosses has 5,478 positions, few enough to search every one. So
the perfect player is not learnt but **computed**: minimax, from T27, with no
depth limit. Press M in `make demo-tictactoe` and each square says what
perfect play makes of it. Then you can see where MENACE agrees with it --
and where its beads say "centre, 90%" in a position where the edge was just
as good.

## Training happens in Python, and only there

The game reads `godot/game/tictactoe/menace_beads.json` and draws from it.
It never adds a bead or takes one away (invariant 6):

- `check_no_training.py` refuses a bead count written in GDScript (N5);
- it trains MENACE again from the seed and refuses a published file that
  has come apart from what the pipeline writes (N6);
- a test plays sixty moves in the scene and checks that no bead changed.

## When not to use it

- **Anything larger.** One box per position works for 304 positions. Chess
  has more positions than there are atoms to make matchboxes from. Learning
  there needs a function that generalises across positions it has never
  seen -- a value function, a network -- which is where reinforcement
  learning went next.
- **When the opponent is known.** Against a fixed opponent you can search,
  and search is exact.
