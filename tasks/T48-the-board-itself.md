# T48 — The board itself: a second crossing, a threat map, shorter fights

Size: L · Prereqs: T45, T46, T47 · Files: `godot/game/tactical/`, `spec/`, `python/gameaikit/dataset/`, `godot/test/`, `docs/`

## Goal

Only if T45-T47 leave the tactical board feeling like a queue. Three changes
to the game rather than to its controllers, each named in
[docs/design/tactical-references.md](../docs/design/tactical-references.md)
and each larger than the tasks before it:

- **A second crossing, or zones of control** (§1.3, §1.2). One two-cell
  bridge for four of five types gives a player no *where* to decide, only a
  *when*. A ford at the far edge, or Wesnoth's zone of control -- an enemy
  entering a cell beside a walker stops -- turns the bridge into a line
  held rather than a queue.
- **A threat map** (§2.2, Dave Mark's modular influence maps, by path
  distance so the river blocks it): where each side can strike next turn,
  for retreats and staging, and drawn -- Into the Breach's telegraphed
  intent (§2.5), and invariant 13.
- **One blow and one back instead of a fight to the death** (§1.2, Advance
  Wars and Wargroove): chip damage and focus fire start to mean something.
  It rewrites the combat vectors and retrains the combat model.

## Steps

1. Before anything, the owner chooses which, from T45-T47's measurements
   and a game played after them.
2. Each chosen change ships with its own measurement in
   `tactical_win_rates.gd`, stated before the change is made.

## Acceptance

```bash
make test-godot
make test-vectors
make tactical-win-rates GAMES=40 LIMITS="--at-most rr:draw:8"
```

A threat-map test must hold: a cell across the river with no crossing in
reach carries no threat from a walker that cannot wade, and a planted map
that counts one fails.

## Manual check

The owner plays three games and says whether the board offers a choice of
where to attack.

## What was done so far (2026-10-18, wave 52) -- wip

The owner asked to carry on with the design study's proposals in their
order; T48's step 1 ("the owner chooses which") was answered that way, and
the study's own order put the crossing and the threat map first. The third
change -- one blow and one back -- retrains the combat model and waits for
the owner to ask for it.

- **A second crossing.** Two fords (`f`, `TacticalRules.FORD_COST` 3, the
  cost of trees), at the river's top and bottom rows. A pair, because the map
  is the same turned half round and the bridge already holds the only
  crossing that is its own mirror. Drawn with the board's rough-ground tile,
  so the cost written on it is true, and named in the legend.
- **The planner's domain follows.** `bridge_open` is now `crossing_open`
  and `cross_the_bridge_*` is `cross_the_river_*`: a crossing is open while
  one of the three has none of theirs on it (`TacticalPlanBridge.crossings`).
  A plan that stops running now names the first step ahead that cannot run.
  With the fords no sampled board shuts every crossing, so
  `planner_properties.gd` also plans from each board with every crossing
  shut and the workshop guarded, so its "no plan" half still runs -- found by
  that check printing one half only, after a script error in it had first
  skipped the whole check with exit 0 (now a trap in CLAUDE.md).
- **A threat map** (`ThreatMap`): for each cell, how many of a side's pieces
  could attack it next turn, by path on each piece's own cost map, so the
  river blocks it; a bolt tower's ring. Drawn as a red tint with the count
  for the side not to move; T hides it. `threat_map_test.gd` holds the
  task's test -- across deep water a walker that cannot wade threatens
  nothing -- against the straight-line map the header warns about, which
  counts the cell; a river-blind flood turns it red (planted and undone).
- **Staging on the threat map: not built.** The fords did what it was for
  (below).

**Acceptance** (`make tactical-win-rates GAMES=40 LIMITS="--at-most rr:draw:8"`):
exit 0.

| pairing, 40 games | red | blue | draws | settled at the limit | stuck: red | stuck: blue | over a ford, games: red / blue |
|---|---|---|---|---|---|---|---|
| rules v rules | 7 | 33 | 0 | 8 | 14.8% | 18.2% | 31 / 40 |
| rules v learned | 4 | 36 | 0 | 19 | 12.0% | 15.2% | 31 / 40 |
| learned v rules | 40 | 0 | 0 | 17 | 15.9% | 19.6% | 40 / 36 |
| rules v planner | 1 | 39 | 0 | 0 | 9.1% | 10.0% | 40 / 4 |
| planner v rules | 11 | 29 | 0 | 13 | 13.9% | 14.2% | 40 / 40 |

The study's measures: rules' mirror decided before round 40 in 32 of 40
(at least 80% asked); both crossings used in most games (at least 30%
asked). The learned side's stuck walkers fell from 44% and 42% (T45) to
15.2% and 15.9% -- T45's own limit is 5%.

**What the fords broke: T47's balance.** The rules' mirror went from 59-41
to 7-33. Swept over 100 games each, nothing tried lands red in 40-60%:

| fords at | ford cost | blue's counter | red wins of 100 |
|---|---|---|---|
| rows 0 and 8 | 3, 4, 5 or 6 | none | 100 |
| rows 0 and 8 | 3 | +2 or +6 workshop health | 100 |
| rows 0 and 8 | 3 / 4 / 5 / 6 | the shield | 17 / 14 / 20 / 23 |
| rows 2 and 6 | 3 | none | 4 |
| rows 2 and 6 | 3 | the shield | 14 |

Each ford at rows 0 and 8 opens beside a workshop's corner, and the side
moving first sends a runner over it: without a piece in the way it wins
every game in about 12 rounds, with blue's shield in the way it loses most.
Moved to mid-board, the fords give the side moving second the edge instead.
The game is decided by one lane, which is a design question for the owner
-- a ford placed between those two, a zone of control (the study's other
answer, §4 item 6), or a different counter -- not something to tune blind.
Shipped as measured: fords at rows 0 and 8, cost 3, with the shield.
