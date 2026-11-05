# The infiltration level: guards that notice, search together and call for help

<!-- doc-meta
half_life: practice
verified_on: 2026-11-05
tier: 2
source: https://github.com/boscocp/game-ai-kit
invalidated_if: the guards' actions, the guard types, the rules or the levels change, and infiltration_properties.gd prints different numbers
teaches: none
-->

> T70's example, built and measured. Where its techniques come from is
> [the stealth AI page](../concepts/stealth-ai.md); what a guard perceives
> and how aware it grows is T69's, on that page's last sections. This page
> says what the level does with them, what was measured, and the one claim
> that is printed rather than held.

## What it is

You sneak in third person (`make demo-infiltration`) past guards who are
T67's agent: each step a guard's eyes and ears give it a percept (T69's
vision shape, body points, light and hearing along the level); its mind
grows aware and remembers; its own belief -- a grid belief map, or a
cloud of particles (T91) -- holds where you may be; and
each decision it scores every action it could take (`guard_actions.json`,
weighed by `ActionChoice`) and does the highest. Patrol, glance,
investigate, search a spot, cover a way out, report by radio, call for
help, raise the alarm, check on a partner gone quiet, engage, flank, take
cover, return: no line of code says which comes first. The team shares out
the work as plain data -- `SearchCoordinator` (who searches which spot, a
cap on who goes to the last known position) and `RoleArbiter` (one flanker,
someone shooting), both new in `ai_teamwork` with Python twins and vectors.

**What is shared follows what was heard** (`GuardSearch`). Guards whose
memories hold the same place -- because they heard the same report or saw
the same sighting -- search together: spots weighed from the freshest
one's belief, the spots any of them has seen off the list, divided so no
two take one. A guard whose knowledge no one shares searches alone from
its own belief. "Searched" is each guard's own, since its knowledge last
changed. The cap on the last known position is per place known. A fight
is shared by every guard in it, so the arbiter weighs them all.

Two hand-made levels (`levels/the_warehouse.json`, `levels/the_courtyard.json`)
in `arena.json`'s shape, built by `BotArena` and walked by `ArenaWalk`, and
a generator for more (`LevelGenerator`), which draws them or, since T95,
declares them and has a constraint solver place them. The same guards, with
no line changed, play all of them.

## Playing it

WASD walk, relative to the camera; the mouse turns the camera (click to
capture it, Esc to free it). C crouches, Z lies prone, Shift sprints
(upright only). G throws a distraction where the crosshair points; E takes
down a guard from behind when the corner says you can; a click shoots.
1 cycles the belief -- off, the grid, the particles -- 2-4 switch the
coordinator, the arbiter and the accumulator; 5 the off-screen halving; 6 the director (T90, below:
the level starts again, with its reserve). Tab watches the next guard, H hides the reasoning,
L the next level (two hand-made, then generated), N again, P pauses, Space
one decision while paused. K, on a generated level, how it is made: drawn,
solved by the constraint solver, or solved with its work replayed (T95,
below).

On screen (invariant 13): over each guard its detection bar with its
phases' thresholds as ticks, its phase and its action, and its role in a
fight; "CALLING FOR HELP" while it calls, and "heard: ..." when a report
reached it. On the floor, each guard's vision zones in its phase's colour;
for a guard looking at you, a line to each of your body points, green
where it sees it and red where a box hides it; the floor's brightness is
the light a guard reads. For the watched guard: its belief as orange cells
(with the particles on, its cloud as dots sized by the share on each cell,
and a white square flashing on each cell its sight just emptied),
its last known position as a grey figure, the spot it was given (purple)
and the spots searched (grey) while it searches, its way out, and where it
is walking. Every sound's reach along the level as blue marks. The radar
shows it all from above; the panel shows the watched guard's every score.

## What changed in T69's pieces, and why

