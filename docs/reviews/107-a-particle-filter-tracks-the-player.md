# Review: wave/107-a-particle-filter-tracks-the-player

T91: `ParticleBelief` in `ai_perception` beside `BeliefMap` -- a transition
model, a sensor model that counts what was not seen and not heard,
systematic resampling -- with a Python twin held by vectors, wired into the
infiltration level's guards behind key 1, and T73's "finds you sooner"
measured again.

A fresh context reviewed PR #49 at head 7150e32.

**Verdict: changes requested; no blockers.** Every should-fix and nit was
applied on the branch, after a rebase on 4c4c1d1 (T103).

## What was reviewed

The diff against main:

- `godot/addons/ai_perception/particle_belief.gd`, `particle_draws.gd`, and
  `godot/test/ai_perception/` (the vector kind, the suite);
- `python/gameaikit/perception/particles.py`, `draws.py`, the tests;
- `spec/vectors/perception/` (four `particles-*` vectors, `derive.py`, the
  README);
- the infiltration wiring (`InfiltrationSenses`, `InfiltrationGuard`,
  `InfiltrationWorld.believed`, `GuardSearch`, `GuardWaysOut`, the
  drawing, ground, radar, keys, text, rules, the pt-BR table) and
  `godot/test/infiltration/` (`TrackingClaims`, the runner, the switch
  suite, `HidingStage`);
- `docs/techniques/ai_perception*.md`, `docs/godot/infiltration.md`,
  `stealth-ai.md`, the literature table, the manifests, the Makefile, the
  STATUS row.

## What the reviewer found sound

