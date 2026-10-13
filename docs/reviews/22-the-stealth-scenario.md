# Review: wave/22-the-stealth-scenario

Two fresh contexts reviewed it, one for `ai_perception` and its properties
and one for the game. Neither wrote the code. Both mutated it, and the game
reviewer also *played* it, driving `StealthWorld` from throwaway scripts and
reading every guard's state turn by turn. That found the worst defects, and
no mutation could have: they were behaviour that was legal, and wrong.

## What was reviewed

Commit e3e5d49 on this branch:
- `godot/addons/ai_perception/` (`LineOfSight`, `VisionCone`, `Hearing`,
  `InfluenceMap`);
- `godot/game/stealth/` (`Suspicion` on `ai_fuzzy`, `StealthGuard`,
  `StealthWorld`, `StealthRoom`, the view and the demo scene);
- `test/perception_properties.gd`, which is T14's acceptance;
- the two new gdUnit suites.

## Findings

### A guard that found you turned its back and walked away

When the next cell on its route was occupied, a guard turned a quarter. That
included the case where the cell held the player it was closing in on. In
the default room, a guard reached the player at arm's length, said "sees
you", then turned away. Its suspicion fell from 41 to 19, and it went back
to its round.

### The picture and the words disagreed

A guard perceived from where it stood *before* moving, while the overlay drew
its cone from where it stood *after*. On about a third of the turns near a
guard, the status said "sees you" with the player outside the drawn cone, or
the reverse. Invariant 13 asks the example to show the decision, and this
showed a decision the guard had not used.

### Two guards head on spun in place forever

Each planned straight through the other.

### The line was checked only against itself

Property 2 picks its wall from `cells_between`, so it only proved that
`clear` agrees with `cells_between`. One mutation shifted every sloped line
down a row, so (0,0)→(5,2) passed through (4,3), outside the segment's
bounding box. It passed every gate. A sight that never sees anything also
passed the acceptance command, and so did one that ignores trees.

### Sight slipped between two walls meeting at a corner

Units move in four directions, so a guard could see a player the player
could never walk to.

### The catch did not look

It passed a zero facing. Between neighbours there is nothing to block, so
"can see them" was always true, and an alert guard caught from behind.
Deleting the clause left everything green, and so did dropping the ALERT
requirement or widening the reach to three cells.

### Smaller

- **The cone's edge.** It left out cells lying exactly on it. The diagonal
  measures 45.00000125 degrees.
- **Reach 0.** A cone of reach 0 answered NaN at its own cell.
- **Influence map.** `raise_to` stored NaN. `of_watchers` silently dropped
  watchers whose facing was missing. Its header claimed a maximum it could
  not promise for an off-board watcher.
- **A sprint over the exit** did not count.
- **Hysteresis.** The guard had it only at one of its two thresholds, which
  its header did not admit.
- **After a catch,** the other guards went on moving that turn.
- **The status line** showed the controller's answers but not what it had
  been given.
- **Twelve game rules were deletable with every gate green:**
  - occupancy;
  - facing;
  - the walking noise;
  - light;
  - the rate;
  - and hearing as distinct from sight. That test let a guard spin until it
    *saw* the player.

## What was done about them

Each finding is fixed, with a test or a property that fails without the fix:

- **Moving and perceiving.** A guard moves first and perceives from where it
  ended up, so the cone drawn is the cone used.
- **Next to the player,** a guard faces them and stays.
- **Routes** treat the other guards as walls, so guards pass each other
  wherever there is room.
- **The line** is checked against geometry rather than against itself: one
  cell per step along the longer axis, each within half a cell of the true
  segment. An empty board must see everything. Property 2 plants trees as
  well as walls. Property 4 generates watchers with no reach.
- **Corners.** Two opaque cells meeting at a corner block sight.
- **The cone** compares cosines with a margin of 1e-6. The first fix used
  1e-9, too tight for single-precision `Vector2`, and its own test said so.
- **The catch** uses the guard's facing.
- **Hysteresis.** Leaving ALERT now waits for 60.
- **ALERT is more than a colour now.** An alert guard runs two cells a turn.
- **The status line** shows each guard's four inputs beside the strength of
  each term.

The first version of the corner rule broke symmetry. It walked the line from
the wrong end when asked backwards, and the symmetry property caught it
within the same session.

**32 mutations were re-run against the fixes, and all 32 go red.** That
covers every survivor both reviewers reported and each new rule. Five
survived the first re-run, and each now has a planted case. One of the five
was a redundant branch, and it was deleted. Another passed only because the
board's edge stopped the sprint before the rule did.

### Recorded, not fixed

- **A one-cell corridor.** Two guards meeting head on in one still wait for
  each other. Getting one to back out is cooperative pathfinding, a lesson of
  its own. The default room's rounds never share such a corridor, and a test
  walks them for 200 turns.
- **The default room is not hard.** Walking straight across wins, because
  suspicion takes a few turns to climb. A sentry by the passage makes that
  walk drive a guard to ALERT, and a test pins it, so the number the demo is
  about does rise and fall on the obvious route. Making the room *hard* is
  level design. A walker steering by the danger map was tried, and it was
  caught more often than the straight walker, which says something about
  influence maps used naively.
- **A heard noise** tells the guard the player's exact cell, through walls.
  This is named in `StealthGuard`'s header as a simplification.

### Not proven

- **The manual check is a person's:** walk past a guard at the edge of its
  cone in `make demo-stealth`, and watch whether the suspicion bar chasing
  its tick reads as a decision.
- **Nothing is profiled.** The danger map is rebuilt every frame it is
  shown.
- **The fixes in this record were not reviewed by a fresh context.**

## A trap worth knowing

Two reviewers mutating one checkout at the same time saw each other's
mutations as flaky tests. The next wave should give each reviewer its own
worktree.