- **Seen means a body there would have been perceived** (T69's review,
  finding 10). A cell counts as searched only when a body lying prone in
  it would give the guard a certainty of at least `seen_threshold` (0.15),
  in that cell's light and hiding -- one ray to the lowest point. Planted
  as T69's reading (a clear line to a standing chest), the belief zeroes
  hidden players' cells; `GuardEyes.seen_cells_by_line` keeps it, named.
- **A phase may have its own decay.** With one decay, a search either
  lingered so long that every glimpse added up to an alert, or faded in a
  fraction of a second after one. Now suspicion fades at the row's 0.08 of
  the peak a second and a search after an alert lingers at 0.02 (about 19
  s), as an envelope's release is set per stimulus in Crysis [Welsh 2013].
  `Awareness`, its Python twin and a new vector say so.
- **Sound floods the 4-connected walk graph, and says so**: a radius is a
  diamond; slow ground is quieter to hear across. No second graph was built
  -- every walk cell here costs one and there are no doors.
- **A sound that goes on is heard while it goes on** (T81, wave 82). The
  owner, playing it: walking behind a guard, it did not seem to hear. The
  player makes a footstep every `noise_every` (0.4 s) and the world steps
  0.1 s; a guard heard a footstep only in the step it arrived, a quarter
  of the time, and its awareness fell in the other three -- standing 1 m
  behind a guard, noticed at 5.8 s or never, 3 m never. Now a sound is
  delivered with how long it holds (the player's steps, their cadence; a
  one-off, none) and heard until it ends or another sound is made -- any
  sound made in a later step replaces it, so a held footstep never hides a
  throw or a takedown; within one step the louder wins. Not T69's
  event lifetime: that is how long an event is remembered (4 s for a
  footstep), and a footstep heard 4 s would raise a guard to alert from one
  step. And a guard's glance now turns to where it heard: it read a sound
  already emptied by the time a guard acts.

## Measured (2026-10-22)

`make test-infiltration` (`infiltration_properties.gd`, about a minute)
drives scripted players over the two hand-made levels and generated levels
1-3, about 100 s since wave 82. Every claim holds and every planted case
is caught:

| claim | planted case |
|---|---|
| help is heard, not shared: every report is heard by exactly the guards with a path within its radius, and every guard that learns a place from a report heard one | a broadcast to every guard |
| a call cut short (its caller downed as it starts) reaches no one -- 12 calls cut (8 before wave 82) | -- |
| the search is divided: among guards who know the same place, no two hold one spot and none holds one they searched -- 325 decisions with two or more searching together | claims off inside the coordinator |
| a search is shared only by what was heard: no guard is sent by a belief it never heard (two calls for help, each heard nearby) | every searcher in one group |
| the belief finds a hidden player sooner, by `MARGIN` = 5 s | a belief that never spreads |
| the quiet route and the loud one | a plain yes-or-no sight test (the accumulator off) |
| the arbiter: one flanker at most; shots only on decisions taken alert; an alert guard able to shoot is answered within reaction + a decision + a shot -- 24 shots fired | two flanks granted; a guard that never shoots; a guard that fires on a glimpse |
| off-screen halving only lowers what a guard hears | the factor as a gain |
| every decision is on the overlay, and done: the record is the action, and the guard walks where it says | a decision taken outside the selector; an act that ignores the action |
| portable: the guards' scripts name no level, and each guard stands at its level's post | a guard script that reads the first level's file |
| a guard hears a player walking behind it (wave 82): standing 1 m and 3 m behind it along the floor, out of its sight, noticed within 2 s; crouched at 1 m, inside the creep's radius, noticed and no sooner than standing; crouched at 3 m, outside it, and prone, never -- 10 guards on five levels | each sound heard for the one step it arrives in (wave 80) |

