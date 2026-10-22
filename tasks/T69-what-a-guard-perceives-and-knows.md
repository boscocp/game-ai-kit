# T69 — What a guard perceives, how aware it is, and what it knows

Size: L · Prereqs: T14, T49, T67 · Files: `godot/addons/ai_perception/`, `godot/addons/ai_search/`, `godot/game3d/infiltration/`, `python/gameaikit/perception/`, `spec/vectors/perception/`, `godot/test/ai_perception/`, `godot/test/infiltration/`, `modules/ai_perception.json`, `modules/infiltration.json`, `Makefile`, `docs/concepts/stealth-ai.md`

## Goal

The first half of the owner's T52 (2026-10-21): bots against the player
with an optional stealth, "inspirado no assassins creed, splinter cell e
metal gear", applying what T67 learns. The owner split it in two on the
same day; it was numbered T52.1 at first, renumbered T69 because `make
wave` reads only whole numbers. This half is the techniques: what a guard
perceives, how aware that makes it, and what it then knows. T70 builds the
level, the cooperation, the player and the overlay on them.

The owner's standing rule holds here first, because this is where it is
cheapest to keep: "aqui devemos sempre trabalhar a autonomia e fazer o
mínimo de if else fixo na demo, pra ser uma IA genérica", and the agent
"em outro mapa, outro contexto com outros modelos 3d ... deve saber se
virar". So nothing in this task knows a level: the techniques take a
neighbour list, path lengths, a light per cell and a percept, and every
number is a data row per guard type.

## Decided (2026-10-21)

- **The research is [`docs/concepts/stealth-ai.md`](../docs/concepts/stealth-ai.md)**
  (wave 74), 20 sources each opened. Perceiving and being aware are two
  things [Walsh 2015]: a vision shape that widens then narrows, read as a
  certainty per zone [McIntosh 2015; Rabin 2015], light at the player's
  feet [Leonard 2003], sound along the level, not through walls [Walsh
  2015; Miles 2013]. Awareness accumulates and decays through every
  intermediate value [McIntosh 2015; Leonard 2003]; the phases are
  thresholds on it, in data [Welsh 2013], with a caution that lasts after
  an alert [Ubisoft 2024]. A guard knows only what it perceived or heard
  [McIntosh 2015]; a shared belief collapses to where the player is seen,
  and otherwise spreads and is wiped where any guard sees [Isla 2013;
  McIntosh 2015].
- **Invariant 2 decides where each piece lives.** `ai_perception` depends
  only on `ai_core`, so it computes nothing another addon owns: the
  awareness accumulator takes its rate per step as a number, the hearing
  takes a path length, the belief takes a neighbour list and the cells
  seen. The guard's own module, `infiltration` (started here, an example),
  wires them: the rate from an `ai_fuzzy` rule base, the path lengths from
  an `ai_search` flood over the walk graph -- as T14's stealth demo wires
  `ai_fuzzy` into its suspicion.
- **The awareness rate is a fuzzy controller** -- the owner's choice of the
  two offered. It keeps T14's lesson: the 2D suspicion grown from a grid to
  rays at a body.
- **Metal Gear is taken as design only** -- its phases as pacing, the radio,
  the radar, the hiding places -- since no developer source on its AI
  exists. Nothing in this task claims to work as Metal Gear's guards do.
- **No cheat in what a guard knows.** Welsh's 2-3 s of "knowing", his
  search weight towards the player's real position, and The Last of Us's
  5 m rule are left out [Welsh 2015; McIntosh 2015]; the belief does their
  job.
- **Off-screen hearing halved is on by default** (the owner asked for the
  sources' recommendation; it is Walsh's): a guard off screen and far
  enough away hears minor events at half the radius, because being heard
  by a guard the player cannot see feels unfair whatever the simulation
  says [Walsh 2015], and the Mirage team aimed at detection players trust
  [Reparaz 2024]. Here it is only a factor the hearing accepts; T70 ties it
  to the camera and shows it.

## Steps

1. **Read T67's result.** Its percept record and the parts of
   `ai_perception` it uses are the base; extend them, do not fork them.
2. **The vision shape**, in `ai_perception`. Zones that widen then narrow
   with distance, each with a certainty from 0 to 1; movement adds, poor
   light and hiding spots take away [Rabin 2015]. Rays to a few points on
   the body, given as clear or blocked by the caller; how many must be
   clear is a stance rule. Returns a percept: certainty, which points were
   seen, and why the rest were not -- the overlay's material.
3. **Light** as a value per cell, sampled at the target's feet.
4. **Hearing by path length.** `ai_perception` turns a path length and a
   radius into a loudness, zero where no path exists, never rising with
   length, times a listener factor of at most 1 (the off-screen halving).
   The path lengths come from a flood in `ai_search` -- Dijkstra to every
   cell within a cost, added there if it has none, with its own vectors.
   `Hearing`'s straight line stays for the 2D stealth demo; both headers
   say which is which.
5. **Typed events** as data rows: sense, priority, radius, lifetime
   [Miles 2013] -- footstep, shot, thrown object, body, open door, a guard's
   call. A guard's own call is an event like the others.
6. **Awareness**, in `ai_perception`. One number per guard and stimulus,
   rising by the rate it is given, falling at a rate of its own and through
   every intermediate value. Phase thresholds as fractions of the peak; a
   caution floor and its duration. Per guard type in a JSON file, as
   Crysis does [Welsh 2013]. The phase is a pure function of the number
   and the row -- there is no transition code. In `infiltration`, the rate:
   an `ai_fuzzy` rule base of certainty, light, motion and distance, its
   rules in the same JSON.
