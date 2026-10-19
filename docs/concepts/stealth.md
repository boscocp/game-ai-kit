# Stealth: what a guard perceives, and how suspicious that makes it

<!-- doc-meta
half_life: concept
verified_on: 2026-10-19
tier: 0
source: book:Ian Millington, "AI for Games", 3rd edition, CRC Press, 2019 -- chapter 5 on fuzzy logic
invalidated_if: StealthGuard's thresholds, Suspicion's controller or RATE, or VisionCone's three tests change
teaches: perception
-->

> How the guards in `make demo-stealth` decide whether to keep to their
> round, go and look, or give chase. Reading only: the code is
> [`godot/game/stealth/`](../../godot/game/stealth/) with the senses in
> [`ai_perception`](../../godot/addons/ai_perception/) and the controller in
> [`ai_fuzzy`](../../godot/addons/ai_fuzzy/), and every number below is a
> constant there.

## Two questions, kept apart

A stealth guard has to answer *what can I perceive?* and *how much should
that worry me?*, and the kit answers them in two separate places on purpose.
Perception is geometry and is the same for every guard; worry is a judgement,
and is where a designer tunes the game.

## Perceiving: a cone, a line, a noise

`VisionCone.sees` runs three tests, cheapest first, so most of the board is
turned away before the expensive one runs:

1. **near enough**: within the cone's reach, eight cells here;
2. **within the angle** the guard faces;
3. **nothing in the way**: `LineOfSight` walks the cells between eye and
   target, and walls and trees stop it.

Light does not change what is seen: a guard sees you in the shade exactly
as it does in the light. It changes how much that worries it, as one of the
fuzzy controller's inputs below. Hearing is cruder, and says so: `Hearing.loudness_at` falls off in a straight
line from the source and **walls do not stop it**. A walk carries three
cells, a sprint seven, and waiting is silent. A heard noise tells the guard
your exact cell, through walls -- a simplification named in the code.

## Worrying: a fuzzy controller

A guard that flips to "seen" the instant one cell of you enters its cone is
a light switch, and players read it as unfair. `Suspicion` replaces the
switch with a number from 0 to 100 that moves. Each turn a **fuzzy
controller** reads four inputs -- how near, how lit, how loud, how long since
-- and its rules, written so a designer can read them aloud, say how alarming
that is. "Near *and* lit is alarming"; "far *or* dark is calm". Every rule
fires a little, by how true its condition is, and the answer is the
balance point of all of them (a centroid).

Then the level moves **half the way** towards that answer each turn, so it
rises and falls rather than snapping, and it never falls while you are in
sight. With nothing to go on it settles near 12, not 0: that is where the
shape of "calm" balances.

## Deciding: three states with a gap

The level picks one of three states, with a gap between going up and
coming down so a level hovering at one threshold does not flicker the guard
between two minds:

| state | goes up at | comes down below |
|---|---|---|
| patrol -- walk the round | | |
| investigate -- walk to where you were last noticed | 40 | 25 |
| alert -- run there, two cells a turn; only an alert guard catches | 75 | 60 |

Every walk is an A\* route on the board, around the other guards.

## The danger map

D in the demo draws an **influence map**: a number per cell saying how
dangerous it is to stand there. Each guard raises every cell it sees, by how
near, and the cells along its next few steps, so a corner is dangerous
before the guard can see round it -- which is the thing a player is actually
afraid of. A cell keeps the strongest value rather than the sum: two guards
watching it make it no more watched than the nearer one does.

## When not to use this

- **Many watchers on a large map.** Asking every cell whether it is seen is
  a few hundred line walks here; with hundreds of guards, cast rays outwards
  once per guard, or use the engine's physics.
- **Sound that should go round corners.** That is a search over the grid, a
  Dijkstra flood from the source, and a good deal more than a radius.
- **Past a dozen fuzzy rules.** Twenty overlapping rules are a system nobody
  can predict, since every change moves every output a little; a decision
  tree says the same more plainly.