**Hearing.** A guard frozen where it stands, alone on its level, the
player walking to and fro behind it along the grid's axis nearest straight
behind (3 m away is then 3 m along the floor, the way sound is measured):
standing, noticed -- its phase past unaware -- in 0.5 to 0.9 s at 1 m and
0.9 to 1.8 s at 3 m (the sentry, `heard_rate` 0.4, is the slower);
crouched, in 0.9 to 1.5 s at 1 m, inside the creep's 2 m radius; crouched
at 3 m, outside it, and prone, never -- those two hold by the events' data,
and are kept to catch a change to it. Before wave 82 the same trials gave
5.8 s or never at 1 m, never at 3 m. **Facing matters**: a guard facing
diagonally hears a player 3 m straight behind it 4 m along the floor (sound
is 4-connected, T69's diamond), and a sentry took 4.6 s there -- the
owner's own case is the axis one only when the guard faces along a
corridor. The bound of 2 s
is the upper end of The Last of Us's "around 1 or 2 seconds" to perceive a
seen player [McIntosh 2015]; no source opened gives a time for hearing
footsteps, so the kit takes the same.

**The search.** A staged search (`HidingStage`): the player lies prone at a
hiding place no guard watches, and a radio report says it was seen 8 to 14
steps away, out of sight of it. Over 15 runs (5 levels, 3 seeds), the
player is found on average after **6.9 s** with the belief, **20.8 s**
without it (21.0 s in wave 80's first run, before its review's fixes; 20.8
after them and again in wave 82), and **18.4 s** with a belief that never spreads -- so it is the
spreading, not merely knowing a place, that finds a player.

**The quiet route does not show the light term.** The scripted sneak keeps
out of every zone, so guards blind to light do not alert on its route
either (printed per level); routed through zones where they are dark, the
honest guards alerted on two levels. What the quiet route does show is the
accumulator: a plain yes-or-no sight test alerts on it on both hand-made
levels, from the glimpses the accumulator lets fade.

**The quiet route -- printed on generated levels, not held.** A scripted
player crouched in the shadows finishes the two hand-made levels and
generated levels 2 and 3 with no guard alert; the same route walked
upright and sprinting brings a guard to alert on all five. On generated
level 1 the quiet player is noticed in the dark, the guard investigates and
follows, and the player is caught. That is the guards working and the
scripted sneak -- a heuristic, not a person -- failing, and no number tells
the two apart, so the gate holds the quiet half on the hand-made levels and
prints it on the generated ones.

## Particles against the grid

T91 gave every guard a second belief, `ai_perception`'s `ParticleBelief`
over the same walk graph: two particles a walk cell (936 to 1784 on these
levels), which walk on (0.7), turn (0.2) or stay, weigh 0 where the guard
sees and 0.3 where the player's quietest moving sound -- the creep, 2 m
along the level -- would have reached the guard and it heard nothing, and
are resampled every belief step. Both beliefs are stepped every belief step
and collapse together on a sighting or a report; key 1 chooses which one
the search and the ways out read (`InfiltrationWorld.believed`). The grid
stays the default, so every number above is unchanged.

**Why two a cell.** The first version had 256 particles for levels of 468
to 892 cells: the even start and every reseed then covered a stripe of a
third to a half of the level, and one particle on a cell weighed more than
`GuardWaysOut`'s "likely" cut (twice an even share), so a single stray
particle made a way out anywhere. The review found a staged run that was
never found in 60 s for that reason (9.3 s with the grid). With two a cell
the start and a reseed cover every cell, and a cell needs four particles to
be "likely". The cut was left as it is because the grid's numbers depend on
it.

**The sensor's radius.** The first version used the standing footstep (6
m), but a player creeping makes a sound heard only within 2 m, and a guard
that heard nothing knows only that no one crept that close. The
off-screen halving is left out of the model: it is a rule about the
camera, not something a guard knows of its own ears.

**What it costs.** One guard's belief step on the largest level (892
cells, 1784 particles) measured 1.5 ms, twice a second. The guards step
their beliefs in the same frame, so a level of four guards spends about 6
ms of that frame -- more than a third of a 60 Hz frame, every half second. A game
with more guards should stagger them, or use fewer particles on a coarser
graph (rooms rather than cells).

