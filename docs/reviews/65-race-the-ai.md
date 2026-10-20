# Review: wave/65-race-the-ai

One fresh context reviewed it at the wave's first commit, with no
permission to edit, commit or run `make check`, `make check-affected` or
`make test-godot` while `make check` ran beside it. Its probes ran from the
job's scratch directory by absolute path, so none was written under
`godot/`.

**Verdict: do not merge yet** -- the art manifest test would fail, and
following without passing made the leader impossible to pass: in watch
mode it turned T23's ladder upside down, in race mode whoever led into the
first corner won. The honest-twin cheat check was green through both,
because the twin runs the same race rules.

## What was reviewed

- `CLAUDE.md`, T59, T23 and the wave 64 review record, and the whole diff:
  `RacingHumanDriver`, `RacingRace`'s grid, bump and following, the wider
  track, the views, the minimap, the text, the art and `LICENCES.md`.
- Run: the racing suite, both racing gates, the overlay walk, the lints;
  six probes (watch mode by grid order, slot fairness, a parked car, side
  contact, three-car contact, a shortcut across the grass), windowed
  screenshots, and the art's sha256s against the pack.

## Findings

Each is followed by what was done about it.

1. **Confirmed: `Art.every_path()` gained nine paths the generator's
   manifest lacks**, so the menu module's art test would fail. *Fixed*:
   the racing pictures are not generated, so they stay out of
   `every_path` (said in its comment) and `Art.racing_paths()` lists them;
   the racing suite loads each.
2. **Confirmed: following without passing inverted the ladder in watch
   mode** -- easy, normal, hard finished in that order from that grid --
   and **(3) in race mode the AI could never pass**: a car driving like
   easy beat hard from the front, and a parked car stopped hard for good.
   *Fixed*: a blocked AI moves its aim `PASS_OFFSET` metres to the side of
   the line with more tarmac and keeps a crawl behind a stopped car, so it
   draws alongside and goes by. Measured on seeds 23, 5 and 7: watch mode
   finishes hard, normal, easy every time; hard passes easy from behind; a
   parked car is passed. A test holds the sidestep, and another that
   `racing_race.gd`'s code never names a level or a knob -- the part the
   twin cannot see, now said in the cheat check's header.
4. **Confirmed: the grid favours the left of the front row**, which was
   always yours: two identical drivers, the right one about 1.3 s behind
   over three laps. *Done*: the AI takes the favoured slot and you the
   other, and the demo says so -- a second to win back, not one handed to
   you.
5. **Confirmed: a car 3.5-4.8 m to the side was hit and not followed, and
   a glancing touch set the whole speed to the other car's.** *Fixed*: the
   follow width is the contact width plus half a metre, and a bump takes
   away only the speed closing on the other car, shared by how squarely
   each points at it. A test holds that a glancing touch costs little.
6. **Confirmed: three cars could end a step overlapping.** *Fixed*: four
   passes over the pairs; a three-car test.
7. **Confirmed: the bump test could not tell the rule from simpler wrong
   ones.** *Fixed*: it runs both ways round; a mutation that slowed the
   wrong car now fails two tests.
8. **Confirmed: Tab after A hid your car.** *Fixed*: `restart` clears it.
9. **Confirmed: the banner sat on your car.** *Fixed*: at the top.
10. **Confirmed: before the start the AI's aim line ran to (0, 0), and the
    start line looked like the braking bar.** *Fixed*: `RacingRace.plan`
    has every driver decide once before the count; the start line is
    chequered.
11. **Confirmed: '.' stepped the race during the count, without your
    keys.** *Fixed*.
12. **Confirmed: places could contradict the banner.** *Fixed*:
    `RacingDemoText.place` ranks by finish time, then distance, then car
    number, for any number of cars.
13. **Confirmed (small): a long cut across the infield is credited.**
    *Said*: the race's header gives the measured 0.4 s for 145 m of grass
    instead of claiming the grass always makes it not pay.
14. **Plausible: wording and hard-coded bounds.** *Fixed*: the grid is
    described as it is (the front row on the line); the minimap and the
    watch camera take their bounds from the track. STATUS lists T59 done.

What held: the lap times (38.02 / 35.90 / 34.44 s), no level leaving the
tarmac, the lookahead claim, every sha256 against the pack, lap counting
through bumps, no tunnelling, and the human's car being a plain
`RacingCar` on the race's physics.

## The second review, of the fixes

A second fresh context reviewed the fix commit under the same limits,
probes by absolute path, nothing under `godot/`. **Verdict: do not merge
yet** -- passing held only where it had been measured.

1. **Confirmed: a car stopped on the line still stopped easy and hard for
   good** -- pure pursuit asked a car at rest for no turn, and the follow
   distance (20 m) was far short of the braking distance (112 m).
2. **Confirmed: the pass had no memory** -- it flipped on and off at the
   edge of the follow cone, and hard trailed a 20 m/s car for a whole race.
3. **Confirmed: the pass side flipped mid-pass** as a corner approached,
   sending a car across and onto the grass.
4. **Confirmed: watch mode still inverted on one seed of six.**
5. **Confirmed: a bump took speed on every one of the four passes.**
6. **Confirmed: with three or four cars the outcome depended on numbering.**
7. **Confirmed: "the right slot costs a second" was wrong** -- alone it
   costs nothing; being behind into the corner does.
8. **Confirmed: the "names no level" test guards less than it said**, and
   passing lives in the driver, which it does not read.

And the owner raced it, with the four asks in T59's step 7.

*Done about them*: passing is a manoeuvre with state -- a side chosen once,
away from the other car unless that side has no room, held until the way
has been clear a second, a few metres a second over the car it passes, the
aim held on the tarmac; the follow distance is the braking distance plus
20 m; at a crawl a car still turns. Collisions became the owner's: equal
masses trade velocity along the line between them, on the first pass only
-- which also closes 5. Measured after (T59's record): six seeds in order,
parked and slow cars passed from either slot. 6 is said rather than
removed: a chain of three is settled pair by pair. 7 and 8 are reworded to
what holds; the level test also refuses the human driver's name. The grip
rule in the cheat check reads what the car's tyres held on its own step,
since a collision now changes speed after it.

## What was done about them

All fourteen of the first review, as above, in the commit after it; the
second review's and the owner's in the commit after that. The racing suite
(18 cases), both racing gates, the overlay and menu walks, the menu suite
(30 cases, the art manifest test among them) and the lints were rerun
green, and screenshots taken in a window of the start and of a race in
its last lap. `make check-affected` -- all of `make check`, the Makefile
having changed -- runs before the merge.