7. **Memory and belief**, in `ai_perception`. Each guard's memory: where,
   when and from what it last perceived the target. A belief map over a
   neighbour list. While any guard perceives the target, all of it sits on
   the perceived cell. While none does, each step spreads it along edges,
   zeroes every cell a guard sees, and renormalises. If a step would clear
   it all, it is reseeded uniformly over the cells no guard sees, and the
   overlay says so (the player has been searched for everywhere they could
   be and was not found). It is written only from a percept or a heard
   report.
8. **Python twins and vectors** for the shape, the loudness, the flood, the
   accumulator, the phase reading, the fuzzy rate and the belief.
   `make test-perception-vectors`, as `test-teamwork-vectors` is.
9. **Properties**, `godot/test/infiltration/awareness_properties.gd`, over
   seeded generated graphs, below.

## Acceptance

```bash
make test-perception-vectors
make test-search-vectors
make test-fuzzy-vectors
make test-python
make test-godot-some SUITES="test/ai_perception test/infiltration"
python3 scripts/check_addon_deps.py
python3 scripts/check_modules.py
python3 scripts/check_readability.py
```

```bash
./scripts/godot --headless --path godot -s res://test/infiltration/awareness_properties.gd
```

`awareness_properties.gd` holds, over seeded generated graphs, each claim
with a planted case it must reject (invariant 4):

- **Nothing known that was not perceived.** Awareness does not rise on a
  step with no percept; memory and belief change only from a percept or a
  heard report. Planted: an update that reads the target's true position.
- **Awareness follows exposure.** With all else fixed and the target in
  one zone, the awareness reached after a stated time does not fall as the
  target comes nearer along the guard's facing, into light, or starts to
  move; outside every zone, or with too few clear body points, it does not
  rise. Planted: the light input inverted.
- **The phases follow the thresholds.** The phase is the one the number
  and the row give; falling, it passes through every phase in between;
  after an alert it stays at or above the caution floor for the stated
  time. Planted: a threshold read from the wrong row.
- **Sound goes round, not through.** A listener with no path to the source
  hears nothing at any straight-line distance; loudness never rises with
  path length. Planted: Euclidean distance.
- **Off-screen halving only lowers.** With the factor on, no listener
  hears any event louder than with it off. Planted: a factor above 1.
- **The belief is honest.** While the target is perceived it is all on the
  perceived cell; while it is not, it is zero in every cell a guard sees,
  sums to one, and moves only along edges; a full clear reseeds over the
  unseen cells. Planted: diffusion through a wall.
- **Portable.** Every claim above holds on graphs the test generates, of
  sizes and shapes no hand-made level has. Planted: a guard type whose
  data names a cell of one level, which the generated graphs must break.

## Manual check

None of this is on screen yet; T70 draws it. Read `awareness_properties.gd`'s
output for `SCRIPT ERROR`, not only its exit code (CLAUDE.md's trap), and
read one guard type's JSON row aloud: does each number say what it tunes?

## Done in wave 79 (2026-10-22)

What was built differs from the steps above in these places, each on
purpose; `docs/concepts/stealth-ai.md`'s last section has the map and the
numbers.

- **T67's percept record was read, not extended.** `MatchPercepts` is the
  bot match's, and holds rounds, orders and cover a guard has no use for.
  The guard's own record is `GuardPercept`, in `infiltration`, the same
  idea: one record a step, and a mind that reads nothing else.
- **The fuzzy rate's vector is an ordinary fuzzy vector**,
  `spec/vectors/fuzzy/a-guards-awareness-rate.json`, checked by `make
  test-fuzzy-vectors` and by `gameaikit.fuzzy` -- the rate's Python twin is
  the fuzzy package. `guard_type_test.gd` holds its controller equal to the
  patrol row's.
- **The flood's Python twin is `gameaikit.search.flood`**, a new package;
  the flood vectors are `flood-*.json` in `spec/vectors/search`, checked by
  `make test-search-vectors` and `make test-python`.
- **Two guard types**, a patrol and a sentry, so "the wrong row" and
  "every guard type" are claims about more than one row.
- **Portable, planted as the task says**: a row with a `post_cell`, used
  as where a noise is made; on levels too small to have that cell, the
  noise is not heard where it is made. The honest rows are also read for
  any key naming a cell, a position or a place.
- **Honest steps are counted**: the claim "nothing known that was not
  perceived" fails if the walks never give an empty step or never a
  perceived one, so it cannot pass on an empty scene.

Measured: every claim holds on 150 generated levels and both types, and
every planted case is caught, each by its own claim (printed once, by a
probe not committed): the truth told changed the memory on an empty step;
inverted light lowered awareness as the light rose; the wrong row read
0.25 as phase 0; Euclidean hearing let a cell behind a full wall hear; a
doubling factor made a far cell louder; a leaking diffusion gave a node a
share from no neighbour; the posted noise was off a smaller level. The
properties take about 30 s.

After the review (wave 79): the portability claim is two pairs, each with
its own planted case, and its key check says it matches by name only;
`Awareness.problem` refuses a row whose phases do not rise from 0 or whose
caution floor would keep a guard alert for good; the walk takes a stance
and low cover at random, so the stance's count is exercised, and reads the
footstep's radius from the events; the exposure claim adds a crouched body
with one point showing and one off the side of a zone; the reseed is
O(V + E) on both sides. The headers say that a flood over the 4-connected
walk graph hears in a diamond, and why light and motion are read twice.
The review's note for T70 -- "seen" must mean "would be perceived there"
-- is in `docs/concepts/stealth-ai.md`.