`make test-infiltration-tracking` (about 40 s, a measurement, not one of
`make check`'s gates) prints every run paired. Measured 2026-10-29:

| scenario | paired runs | grid mean / median | particles mean / median | particles sooner | grid sooner | same |
|---|---|---|---|---|---|---|
| a reported player creeps 8-14 steps to a hiding place, then lies prone (2 hand-made + 20 generated levels, seeds 1-2) | 26 | 4.8 / 1.5 s | 4.7 / 1.5 s | 2 | 1 | 23 |
| T70's staged search, the player never moving (5 levels, seeds 1-3) | 15 | 6.9 / 5.7 s | 7.1 / 5.7 s | 0 | 3 | 12 |

In the first scenario the clock runs from the first step the player lies
hidden and unfound to a guard finding it (within reach, or seeing it at
certainty 0.3), capped at 60 s. One run hit the cap with either belief
(generated 5, seed 1). Of the 44 runs, 18 were not measured in both modes (the run could not be
staged, or no guard ever lost the player); only 2 of the 4 hand-made runs
were measured, so they are not given a row of their own.

**What this shows: no difference worth the name.** The two beliefs found
the player at the same moment in 35 of 41 paired runs. The few that
differ go both ways, by a second or two, and none of them is large enough
to call a direction. **The scenario has little power to tell them apart.**
In 5 of the 26 moving runs the player was found within one belief step
(0.5 s) of lying down, and in most others a guard's glimpse on the way had
already collapsed both beliefs onto the same cell. A scenario where the
belief decides -- a long chase out of sight, several ways the player could
have gone -- is what would separate them; it is not built here.

Measured first with T70's `hide` player (show yourself, sprint to a hiding
place), most runs never reached a hiding place: the player was shot down
or found no way past. That version was dropped. With 256 particles, before
the review, the same tables read 4.5 against 4.8 s and 9.4 against 6.9 s;
the 9.4 was one run at the cap, the stripe above.

What `make check` holds is the wiring, in `belief_switch_test.gd`, where
it is cheap:

- the spot a guard is given, and the way out it covers, come from the
  belief that is on, each checked with the two beliefs collapsed on two far
  apart cells;
- a silent guard would have heard a creep one step away and not one far
  off, and nothing when it heard something.

The measurement's own claim -- at least 20 runs in each mode, and the
particles change some run -- is caught by its planted case, the particles
on with the search wired to the grid (`TrackingClaims.wired_to_nothing`).

## The director (T90)

