# The infiltration level: guards that notice, search together and call for help

<!-- doc-meta
half_life: practice
verified_on: 2026-10-22
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
grows aware and remembers; its own belief map holds where you may be; and
each decision it scores every action it could take (`guard_actions.json`,
weighed by `ActionChoice`) and does the highest. Patrol, glance,
investigate, search a spot, cover a way out, report by radio, call for
help, raise the alarm, check on a partner gone quiet, engage, flank, take
cover, return: no line of code says which comes first. The team shares out
the work as plain data -- `SearchCoordinator` (who searches which spot, a
cap on who goes to the last known position) and `RoleArbiter` (one flanker,
someone shooting), both new in `ai_teamwork` with Python twins and vectors.

Two hand-made levels (`levels/the_warehouse.json`, `levels/the_courtyard.json`)
in `arena.json`'s shape, built by `BotArena` and walked by `ArenaWalk`, and
a generator for more (`LevelGenerator`). The same guards, with no line
changed, play all of them.

## Playing it

WASD walk, relative to the camera; the mouse turns the camera (click to
capture it, Esc to free it). C crouches, Z lies prone, Shift sprints
(upright only). G throws a distraction where the crosshair points; E takes
down a guard from behind when the corner says you can; a click shoots.
1-4 switch the belief, the coordinator, the arbiter and the accumulator; 5
the off-screen halving. Tab watches the next guard, H hides the reasoning,
L the next level (two hand-made, then generated), N again, P pauses, Space
one decision while paused.

On screen (invariant 13): over each guard its detection bar with its
phases' thresholds as ticks, its phase and its action, and its role in a
fight; "CALLING FOR HELP" while it calls, and "heard: ..." when a report
reached it. On the floor, each guard's vision zones in its phase's colour;
for a guard looking at you, a line to each of your body points, green
where it sees it and red where a box hides it; the floor's brightness is
the light a guard reads. For the watched guard: its belief as orange cells,
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

## Measured (2026-10-22)

`make test-infiltration` (`infiltration_properties.gd`, about a minute)
drives scripted players over the two hand-made levels and generated levels
1-3. Every claim holds and every planted case is caught:

| claim | planted case |
|---|---|
| help is heard, not shared: every report is heard by exactly the guards with a path within its radius | a broadcast to every guard |
| a call cut short (its caller downed as it starts) reaches no one | -- |
| the search is divided: no two guards hold one spot; every spot in sight is marked | claims off inside the coordinator |
| the belief finds a hidden player sooner, by `MARGIN` = 5 s | a belief that never spreads |
| the quiet route and the loud one | guard types blind to light alert on the quiet route |
| the arbiter: one flanker at most; shots only on decisions taken alert; an alert guard able to shoot is answered within reaction + a decision + a shot | two flanks granted |
| off-screen halving only lowers what a guard hears | the factor as a gain |
| every decision is on the overlay | a decision taken outside the selector |
| portable: the guards' scripts name no level | posts read from the first level's file |

**The search.** A staged search (`HidingStage`): the player lies prone at a
hiding place no guard watches, and a radio report says it was seen 8 to 14
steps away, out of sight of it. Over 15 runs (5 levels, 3 seeds), the
player is found on average after **6.9 s** with the belief, **21.0 s**
without it, and **18.4 s** with a belief that never spreads -- so it is the
spreading, not merely knowing a place, that finds a player.

**The quiet route -- printed on generated levels, not held.** A scripted
player crouched in the shadows finishes the two hand-made levels and
generated levels 2 and 3 with no guard alert; the same route walked
upright and sprinting brings a guard to alert on all five. On generated
level 1 the quiet player is noticed in the dark, the guard investigates and
follows, and the player is caught. That is the guards working and the
scripted sneak -- a heuristic, not a person -- failing, and no number tells
the two apart, so the gate holds the quiet half on the hand-made levels and
prints it on the generated ones.

## Where this was done differently from the task, and why

- **The HUD and map are new** (`InfiltrationHud`, `InfiltrationRadar`), not
  `BotMatchHud` and the bot match's map: both read a `BotMatch`. The body,
  the ground, the boxes and the selector are the bot match's.
- **Crouch and prone are rows of the infiltration example's own
  `rules.json`**, not the bot match's: adding them there would make every
  change to them select the bot match's slow gates. The walk and sprint
  speeds are copied from the bot match's file, and say so.
- **Each guard has its own belief**, not one shared map: a shared map would
  hand every guard what one saw, and help would be shared, not heard. A
  guard's belief takes another's only from a report it heard.
- **The off-screen halving is tied to the camera's frustum** in the demo;
  the properties stand in for the camera with "within 10 m of the player".

## Manual check

See `tasks/T70-the-infiltration-level.md`: play both levels quiet and loud,
each technique on and off, and say whether being noticed felt readable and
fair.
