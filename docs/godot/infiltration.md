# The infiltration level: guards that notice, search together and call for help

<!-- doc-meta
half_life: practice
verified_on: 2026-10-29
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
a generator for more (`LevelGenerator`). The same guards, with no line
changed, play all of them.

## Playing it

WASD walk, relative to the camera; the mouse turns the camera (click to
capture it, Esc to free it). C crouches, Z lies prone, Shift sprints
(upright only). G throws a distraction where the crosshair points; E takes
down a guard from behind when the corner says you can; a click shoots.
1 cycles the belief -- off, the grid, the particles -- 2-4 switch the
coordinator, the arbiter and the accumulator; 5 the off-screen halving. Tab watches the next guard, H hides the reasoning,
L the next level (two hand-made, then generated), N again, P pauses, Space
one decision while paused.

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
over the same walk graph: 256 particles that walk on (0.7), turn (0.2) or
stay, weigh 0 where the guard sees and 0.3 where it would have heard a
footstep (the event's 6 m along the level) and heard nothing, resampled
every belief step. Both beliefs are stepped every belief step and collapse
together on a sighting or a report; key 1 chooses which one the search
reads (`InfiltrationWorld.believed`). The grid stays the default, so every
number above is unchanged.

`make test-infiltration-tracking` (about 40 s) measures it two ways, with
the same guards, decisions and seeds:

**A reported player that creeps off and hides.** A radio report says the
player was seen at a place 8 to 14 steps from a hiding place no guard
watches (`HidingStage`'s places); it creeps along the walk there and lies
prone. From the first step it lies hidden and unfound, the clock runs until
a guard finds it -- within reach, or seeing it at certainty 0.3 -- or 60 s
pass. The two hand-made levels and generated levels 1 to 20, seeds 1 and 2
(measured 2026-10-29):

| levels | belief | runs | mean | median | found within 60 s |
|---|---|---|---|---|---|
| hand-made | grid | 2 | 6.5 | 10.5 | 2 |
| hand-made | particles | 2 | 6.5 | 10.5 | 2 |
| generated | grid | 24 | 4.6 | 1.4 | 23 |
| generated | particles | 25 | 4.4 | 1.1 | 24 |
| all | grid | 26 | 4.8 | 1.5 | 25 |
| all | particles | 27 | 4.5 | 1.4 | 26 |

Of the 26 runs both measured, the particles found the player sooner in 3,
the grid in none, and 23 took the same time to the step. (The other runs
could not be staged, or no guard ever lost the player; one more lost it
with the particles on.) **T70's staged search** -- the player already
lying hidden when the report arrives, not moving at all -- the other way:
found after **6.9 s** with the grid and **9.4 s** with the particles on
average (5 levels, 3 seeds).

So: **not clearly sooner.** When the player moves after it is lost, the
particles' walking model helps a little, a few runs and never against it.
When it has not moved, a model that says "a person keeps walking" spreads
the cloud away from where the player lies, and the grid's slower, even
spread is closer to the truth. Most runs are decided by a glimpse on the
way, which collapses both beliefs alike. Measured first with T70's `hide`
player (show yourself, sprint to a hiding place): most runs never reached
a hiding place -- the player was shot down or found no way past -- and are
not a measure of the search; that version was dropped.

The gate holds what can be held: at least 20 runs lost the player in each
mode, and the particles changed at least one run. Planted: the particles on
and stepped, the search wired to the grid (`TrackingClaims.wired_to_nothing`),
which must change none -- caught.

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
`belief.particles` (256), the
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
purple cross inside it?