Key 6 turns on a director after Left 4 Dead's ([the stealth AI page](../concepts/stealth-ai.md#pacing-a-director-over-the-guards-t90)
says where it comes from). Off, the level is exactly T70's. On, the
level's **reserve** -- two more patrols per level, waiting at posts the
start cannot see (`"reserve"` in each level file; the generator draws two
from a generator of its own, so a seed's level is unchanged) -- stands
among the guards, and after every step:

- `DirectorEvents` lists what happened to you: a guard's phase rising
  (`seen` or `heard`), damage (`hurt`), a guard searching within 10 m
  (`search_near`), a guard chasing -- alert and seeing you -- starting or
  stopping (`chase`), your walk to the exit (`exit`);
- `Director` -- the machine, the same as `gameaikit.director.pacing`, held
  to it by `make test-director-vectors` -- turns them into your intensity
  and its phase: building up, holding the peak, fading, relaxing;
- `DirectorOrders` sends a calm reserve guard the player cannot see on its
  beat while building up or holding the peak, and calls a calm one back to
  its post while fading or relaxing, one every 5 s at most. It writes a
  route into the guard and nothing else.

On screen, with the reasoning shown: the strip under the map draws the
last minute of your intensity against the peak line (red) and the fade
line (blue), the phase by name and how many reserve guards are out, and a
yellow mark for each patrol sent and a grey one for each called back; the
map draws a line from where you stood to where that patrol starts.

**Measured** (`make measure-director`, 2026-10-30): three scripted players
-- T70's hiding and quiet ones, and one that lies still at the start and
throws a distraction towards the exit every 45 s -- on the two hand-made
levels and eleven generated ones, five minutes at most each, 39 runs:

| | seconds |
|---|---|
| building up | 2165.4 |
| holding the peak | 119.3 |
| fading | 733.9 |
| relaxing | 86.4 |

33 peaks, 3 relaxes, 71 patrols sent, 4 called back. **The relax is
rare, and the measurement says why**: most runs end within 40 s, the
player caught or out, before a fade can finish; and on two generated
levels the hiding player ends in a stand-off, guards alert and seeing it
for minutes without closing in, which Booth's rule reads as engagement and
so never lets the intensity fall (`peak_fade` 290 s). The one run with the
whole cycle is the distracting player on generated level 10, never found:
three peaks, three relaxes, four patrols sent and four called back -- and
`director_test.gd` holds that run, said as such, so the cycle is held on
the game and not only on the vectors.

The other claims: with the director off the guards are the level's own;
the generator, with the reserve erased, writes for seeds 1-11 the same
levels it wrote before the reserve existed (fingerprints taken from main
at b6b86d1), and a generated reserve takes no guard's place, no exit and
no other reserve cell; every reserve post is out of the start's sight and
every reserve place walkable. Across the hiding and distracting players'
runs on all five levels, each with a planted director it must catch:

- no guard's belief or memory changes when the director acts -- a
  director that also collapses the sent guard's belief onto the player is
  caught;
- every route it gives is the guard's own beat, and a recall leaves none
  -- a director that routes the guard to the player's place, changing no
  belief at all, is caught;
- no patrol is sent in the player's view -- a director that sends the
  waiting reserve guard nearest the player, seen or not, is caught.

Booth's slides were not read again for this wave, as the task's first
step asked: the director is built from the passages T73 quoted from them.

The director's numbers are the kit's own (`spec/director/director.json`):
sight 0.25 and hearing 0.2 a phase, 0.01 a point of damage, 0.02 a second
for a search within 2 m and less further off, decay 0.04 a second, peak
0.7, fade below 0.35, sustain 4 s (Booth: 3-5), relax 30 s (Booth: 30-45)
or 15 m nearer the exit, an order every 5 s. Two were changed by
measuring: a search at first added 0.15 a second, more than the decay
takes, and pinned the intensity at its top while a guard searched beside
a hidden player; hearing at first added 0.1, and a distraction heard by
three guards never reached the peak.

## Levels declared, not drawn (T95)

`LevelGenerator` draws a whole level and keeps it when the exit and every
guard's places can be walked to from the start -- generate and test, up to
40 draws. `LevelConstraints` declares it instead: the seed draws the size
and how many boxes, lamps and hiding places, and for each of them, each
patrol point and the sentry's post, 16 candidate places; those are the
variables of a constraint satisfaction problem, solved by `ai_constraints`
(`docs/techniques/ai_constraints.md`). `level_constraints.json`, beside
`guard_types.json`, names the rules a level is declared with, by their
labels, and the numbers that tune them; the rules themselves are written in
`LevelConstraintRules`. Leave a label out of the file's `constraints` list
and that rule is not asked for:

| condition | kind | how it is asked of a partial level |
|---|---|---|
| boxes 1 m apart; nothing under a box; one guard place a cell; hiding places and lamps (6 m) apart | binary | a table of every pair of candidates, propagated by AC-3 |
| the exit can be walked to from the start | global | refused as soon as the boxes placed so far wall it off |
| every route point and post can be walked to | global | the same, for each place already chosen |
| no post in sight of the start | global | only once every box is placed: a box still to come might hide it |
| a hiding place within 6 steps of each patrol's route | global | counted with the boxes so far, every unplaced hiding place taken as near |
| a dark way (light under 0.3) from the start to the exit | global | refused as soon as the lamps so far light every way through |

The last two are new: a designer's intent, which a draw can only hope for.
The solver checks the global ones on the `LevelSketch`, a grid that knows
only boxes on the ground, and `LevelAudit` then checks every solved level
again on the `InfiltrationLevel` and `BotArena` the game builds. How
independent that second check is depends on the condition:

- **walking** (the exit, the guard places, a hiding place near a route) and
  **light** (the dark way) are measured on the arena's own walk graph and
  the level's own light map, so a sketch that drifted from them would be
  caught; `level_constraints_test.gd` also holds the two walk grids equal,
  cell for cell;
- **sight** is not. The line test is the arena's (`first_block`), but the
  rest -- the guard type's farthest zone, any facing, eyes at 1.6 m, from
  cell centre to cell centre -- is the same reading the solver uses. If that
  reading of "in sight" is wrong, both are wrong together. A guard's real
  vision (its zones, its facing, the player's body points and the light) is
  not asked.

A search that runs into its limit of
400 assignments starts again, up to four times, with its ties broken by
another seed: chronological backtracking can thrash, going back over boxes
that were never the trouble while a post stays in sight. AIMA's cure is
backjumping (6.3.3), which is not in the kit.

**Measured** (`make measure-level-constraints`, seeds 1-200, one run on a
Ryzen 5 9600X, both ways the same seeds):

| | draw and test | constraints |
|---|---|---|
| levels found | 200 | 200 |
| work | 201 draws (one seed needed a second) | 7,090 assignments, 2,304 backtracks, 6 fresh starts; the most on one seed 426 assignments |
| time | under 25 ms a level (the run draws each seed twice, to count the draws) | 136 ms a level; the slowest 2.5 s |
| no hiding place within 6 steps of a patrol route | 107 (54%) | 0 |
| no dark way from the start to the exit | 71 (36%) | 0 |
| a post in sight of the start | 90 (45%) | 0 |

So generate and test pays almost nothing, because it asks almost nothing,
and half of what it keeps breaks a condition it never asked about. The
solver pays several times the time for levels that keep all of them. Seeds
1 to 3 took 25 or 26 assignments -- one a variable -- and no backtrack, AC-3
having crossed out what could not stand; a few seeds take hundreds, and the
totals are mostly theirs. A seed is one level: the tie order, the values
and the restarts are all the seed's.

In the demo, **K** on a generated level cycles: drawn (as before), solved,
solved with the generation view, which replays the solver from its trace
over the screen -- the boxes placed so far grey and the other things as
dots; for the thing chosen next by minimum remaining values, each of its 16
places, white while possible and a red cross where propagation crossed it
out; a list of everything still to place with how many places it has left;
a red ring where a backtrack undid a value; and the last refusal with the
constraint that refused it, with a key at the bottom. The panel's switch
line says the mode (`K level drawn / solved / solved and shown`), and the
overlay's `generator` says the mode and the solver's counts. A seed the
solver gives up on falls back to the drawn level and its drawn name, and
with the view on, the view says so in one line. K on a hand-made level
changes only the mode, for the next generated one.

**The solve runs off the main thread** (T122). A solve takes 120-140 ms a
level on average, and 2.2-2.5 s on the slowest seed of 200 (seed 144).
Until T122 it ran on the main thread when the world was built, with the
window frozen meanwhile. Now `LevelSolving` hands it to `WorkerThreadPool`
as one task: the level being played goes on, the panel's first line says
"solving level 4: this one plays until it is ready", and the scene asks
the pool each physics frame whether it is done. When it is, the world is
built again on the new level, and the view and the solver's counts appear
then. One solve runs at a time: L or K pressed while it runs is answered
when it ends, by solving the level then asked for, if it is another; the
panel names the level that will replace the one played, and says nothing
once none will (K back to drawn, L onto a hand-made level). The last
solved level is still kept by its seed, so N and the second K press do
not solve again. Headless the scene solves inline, unless a test asks for
the pool: `solve_in_background` is off when the display server is
`headless`. **Leaving the scene mid-solve freezes the window** for the
rest of the solve -- up to about 2.5 s on seed 144, 3.7 s measured under
load -- because `_exit_tree` waits for the task: the pool frees a task
only once it is waited for. Handing the task to something that outlives
the scene, an autoload, was judged more machinery than that cost. What the pool and the thread-safety page say, and what was
measured, is [WorkerThreadPool](worker-thread-pool.md).

Measured with `level_solving_measure.gd` (headless, 4.7.2, 2026-11-05),
the longest frame from L until the new level is played:

| seed | drawn | solved inline | solved on the pool | frames until played |
|---|---|---|---|---|
| 3 | 37 ms | 144 ms | 23 ms | 23 |
| 4 | 24 ms | 102 ms | 20 ms | 19 |
| 5 | 34 ms | 196 ms | 25 ms | 32 |
| 144 | 26 ms | 2281 ms | 21 ms | 334 |

The pool's longest frame is the one that builds the world, which a drawn
level costs too. The level is the same either way:
`level_solving_test.gd` compares the data, the assignment, the counts and
the whole trace for seeds 3, 54 and 144, and the measurement fails if the
two ways differ.

## The kit's own numbers

Sourced: the player's walk and sprint speeds (the bot match's), and, from
T69, the phases' thresholds, the rate's range and the off-screen half. Every
other number is the kit's own, set by measuring with the properties, not
taken from any game: in `rules.json`, the crouch and prone rows,
`shot_interval`, `shot_damage`, `shoot_certainty` (0.3), `check_in_every`
(8 s), `quiet_after` (20 s), `call_seconds` (1 s), `help_lasts`,
`report_every` (5 s), `seen_threshold` (0.15), `flank_distance` (7 m), the
whole `decision` row (`noticed_for` 3 s, `known_for` 60 s, `under_fire_for`
2 s, `near_last_known` 2 m, `away_scale` 5 m), `belief.spread` (0.4) and
`belief.particles_per_cell` (2), the
search's `worth`, `travel`, `last_known_cap` (2) and `spot_radius` (2.5 m),
and every knob; in `guard_types.json`, the per-phase decays (0.02 and 0.015
while searching and alert); and in `guard_actions.json`, every weight and
curve.

## Where this was done differently from the task, and why

- **The HUD and map are new** (`InfiltrationHud`, `InfiltrationRadar`), not
  `BotMatchHud` and the bot match's map: both read a `BotMatch`. The body,
  the ground, the boxes and the selector are the bot match's.
- **Crouch and prone are rows of the infiltration example's own
  `rules.json`**, not the bot match's: adding them there would make every
  change to them select the bot match's slow gates. The walk and sprint
  speeds are copied from the bot match's file, and say so.
- **Each guard has its own belief**, not one shared map, and a search is
  shared only among guards who know the same thing: a shared map, or one
  search for all, would hand every guard what one saw, and help would be
  shared, not heard (the wave 80 review).
- **A guard shoots at what it saw**: its percept's place, its chest among
  the points seen, at a certainty of at least `shoot_certainty`. The
  off-screen halving reads the true distance to the player, on the
  engine's side, as T69's technique does: it is a rule about the camera.
- **The off-screen halving is tied to the camera's frustum** in the demo;
  the properties stand in for the camera with "within 10 m of the player".

## Manual check

See `tasks/T70-the-infiltration-level.md`: play both levels quiet and loud,
each technique on and off, and say whether being noticed felt readable and
fair. And `tasks/T91-a-particle-filter-tracks-the-player.md`: with the
particles on (1) and the reasoning shown (H), break line of sight and hide
-- does the cloud follow where you could have gone, thin where a guard
looks, drift from where it listened and heard nothing, and is the guard's
purple cross inside it? And `tasks/T90-a-director-paces-the-infiltration.md`:
with the director on (6) and the reasoning shown, play twice on one seed
and once on a generated level -- do the quiet stretches and the pressure
match the strip, and does a new patrol ever appear where you could see it
arrive?
