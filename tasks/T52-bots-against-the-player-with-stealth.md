# T52 — Bots against the player, with an optional stealth

Size: L · Prereqs: T49, T50, T14, T67 · Files: `godot/game3d/infiltration/`, `godot/addons/ai_perception/`, `godot/addons/ai_teamwork/`, `godot/addons/ai_search/`, T67's selector addon, `python/gameaikit/`, `spec/vectors/`, `godot/test/infiltration/`, `modules/infiltration.json`, `docs/godot/infiltration.md`, `docs/concepts/stealth-ai.md`

## Goal

The owner, on 2026-10-21, in their words: bots against the player with an
optional stealth, "inspirado no assassins creed, splinter cell e metal
gear", applying what T67 learns. And the rule that holds for every example:

- "aqui devemos sempre trabalhar a autonomia e fazer o mínimo de if else
  fixo na demo, pra ser uma IA genérica";
- "o bot é um agente que deve perceber o mundo e suas acoes e decidir o que
  fazer pra atingir seu objetivo ... em outro mapa, outro contexto com
  outros modelos 3d ele deve saber se virar".

So the guards are T67's agent with other percepts and other actions. Alert
phases, the search and calling for help are each a weighed decision from
what the guard perceived and a technique of the kit -- not an if/else chain
in the demo -- and the same guards, with no line changed, play a second
level and a third one the test makes.

The player can go in shooting, or stay unseen. Both are the same guards:
stealth is what the guards do while their awareness is low, combat what
they do when it is high.

## Decided (2026-10-21)

- **The research is [`docs/concepts/stealth-ai.md`](../docs/concepts/stealth-ai.md)**
  (wave 74), 20 sources each opened; no developer source on Metal Gear
  Solid's guard AI could be found, and the page says which sources are
  articles about talks. In one paragraph: perceiving and being aware are
  two things -- a vision shape that widens then narrows, read as certainty
  [Walsh 2015; McIntosh 2015; Rabin 2015], light at the player's feet
  [Leonard 2003], sound along the level, not through walls [Walsh 2015;
  Miles 2013]; awareness accumulates and decays through every intermediate
  value [McIntosh 2015; Leonard 2003]; the phases are thresholds on it, in
  data [Welsh 2013], with a caution that lasts after an alert [Alexander
  2009; Ubisoft 2024]; a guard knows only what it perceived or heard
  [McIntosh 2015]; the search runs on a shared belief map and a coordinator
  of claimed spots [Isla 2013; Welsh 2015]; calling for help, a body and a
  partner gone quiet are events perceived like any other [Miles 2013;
  Walsh 2015]; and the player must be able to read all of it.
- **A single-player level, not a match.** Nothing here is mirrored, so
  T51's fairness gate does not apply. The level's gates are claims about
  the guards instead (Acceptance), and a person judges whether being seen
  felt fair (Manual check).
- **The guards are T67's agent.** Percepts in one record; a weighed
  selector chooses among actions; every action's score is on the overlay.
  The alert phase is a *reading* of the awareness number against data
  thresholds, which the selector takes as an input -- there is no
  transition table in the demo.
- **No cheat in what a guard knows.** Welsh's 2-3 s of "knowing" and his
  weight towards the player's real position, and The Last of Us's 5 m rule,
  are left out [Welsh 2015; McIntosh 2015]; the belief map does their job.
- **Left for later**: crowds and disguises (Assassin's Creed, Hitman: no
  source describes how they are computed), hand-marked areas and chokes,
  learned guards (invariant 6).

## Steps

1. **Read T67's result first.** Use its selector and its percept record
   as they are; if a guard needs something they lack, add it there with its
   twin and vectors, not a second selector here.
2. **The level as data.** `infiltration/levels/*.json`: walk cells with a
   floor height (T66's), opacity, light per cell, hiding spots (cells that
   block sight), and the guards' posts and routes. Two hand-made levels, and
   a generator for a third, seeded. Nothing in the guards' code names a
   level or a cell.
