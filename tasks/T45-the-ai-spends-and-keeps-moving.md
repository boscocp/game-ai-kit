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

**Measured** after wave 49's review (`make tactical-win-rates GAMES=20`, the
acceptance's limits; a fallback walk now claims its red piece too, which
moved several pairings):

| pairing | red | blue | draws | rounds | stuck: red | stuck: blue | funds left: red / blue |
|---|---|---|---|---|---|---|---|
| rules v rules | 12 | 7 | 1 | 23.6 | 849 of 3516 | 841 of 3320 | 26 / 26 |
| rules v learned | 0 | 1 | 19 | 40.0 | 1248 of 4000 | 4913 of 11054 (44.4%) | 42 / 99 |
| learned v rules | 4 | 0 | 16 | 38.6 | 3902 of 9397 (41.5%) | 902 of 3777 | 121 / 50 |
| rules v planner | 3 | 13 | 4 | 30.9 | 1000 of 4556 | 989 of 4886 | 32 / 30 |
| planner v rules | 0 | 20 | 0 | 11.0 | 237 of 962 | 437 of 1372 | 9 / 18 |

The limits: `rl` stuck 44.4% and `lr` 41.5% (at most 5), `rl` blue funds
left 99.3 (at most 10). Exit 1. Before the claim on fallback targets the same
command gave 43%, 39% and 97, rules mirror 10-5-5, and the planner 16-0-4 as
blue and 4-12-4 as red -- claiming spreads walkers over more targets, and
the planner as red, which already loses its first turns saving for the
forge, loses all twenty again.

**Not like for like with T44.** A walker already in reach of red's workshop
used to be counted stuck and now "stays in reach, to attack it", so part of
the fall from T44's 52.5% is the definition, not new behaviour.

What changed for the better: the rules' mirror is no longer a first-mover
sweep (was 20-0), and T11's planner, whose workshop used to idle on the
rules' refusal, wins as blue 13 of 20 (was 7).

**Why the acceptance is not met** -- for the owner to decide, on numbers
wave 49's review corrected:

- **Stuck walkers.** The first version of this record said most stuck
  walkers had no walk at all. The review counted, and it is false: over
  half have one (2548 of 4942 in `rl`, 2053 of 3745 in `lr`). So part of the
  gap is the controller's, and a staging rule -- step aside off the route
  when nothing gets nearer -- is the controller's answer. The review tried a
  crude ten-line one: stuck fell to 14% (`rl`) and 22% (`lr`) and those games
  became decisive, but the other pairings swung wildly (rules mirror 2-18,
  planner 1-19 as red). Not shipped. The reference's version of the rule
  (§4, item 5) picks the staging cell from a threat map, which is T48's, and
  that is where it belongs. The rest -- pieces with no walk at all, boxed in
  by their own side round the workshop behind a bridge one cell wide and two
  long while red holds it -- is the board's (a second crossing, or passing
  through one's own pieces: T48).
- **Funds.** One build a turn is the floor, and the learned blue's income
  averages 4.35 a turn while it spends 2.06 (the review's measurement; the
  first version of this record said 7, which is what holding both points
  pays, not what the side earns on average). With one build a turn and no
  forge the floor is about 58 left; with the forge and rams about 17. Even
  building the dearest piece every turn ended at 99, because the corner
  filled (80% stuck). So "at most 10" needs a second purchase a turn or
  cheaper income -- a rule of the game -- or a different limit.