- **The filter is correct.** The resampler is Thrun's low-variance one
  (AIMA 14.5.3's systematic resampling): one draw, then evenly spaced
  marks; `came_from` is copied with its particle and reset on a collapse
  and a reseed.
- **The twin is bit for bit,** and `derive.py` is an independent third
  copy importing nothing from the repository.
- **The grid default is untouched**: `make test-infiltration` and
  `test-infiltration-properties` print exactly what they print at the
  merge base, 4cbc399.
- **The `believed` seam** is what the search, the ways out and the radar
  read; nothing reads a guard's belief past it.
- **Invariant 2 is held honestly**: `ParticleDraws` is a copy, and says
  so and why.
- The pt-BR text is faithful to the English.

## Findings

1. **256 particles covered only 29-55% of each level (should-fix).** The
   levels have 468 to 892 walk cells. The even start and every reseed put
   particle i on `candidates[i * n / 256]`, a striped pattern with share 0
   between. One particle (1/256 = 0.0039) outweighed `GuardWaysOut`'s
   "likely" cut (2/n) on every level over 512 cells, so any cell holding
   one particle was "likely", and its empty neighbours became ways out
   scattered across the level. Concretely, T70's staged run on generated
   level 2, seed 3, was never found in 60 s with 256 particles. It took
   9.3 s with the grid and 8.4 s with 1024 particles. With 1024 particles
   the staged mean was 6.40 s against the grid's 6.93.
2. **"Slower when the player never moves" rested on one capped run
   (should-fix).** Per run, particles against grid in T70's staged search
   were the same in 11 of 15. Two differed only through that capped run
   (60.0 against 9.3, and 9.3 against 22.8). Without it the means were
   about 5.8 against 6.8, with particles better in 2 runs and worse in 2.
3. **The tracking scenario has little power (should-fix).** About 12 of
   the 26 paired runs ended within 1.1 s, where a belief step is 0.5 s.
   The particles changed 3 or 4 of 44 runs. Only 2 of the 4 hand-made
   runs were measured, yet they had rows of their own.
4. **"Heard nothing" had no test (should-fix).** A mutant whose
   `would_hear` always returned nothing left `test/infiltration` at 31 of
   31 and the tracking gate at 0 failures; only the printed mean moved,
   9.4 to 14.1. The gate's `_same()` caught only a total miswiring: spots
   read from the particles while ways out read the grid would pass.
5. **The sensor used the standing footstep's 6 m (should-fix),** while the
   measured player creeps (2 m). It also ignored the off-screen halving
   without saying so.
6. **The menu card was wrong (should-fix).** It said "1 turns it off" and
   "press 1 and hide again: without the belief ...", but one press now
   selects the particles.
7. **The legend lacked the new overlay (should-fix).** It had no entry for
   the particle dots (a different orange from the grid's) or for the white
   flash on emptied cells.
8. **Nits.**
   - After resampling, `weights[i]` no longer pairs with `nodes[i]`.
   - `mark > reached` made `>=` survives the vectors (an exact float tie).
   - An unreachable `use_belief` check sat in `_draw_particles`.
   - Invariant 6 was worded "never written into"; "rebuilt from constants
     each step, never accumulated" says it better.
   - The 40 s gate in `make check` was thin. Keep cheap checks there and
     move the table to a print-only target.

## What was done about them

1. **Two particles a walk cell** (`rules.json`'s `belief.particles_per_cell`,
   936 to 1784 on these levels). The start and a reseed now cover every
   cell, and a cell needs four particles to reach the "likely" cut. The cut
   itself was left at twice an even share, because the grid's numbers
   depend on it; the page says so. `particle_belief.gd`'s header says what
   fewer particles than nodes does. The cost is measured and printed:
   about 1.5 ms per guard step on the largest level (892 cells), twice a
   second. With the guards stepping in the same frame, a level of four
   spends about 6 ms of one frame. `docs/godot/infiltration.md` says so,
   and says to stagger or coarsen. Everything was re-measured (below).
2. **The claim is withdrawn.** `make test-infiltration-tracking` now
   prints every run paired, the means and the medians, the counts of
   sooner, later and the same, and the runs at the cap by name. The pages
   (`infiltration.md`, `ai_perception.md` and pt-BR) say only what the
   numbers carry.
3. **Said on the page**, with the counts: how many runs ended within one
   belief step, and that most others were decided by a glimpse collapsing
   both beliefs. The hand-made rows are gone; the table is one paired row
   a scenario, and names what a scenario with power would be.
4. **`belief_switch_test.gd` gained three cases.**
   - A silent guard would have heard a creep one step away, and not a cell
     far off; a guard that heard something gives no cells.
   - The spot a guard is given is weighed from the belief that is on, with
     the two beliefs collapsed on two far-apart spots.
   - The way out is found from the belief that is on (the coordinator
     planted to give no spots).
   Four mutants were caught by `test/infiltration` alone: `would_hear`
   always empty, `would_hear` ignoring what was heard, spots read from the
   grid, and ways out read from the grid. The PR body's claim about the
   gate is corrected.
5. **The quietest moving sound**: `InfiltrationSenses.quietest_step` takes
   the smallest radius among the stances' noises, the creep's 2 m, from the
   data. The halving is left out on purpose, and the docstring and the page
   say why: it is a rule about the camera, not something a guard knows of
   its own ears.
6. The card says 1 swaps the grid for the particles and again turns the
   belief off. The controls line reads "1 belief (grid, particles, off)",
   and "what to watch" walks through both presses. The card has no pt-BR
   table: the menu shows `catalogue.json`'s English, and
   `catalogue.py --check` passes.
7. Two legend entries in both languages: "particles (1): its guesses,
   bigger where more" in the particles' colour, and "white square:
   guesses its sight just cleared". `make test-locale-screen` and
   `test-demo-overlays` pass in both languages.
8. **The nits:**
   - `weights` is documented as indexed by the particles as they were
     weighed, before resampling, in the GDScript and in the vectors README.
   - The tie is not planted. A float tie needs a draw that lands exactly
     on a sum of weights, and no small seed gives one.
   - The unreachable check is removed.
   - Invariant 6 now reads "rebuilt from those constants each step, never
     accumulated from one step to the next", in both languages and the
     header.
   - `test-infiltration-tracking` is a measurement, out of `make check` and
     out of the module's gates. What `make check` holds of the wiring is
     the gdUnit cases in 4.

**The measurements, after the fixes** (2026-10-29):

| scenario | paired runs | grid mean / median | particles mean / median | particles sooner | grid sooner | same |
|---|---|---|---|---|---|---|
| a reported player creeps to a hiding place | 26 | 4.8 / 1.5 s | 4.7 / 1.5 s | 2 | 1 | 23 |
| T70's staged search, the player never moving | 15 | 6.9 / 5.7 s | 7.1 / 5.7 s | 0 | 3 | 12 |

One moving run is at the cap with either belief (generated 5, seed 1), and
5 of the 26 ended within one belief step. No difference worth the name.

## The reviewer's runs

At 7150e32:

- `make test-infiltration-tracking`: 0 failures, 41 s.
- Perception vectors: 15 files.
- The infiltration outputs are identical to the merge base's.
- gdUnit: 109 cases. Python: 11 tests. The lints pass.
- Four mutants:
  - two were caught;
  - one is near-equivalent (`>=` in the resampler);
  - `would_hear` returning nothing survived -- finding 4.
- Windowed screenshots, `scratchpad/reviewer49/shot1.png` and `shot2.png`:
  the dots are visible after a sighting, and the spread cloud is hidden by
  walls in third person.

After the fixes, on the branch:

- `make test-perception-vectors`: 15 files.
- The Python perception tests: 11 tests.
- `test/ai_perception test/infiltration test/menu`: 142 cases, 0 failures.
- `make test-infiltration-tracking`: 0 failures.
- `make test-infiltration test-infiltration-properties`: line for line
  what they printed before.
- `make test-locale-screen test-demo-overlays`: 0 failures.
- The lints pass.
- The only SCRIPT ERRORs are `demo_overlays`' six planted ones.

## Decisions for the owner, with the reviewer's opinion

- **Particles as the default belief**: no. Revisit after finding 1 is
  fixed and there is a scenario where the belief decides -- a long chase
  out of sight with several ways the player could have gone.
- **One seeded generator moved into `ai_core`** rather than three copies
  (`Xorshift`, `MazeDice`, `ParticleDraws`): yes, through an amendment to
  ADR 0021. Not done here.
- **The tracking gate**: thin as a gate. Keep the cheap checks in
  `make check` and the table as a measurement -- done.