3. **Perception, in `ai_perception`.** A vision shape that widens then
   narrows, with a certainty per zone; rays to a few points on the body,
   how many must be clear a stance rule; light sampled at the player's
   feet; motion as a modifier. Hearing along the walk graph -- a flood from
   the source, over `ai_search`'s port -- replacing straight-line
   `Hearing` for this level, its header updated. Typed events (footstep,
   shot, thrown object, body, open door, a guard's call) as data rows with
   a sense, a priority, a radius and a lifetime. Python twin and vectors.
4. **Awareness, in `ai_perception`.** One number per guard and stimulus:
   it rises at a rate from an `ai_fuzzy` controller of certainty, light,
   motion and distance (T14's suspicion, grown from a grid to rays), and
   falls through every intermediate value; thresholds as fractions of the
   peak; a caution floor that stays raised for a stated time after an
   alert. Per guard type in data, as Crysis does. Twin and vectors.
5. **Knowledge, in `ai_perception`.** Each guard's memory: where and when it
   last perceived the player, and from what. A shared belief map over the
   walk graph: seeded at a perceived position, diffusing each step along
   the graph, zeroed wherever any guard sees. Written only from a guard's
   percepts and from reports it heard. Twin and vectors.
6. **Decisions, in T67's selector.** The guard's actions: hold the post or
   walk the route, glance, investigate a point, search a spot, cover a way
   out of the belief's region, report by radio, call for help, raise the
   alarm, engage, take cover, return. Each scored from the percepts, the
   awareness, the phase reading and the belief; weights in data. A cautious
   and an aggressive search are what the scores do at low and high
   awareness, not two code paths.
7. **Cooperation, in `ai_teamwork`.** A search coordinator: spots hidden
   from the belief's likely cells, generated from the level; claimed, so no
   two guards take one; marked off by any guard that sees it. A cap from
   data on how many go to a last known position. A call or a radio report
   is a sound event the hearing carries, so who learns it is a matter of
   who heard it; a call cut short is not sent. A partner gone quiet (in
   earshot for a while, then silent) is an event too. Once a fight starts,
   the role arbiter: at least one shooter, a single chosen flanker,
   requests granted and refused on screen [McIntosh 2015].
8. **The player.** Third person; walk, run, crouch and prone, each with its
   noise and visibility; a distraction to throw; a takedown from behind,
   which leaves a body; the T51 rifle for those who go in shooting. Models
   from an open pack in `assets.json`, with the primitive fallback.
9. **The overlay** (invariant 13). Each guard's detection bar with its
   thresholds and phase; its vision shape and the body points seen; the
   last known position as a silhouette; the belief as a heat map; claimed
   and searched spots; heard events as rings along the graph; every
   action's score for the guard under the cursor; and a 2D radar map with
   all of it. Each technique switchable: belief map off (guards walk to the
   last known position and give up), coordinator off (each searches alone),
   arbiter off (everyone who can shoot does), accumulator off (a plain
   yes-or-no sight test).
10. **Difficulty as named knobs**: reaction, turn rate, aim error, the
    awareness rates, the belief's diffusion steps (Dishonored 2's step
    limit was its difficulty [Couvidou 2021]). Off-screen hearing halved
    [Walsh 2015] is a knob too, off by default, and the HUD says when it
    is on.
11. **Measure and write it down**: `infiltration_properties.gd` below;
    `modules/infiltration.json`; `docs/godot/infiltration.md`, every
    claim with its planted case.

## Acceptance

```bash
make test-infiltration
make test-perception-vectors
make test-teamwork-vectors
make test-godot-some SUITES="test/infiltration test/ai_perception test/ai_teamwork"
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
hand-made levels and over seeded generated ones, with the guards' code
unchanged, and holds every claim below with a planted case it must reject
(invariant 4):

- **Nothing known that was not perceived.** No guard's awareness rises on a
  frame where no ray reaches the player and no event reaches it along the
  graph; a guard's memory and the belief change only from a percept or a
  heard report. Planted: a guard that reads the player's true position.
- **Awareness follows exposure.** With all else fixed, the awareness
  reached after a stated time does not fall as the player comes nearer,
  into light, or moves; in darkness and outside every shape it does not
  rise. Planted: a rate with the light input inverted.
- **The phases follow the thresholds.** On every frame each guard's phase
  is the one its awareness and the data's fractions give; falling, it
  passes through every phase in between; after an alert it stays at or
  above the caution floor for the stated time. Planted: a threshold read
  from the wrong row.
- **Help is heard, not shared.** A guard out of earshot of a call or a
  report learns nothing from it; a call cut short reaches no one. Planted:
  a broadcast to every guard.
- **The search divides the area.** No two guards claim one spot; a spot any
  guard saw is marked; the belief is zero in every cell a guard sees. With
  the belief map on, guards reach the player's hiding place in fewer steps
  on average than with it off, by a margin stated in the header.
- **The quiet route and the loud one.** A seeded player in shadow, crouched
  and out of the shapes finishes a level without any guard reaching alert;
  the same route walked upright and running does reach it -- so the first
  claim is not passing on guards that perceive nothing.
- **The arbiter**, once a fight starts: at most one flanker, and on every
  frame where any guard can see the player, at least one is shooting.
- **Every decision is on the overlay.** On every frame a guard chose, the
  overlay's record holds the chosen action and every candidate's score.
  Planted: a decision taken outside the selector.
- **Portable.** Every claim above holds on the second level and on the
  generated ones; the guards' scripts name no level file and no cell.

## Manual check

Play both levels twice, quiet and loud, with each technique on and off.
When a guard notices you, can you tell why from its bar, its shape and the
points of your body it saw? When it searches, can you see where it thinks
you are, and does hiding somewhere it has just looked feel like a choice
you made? Does a guard who calls for help sound like one, and do the ones
who did not hear it go on as if nothing happened? Is being seen ever
unfair -- and if so, which knob would you turn?
