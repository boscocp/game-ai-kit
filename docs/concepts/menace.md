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
lost through a blunder later is punished just the same -- and given enough
games, that washes out.

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

Against perfect play it learns quickly never to lose. Against a random
player it **still loses about one game in a hundred**, and that is not a bug
in the code. It is what Michie's rewards ask for.

### Why it never stops losing to a random player

A random player blunders. A move that sets a trap -- one a perfect player
would punish -- wins four games in five against one, and loses the fifth. The
rewards add three beads for each of the four wins and take one away for the
loss, so the trap move gains beads steadily, and a favourite box can hold
hundreds of them. Then the random player stumbles on the reply that beats
it.

Training against the perfect player afterwards does not undo this. A
perfect player never walks into those positions, so the boxes holding the
traps are never drawn from again, and never corrected.

The task this kit was built from asked for a machine that never loses to a
random player. Measured over ten seeds, Michie's rules gave one between 0
and 77 losses in a thousand. The choice was between keeping his rules and
measuring what they promise, or changing them until the number came out
right. The rules were kept: the tests hold that the 10,000-game machine
loses nothing to perfect play, that the 10-game one does, and that against a
random player it loses a tenth as often or less.

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
