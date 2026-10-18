# T45 — The AI spends its money and keeps its pieces moving

Size: M · Prereqs: T44 · Files: `godot/game/tactical/`, `godot/test/`

## Goal

T44 measured the learned blue ending games with 172 funds unspent, its
workshop building nothing on 378 of 787 turns -- 377 of them boxed in by its
own pieces -- and 52.5% of its walkers' decisions "stays: no walk this turn
brings it nearer": pieces queued behind each other at the bridge. The rules
controller has its own silent refusal: against the learned side it built
nothing 503 times because "what would beat red's pieces cannot get past
them". Both are the controllers' faults, not the
game's, and both have a standard answer in
[docs/design/tactical-references.md](../docs/design/tactical-references.md)
(§2.1, Wesnoth's RCA AI): **spend first** -- recruitment outranks every move
-- and **never idle** -- a last, low-priority goal for a piece whose goal is
out of reach -- and **one piece per target**, as Wesnoth assigns villages so
that no two units go for the same one.

## Steps

1. The workshop's two silent refusals, measured in T44: the rules' reach
   rule that refuses every type when the enemy's pieces wall the routes (503
   times, the rules controller's), and a workshop boxed in by its own pieces
   (377, the learned blue's), which the board reports as
   "(12, 1) is not next to unit 6". The second says "no room beside the
   workshop", and the first no longer stops a build when a walker of blue's
   already reaches -- decide what it builds instead, and write down why.
2. A fallback goal for a walker whose goal is out of reach: the nearest
   enemy piece it can reach, or a staging cell behind the crossing that
   leaves the way clear -- decided here, said on screen as a rule.
3. Distinct targets: before blue's walkers move, each is given a target no
   other walker of its side has (a point, a bridge cell, a staging cell), so
   two pieces never queue for one cell.
4. `tactical_win_rates.gd` gains limits on what it already counts -- the
   share of stuck walker decisions and the funds left at the end -- so the
   acceptance below is a command.

## Acceptance

```bash
make test-godot
make tactical-win-rates GAMES=20 LIMITS="--at-most rl:stuck-percent:5 --at-most lr:stuck-percent:5 --at-most rl:blue-funds-left:10"
```

The suite must hold: the boxed-in workshop says there is no room; two
walkers of one side never take the same target in one turn; a walker with
no way to its goal moves to its fallback rather than staying.

## Manual check

Play `make demo-tactical` against each controller for ten rounds: blue's
pieces should cross or stage, not stand in a queue at the bridge.

## What was done so far (2026-10-18, wave 49) -- wip

Steps 1-4 are built and tested; the acceptance command runs and **fails**,
and the reasons are the board's, not the controllers' -- so it stopped here
for the owner rather than for more tuning by trial and error.

- **Step 1, spend first.** When nothing that could reach red's workshop
  beats a red piece, `RuleBasedBlue` builds the type that beats the most of
  them anyway (it holds blue's bank until the way opens), or the cheapest
  when nothing beats anything: money banked is a piece not on the board,
  Wesnoth's order. A workshop with no room says "no room beside the
  workshop" (`RuleBasedBlue.NO_ROOM`) instead of "(12, 1) is not next to
  unit 6", and `BlueTurn` asks it once more after the last walker, because
  the walkers may have moved off.
- **Step 2, never idle.** A walker whose goal is out of reach -- every way
  shut, no walk nearer, or its goal already taken -- walks at the nearest of
  the three red pieces nearest it as the crow flies that some walk brings it
  nearer, and says so as "a fallback rule". It holds only when none does.
  A walker already in reach of red's workshop now "stays in reach, to attack
  it" instead of being counted as stuck. T41's test of the shut bridge now
  expects the fallback, not a hold.
- **Step 3, one piece per target.** A control point is the goal of one
  walker a turn; red's workshop of as many as it has open cells beside it.
  The learned blue skips a point another walker took for the next one the
  capture model ranks. Its holds for want of a nearer walk take the same
  fallback.
- **Step 4.** `tactical_win_rates.gd` takes `red-stuck-percent`,
  `blue-stuck-percent`, `stuck-percent` (the larger), `red-funds-left` and
  `blue-funds-left` as limits.

`tactical_spending_test.gd` holds the three claims the task names and the
two rules beside them; removing the point claim, the second asking, spend
first or the fallback each turns a case red (planted and undone).

**Measured** (`make tactical-win-rates GAMES=20`, the acceptance's limits):

| pairing | red | blue | draws | rounds | stuck: red | stuck: blue | funds left: red / blue |
|---|---|---|---|---|---|---|---|
| rules v rules | 10 | 5 | 5 | 27.3 | 960 of 4237 | 742 of 3963 | 28 / 32 |
| rules v learned | 0 | 3 | 17 | 40.0 | 1010 of 4071 | 4942 of 11275 (43%) | 46 / 97 |
| learned v rules | 5 | 0 | 15 | 38.5 | 3745 of 9414 (39%) | 816 of 3782 | 116 / 51 |
| rules v planner | 0 | 16 | 4 | 26.4 | 1179 of 3755 | 1694 of 4830 | 28 / 27 |
| planner v rules | 4 | 12 | 4 | 27.6 | 798 of 3763 | 856 of 4374 | 21 / 40 |

The limits: `rl` stuck 43% and `lr` 39% (at most 5), `rl` blue funds left
97 (at most 10). Exit 1.

What changed for the better: the rules' mirror is no longer won by whoever
moves first (was 20-0, now 10-5 with 5 draws), and T11's planner, whose
workshop used to idle on the rules' refusal, now wins 16 of 20 as blue
(was 7) and 4 as red (was 0).

**Why the acceptance cannot be met by the controller alone** -- for the
owner to decide:

- **Funds.** A workshop builds once a turn, and a side holding both points
  is paid 7 a turn -- more than any walker costs. Spending every turn still
  banks money; "at most 10 left" needs a second purchase a turn, or cheaper
  income, which are rules of the game (T48's territory), not of the AI.
- **Stuck walkers.** Measured on the learned blue: most of what is still
  stuck has **no walk at all** -- pieces boxed in by their own side round
  their workshop (cells (10, 1)-(13, 3)), because a side that spends every
  turn fills its corner faster than one bridge two cells wide lets it out
  while red holds that bridge. Own pieces block a walk (`TacticalReach`), a
  board rule. A staging rule ("step aside off the route") was considered and
  not built: it cannot help a piece with no walk. The owner's options are
  T48's -- a second crossing, or letting a piece pass through its own side
  as Advance Wars does -- or a lower acceptance for this task.
