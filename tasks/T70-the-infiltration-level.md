# T70 — The infiltration level: guards that search together and call for help

Size: L · Prereqs: T50, T66, T67, T69 · Files: `godot/game3d/infiltration/`, `godot/game3d/assets.json`, `godot/addons/ai_teamwork/`, T67's selector addon, `python/gameaikit/teamwork/`, `spec/vectors/teamwork/`, `godot/test/infiltration/`, `modules/infiltration.json`, `Makefile`, `docs/godot/infiltration.md`

## Goal

The second half of the owner's T52 (2026-10-21): bots against the player
with an optional stealth, "inspirado no assassins creed, splinter cell e
metal gear". It was numbered T52.2 at first, renumbered T70 because `make
wave` reads only whole numbers. T69 built what a guard perceives, how aware
it is and what it knows; this task puts guards made of it in a level, in
third person, against a person.

The guards are T67's agent: "o bot é um agente que deve perceber o mundo e
suas acoes e decidir o que fazer pra atingir seu objetivo ... em outro
mapa, outro contexto com outros modelos 3d ele deve saber se virar". Alert
phases, the search and calling for help are each a weighed decision -- not
an if/else chain in the demo -- and the same guards, with no line changed,
play a second level and the ones the test makes.

The player can go in shooting, or stay unseen; both are the same guards.

## Decided (2026-10-21)

- **The research is [`docs/concepts/stealth-ai.md`](../docs/concepts/stealth-ai.md)**
  (wave 74). For this half: the search runs on the shared belief and a
  coordinator of claimed spots, hidden from the likely cells and marked off
  by sight [Welsh 2015; McIntosh 2015]; how many go to the last known
  position is capped [Welsh 2015; Miles 2013]; calling for help, a body and
  a partner gone quiet are events perceived like any other [Miles 2013;
  Walsh 2015]; once a fight starts, a role arbiter keeps at least one
  shooter and a single flanker [McIntosh 2015]; and the player must read it
  all -- a detection bar, the last known position as a silhouette, a radar
  map [Walsh 2015; Martin 2009; Wikipedia, MGS 1998].
- **Third person**, the owner's confirmation.
- **Reuse the bot match** wherever it fits, the owner's instruction. These
  are T66's, merged in wave 71 and on main: levels as JSON like
  `arena.json` and `yards.json`; `BotArena`'s boxes, platforms and stairs,
  and `ArenaWalk`'s heights; `BotBody`, the humanoid (Kenney's Animated
  Characters Survivors, referenced through `assets.json`); `BotMatchHud`;
  the shot's ray logic, adapted from first person; the sprint rule in
  `rules.json`. T67's selector and percept record are wave 72's, not yet
  merged -- hence the prerequisite.
- **Invariant 2**: `ai_teamwork` depends on nothing, so the search
  coordinator and the arbiter take the sight lines, the belief and the
  candidate spots as data, computed by `infiltration` with `ai_perception`
  and `ai_search`.
- **Metal Gear is taken as design only**: the phases as pacing, guards who
  radio for help and a radio that can be cut, reinforcements that sweep
  where the player hid, the radar, and levels built of places to hide. No
  claim here is about how its AI works -- no developer source on that
  exists.
- **A single-player level, not a match**, so nothing is mirrored and T51's
  fairness gate does not apply. The gates are claims about the guards; a
  person judges whether being seen felt fair.
- **Off-screen hearing halved, on by default**, a named difficulty knob
  shown on the overlay (T69's factor, tied here to the camera) [Walsh 2015;
  Reparaz 2024].

## Steps

1. **Levels as data**, `infiltration/levels/*.json` in `arena.json`'s
   shape, built by `BotArena` and walked by `ArenaWalk`: boxes, platforms,
   stairs, plus T69's light per cell, hiding spots, and the guards' posts
   and routes. Two hand-made levels, built of places to hide; and a seeded
   generator for a third. Nothing in the guards' code names a level or a
   cell.
2. **The guard's actions, in T67's selector**: hold the post or walk the
   route, glance, investigate a point, search a spot, cover a way out of
   the belief's region (computed from the walk graph, not marked by hand),
   report by radio, call for help, raise the alarm, engage, take cover,
   return. Each scored from T69's percepts, awareness, phase reading and
   belief; weights in data. A cautious and an aggressive search are what
   the scores do at low and high awareness, not two code paths.
3. **Cooperation, in `ai_teamwork`**, with Python twins and vectors, its
   inputs plain data: a search coordinator -- spots hidden from the belief's
   likely cells, claimed on T51's claims, marked off when any guard's sight
   line reaches them; a cap from data on how many go to a last known
   position; the role arbiter once a fight starts, requests granted and
   refused on screen.
4. **Help is heard.** A call or a radio report is a T69 event the hearing
   carries, so who learns it is who heard it; a call cut short (the caller
   downed) is not sent; reinforcements are guards who heard the alarm,
   choosing to come. A partner gone quiet -- in earshot for a while, then
   silent [Walsh 2015] -- is an event too, and so is a body.
5. **The player, third person**: `BotBody` driven by a person; walk, the
   sprint rule from `rules.json`, and crouch and prone added as rows of the
   same file, each with its noise and visibility; a distraction to throw; a
   takedown from behind, which leaves a body; the bot match's rifle, its
   shot's ray adapted to an over-the-shoulder camera. The primitive
   fallback when nothing is downloaded.
6. **The overlay** (invariant 13), on `BotMatchHud` and the bot match's
   map: each guard's detection bar with its thresholds and phase; its
   vision zones and the body points it saw; the last known position as a
   silhouette; the belief as a heat map; claimed and searched spots; heard
   events as rings along the graph; every action's score for the guard
   under the cursor; a 2D radar map with all of it; and a line saying when
   off-screen hearing is halved. Each technique switchable: belief off
   (guards walk to the last known position and give up), coordinator off
   (each searches alone), arbiter off (everyone who can shoot does),
   accumulator off (a plain yes-or-no sight test).
7. **Difficulty as named knobs**: reaction, turn rate, aim error, the
   awareness rates, the belief's diffusion steps (Dishonored 2's step limit
   was its difficulty [Couvidou 2021]), and the off-screen halving.
8. **Measure and write it down**: `infiltration_properties.gd` below,
   `make test-infiltration`, `make demo-infiltration`,
   `modules/infiltration.json`, `docs/godot/infiltration.md`, every claim
   with its planted case.

## Acceptance

```bash
make test-infiltration
make test-teamwork-vectors
make test-godot-some SUITES="test/infiltration test/ai_teamwork"
python3 scripts/check_addon_deps.py
python3 scripts/check_modules.py
python3 scripts/check_readability.py
python3 scripts/check_no_assets.py
python3 scripts/check_demos.py
```

```bash
./scripts/godot --headless --path godot -s res://test/infiltration/infiltration_properties.gd
```

`infiltration_properties.gd` drives scripted players over the two
hand-made levels and seeded generated ones, with the guards' code
unchanged, and holds each claim with a planted case it must reject
(invariant 4):

- **Help is heard, not shared.** A guard out of earshot of a call or a
  report learns nothing from it; a call cut short reaches no one. Planted:
  a broadcast to every guard.
- **The search divides the area.** No two guards claim one spot; a spot any
  guard's sight line reached is marked. Planted: claims switched off inside
  the coordinator. With the belief on, guards reach the player's hiding
  place in fewer steps on average than with it off, by a margin stated in
  the header. Planted: a belief that never diffuses, which must lose the
  margin.
- **The quiet route and the loud one.** A seeded player in shadow, crouched
  and out of the zones finishes a level without any guard reaching alert;
  the same route walked upright and sprinting does reach it -- so the
  first claim is not passing on guards that perceive nothing. Planted: a
  guard type with no light term in its rate, which must alert on the quiet
  route.
- **The arbiter.** Once any guard is in the alert phase, at most one guard
  holds the flanker role, and within a stated reaction window of a guard
  in the alert phase seeing the player, at least one guard is shooting. A
  glimpse below alert starts no shooting. Planted: two flank requests both
  granted.
- **Off-screen halving only lowers**, in the level: no guard reaches a
  higher awareness with it on than off, on the same seeded run; the overlay
  says it is on whenever it is. Planted: the factor applied to guards on
  screen as a gain.
- **Every decision is on the overlay.** On every frame a guard chose, the
  overlay's record holds the chosen action and every candidate's score.
  Planted: a decision taken outside the selector.
- **Portable.** Every claim above holds on the second level and on the
  generated ones; the guards' scripts name no level file and no cell.
  Planted: a guard that reads a post's position from the first level's
  file, which the second level and the generated ones must break.

## Manual check

Play both levels in third person twice, quiet and loud, with each technique
on and off. When a guard notices you, can you tell why from its bar, its
zones and the points of your body it saw? When it searches, can you see
where it thinks you are, and does hiding somewhere it has just looked feel
like a choice you made? Does a guard who calls for help sound like one, and
do the ones who did not hear it go on as if nothing happened? Turn the
off-screen halving off: is being heard by a guard you cannot see fairer or
less fair, and which way would you leave it?

## Done in wave 80 (2026-10-22)

What was built differs from the steps above in these places, each on
purpose; `docs/godot/infiltration.md` has the numbers.

- **Each guard has its own belief**, not one shared map: a shared map
  would hand every guard what one saw, and help would be shared, not
  heard. A guard takes another's knowledge only from a report it heard.
- **"Seen" is "a hidden body there would have been perceived"** (T69's
  review, finding 10): a prone body, in that cell's light and hiding, at
  the rules' `seen_threshold`. T69's reading is kept as
  `GuardEyes.seen_cells_by_line`, named, for what it gets wrong.
- **Sound floods the 4-connected walk graph**, and the headers say so: a
  radius is a diamond. No second graph -- every cell costs one, and there
  are no doors.
- **A phase may set its own decay** (`Awareness`, its twin and a vector):
  with one decay, a search after an alert faded in a fraction of a second
  or every glimpse added up to an alert.
- **A radio report is re-sent at most every `report_every` seconds**: a
  guard that keeps seeing reported every decision, and its hearers' fear
  ran away with them.
- **The HUD and radar are new**, not `BotMatchHud` and the bot match's
  map, which read a `BotMatch`. **Crouch and prone are rows of this
  example's `rules.json`**, not the bot match's, so a change to them does
  not select the bot match's slow gates.
- **The belief's margin is measured on a staged search** (`HidingStage`):
  the player hidden, a radio report placing it 8-14 steps away out of
  sight. A player run at guards to get seen was shot before it hid.
- **The quiet route is held on the hand-made levels and printed on the
  generated ones**: on generated level 1 the guard notices the scripted
  sneak in the dark and follows it, and no number tells the guards
  working from the test player failing.

Measured: every claim of `infiltration_properties.gd` holds and every
planted case is caught, in about a minute. A hidden player is found
after 6.9 s with the belief, 21.0 s without, 18.4 s with a belief that
never spreads (15 runs each). The quiet route finishes with no guard
alert on four of the five levels; walked loudly it brings a guard to
alert on all five. Screenshots were taken windowed before any claim
about the view; the manual check is still the owner's.
