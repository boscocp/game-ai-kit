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
  cost of trees; a wader pays 1 there, as in deep water), at rows 1 and 7 --
  one row in from each end of the river. A pair, because the map is the same
  turned half round and the bridge already holds the only crossing that is
  its own mirror. Drawn with the board's rough-ground tile, so the cost
  written on it is true, and named in the legend with its own cost.
- **The planner's domain follows.** `bridge_open` is now `crossing_open`
  and `cross_the_bridge_*` is `cross_the_river_*`: a crossing is open while
  one of the three has none of theirs on it (`TacticalPlanBridge.crossings`).
  A plan that stops running names the first step ahead that cannot run. With
  the fords almost no sampled board shuts every crossing, so
  `planner_properties.gd` also plans from each board with every crossing
  shut and the workshop guarded, and both its halves run -- found after a
  script error in it had first skipped the whole check with exit 0 (now a
  trap in CLAUDE.md).
- **A threat map** (`ThreatMap`): for each cell, how many of a side's pieces
  could attack it next turn, by path on each piece's own cost map, so the
  river blocks it; a bolt tower's ring. Drawn as a red tint with the count
  for the side not to move; T hides it. `threat_map_test.gd` holds the
  task's test -- across deep water a walker that cannot wade threatens
  nothing -- against the straight-line map the header warns about, and the
  tower and the walker's full movement each have a case. **Nothing decides by
  it yet:** the learned blue still retreats by its straight-line reach
  (`LearnedBlue._out_of_reach`), and staging was not built.
- **The rules say where they cross**: "crossing the bridge", "crossing by
  the ford", or "making for a crossing" -- not "the bridge" on the way to a
  ford, which a review saw on screen.

**Where the fords go decides the game.** Rules against rules, 100 games:

| fords at | ford cost | blue's counter | red wins of 100 |
|---|---|---|---|
| rows 0 and 8 | 3, 4, 5 or 6 | none | 100 |
| rows 0 and 8 | 3 | +2 or +6 workshop health | 100 |
| rows 0 and 8 | 3 / 4 / 5 / 6 | the shield | 17 / 14 / 20 / 23 |
| rows 2 and 6 | 3 | none / the shield | 4 / 14 |
| **rows 1 and 7** | **3** | **the shield** | **51** (53 with a wader paying 3 there, the review's run) |

At the river's ends each ford opens beside a workshop's corner and the side
moving first rushes it; in mid-board the side moving second gets the edge.
Rows 1 and 7, the place between, were the one the first sweep missed and
wave 52's review found. They are shipped, with T47's shield, and T47's
band holds again (51-49, exit 0).

**Acceptance** (`make tactical-win-rates GAMES=40 LIMITS="--at-most rr:draw:8"`):
exit 0. Compared with `main` before the fords, on the same 40 seeds (main's
figures are wave 52's review's):

| pairing, 40 games | red | blue | draws | at the limit | stuck: red | stuck: blue | stepped onto a ford, games: red / blue |
|---|---|---|---|---|---|---|---|
| rules v rules | 21 | 19 | 0 | 5 | 9.7% | 18.0% | 40 / 40 |
| rules v learned | 2 | 38 | 0 | 24 | 11.0% | 16.9% (main 28.9%) | 39 / 40 |
| learned v rules | 40 | 0 | 0 | 12 | 19.5% (main 29.2%) | 19.7% | 40 / 38 |
| rules v planner | 0 | 40 | 0 | 0 | 10.5% | 5.0% | 40 / 0 |
| planner v rules | 4 | 36 | 0 | 6 | 10.0% | 15.4% | 39 / 40 |

The rules' mirror is decided before round 40 in 35 of 40 (main: 36). The
learned side's stuck walkers fell from about 29% to 17% and 20% -- a real
gain, though smaller than the first version of this record claimed (it
compared with T45's 44%, from older controllers). T45's own limit, 5%, is
still not met. The ford counter counts stepping onto a ford, not a whole
crossing.
