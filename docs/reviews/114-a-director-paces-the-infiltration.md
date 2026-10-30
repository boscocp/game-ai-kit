# Review: wave/114-a-director-paces-the-infiltration

T90: a director after Booth's Left 4 Dead director paces the infiltration
level. The player's intensity is raised by events and decays, four phases
are read from it, and the level's reserve patrols are sent and called back
by phase. Python and Godot hold one machine, checked by vectors.

A fresh context reviewed PR #55 at head b5ed7dc.

**Verdict: changes requested; no blockers.** Every should-fix and nit was
applied on the branch. The two points that are design choices are left to
the owner, as asked.

## What was reviewed

The diff against main:

- the machine: `godot/game3d/infiltration/director.gd`,
  `python/gameaikit/director/pacing.py`, `spec/director/director.json`
  and its Godot copy, `spec/vectors/director/` (the vectors, `derive.py`,
  the README), and the runner and Python tests that hold them;
- the wiring: `DirectorEvents`, `DirectorOrders`, `DirectorStrip`, and the
  changes to the world, guard, level, generator, keys, text, words, radar
  and demo, the two level files, and the pt-BR table;
- the claims: `director_test.gd`, `director_runs.gd`, `director_measure.gd`,
  and the new `distract` mode of `ScriptedPlayer`;
- `docs/concepts/stealth-ai.md`, `docs/godot/infiltration.md`, the
  catalogue, `games.json`, the READMEs, the manifest, the Makefile and the
  STATUS row.

## Findings

Should-fix:

1. **The fairness test caught one cheat only.** It compared beliefs and
   memory, so a director that set `guard.route = [player position]`
   changed no belief and passed. "A route, not the player's position" was
   not held.
2. **"No patrol sent in view" had no run-level planted case.** The planted
   nearest-picker was only called directly, and `DirectorRuns.run` could
   plant `send` but not `pick`. The page's "each with its planted case"
   overclaimed.
3. **"Existing generated levels unchanged" held only by construction.**
   Nothing compared the generator's output with what main writes.
4. **The concepts page presented the four-phase cycle as what the kit
   does.** The measurement says otherwise: mostly build-up and fade, and a
   relax in one run of 39. That was said only on the infiltration page.
5. **No vector contained a `heard` event**, so `raise.heard` was held by
   nothing.

Nits:

- a downed reserve guard still counted in "patrols out" and in what was
  wanted;
- generated reserve posts and beat cells could coincide with each other,
  with a guard's place, or with the exit;
- `derive.py` had a one-line import and a single-letter name, `e`;
- pt-BR named it "*director*" in the docs and "diretor" in the game, and
  the glossary had no row for it;
- the un-reread Booth slides were not named as a deviation from the
  task's step 1;
- the one-level whole-cycle test should say, on failure, how to re-pick
  the level, and should say that the run's intensity comes from the
  player's own distractions.

## What was done about them

1. `DirectorRuns` now checks every order. A send must leave the guard's
   route equal to its beat, and a recall must leave no route. Any other
   route is a `route` finding. A new property asserts there are none on
   every run, and a planted `send` that routes the guard to the player's
   place is caught (`test_a_director_that_sends_a_guard_to_you_is_caught`).
2. `DirectorRuns.run` takes a `planted` dictionary with `send` and/or
   `pick`. With `_nearest_reserve` planted as `pick`, the run-level
   `seen_sent` claim finds a guard sent in the player's view
   (`test_a_director_that_sends_the_nearest_reserve_seen_or_not_is_caught`).
   The page lists the three run-level claims, each with its cheat.
3. `test_the_reserve_leaves_every_generated_level_as_it_was` holds the
   sha-256 of `LevelGenerator.make(seed)`, as sorted JSON with `"reserve"`
   erased, for seeds 1-11. The fingerprints were taken by running main's
   generator (b6b86d1) beside this branch's, and all eleven matched.
4. `stealth-ai.md` gains a paragraph, "What it does in practice is less
   than the cycle", with the measured shares and a link to the
   infiltration page's numbers.
5. A seventh vector, `hearing-adds-less-than-sight`, has `derive.py` check
   that hearing adds `raise.heard` and sight adds `raise.seen`, and that
   the two differ. The Python test now expects at least seven vectors.

Nits: `on_patrol` counts only living reserve guards. The generator draws
reserve cells without repeats and away from every guard place and the
exit, and `test_a_generated_reserve_takes_no_one_elses_place` holds this;
the fingerprints are unaffected. `derive.py` is fixed. pt-BR now says
"diretor" everywhere, with a glossary row "*director* (diretor)". The
deviation from step 1 is named on both pages. The whole-cycle test's
failure message says to re-pick the level from `make measure-director`,
and its constant explains where the intensity comes from.

Re-measured after the generator change (`make measure-director`, 39 runs):
2165.4 s building up, 119.3 holding the peak, 733.9 fading, 86.4 relaxing.
33 peaks, 3 relaxes (all in generated 10), 71 patrols sent, 4 called back.
Two stand-offs instead of three. The pages and the STATUS row carry these
numbers.

## Decisions for the owner, with the reviewer's opinion

1. **Engagement and the decay.** Booth's "no decay while engaged" is read
   as "a guard is alert and sees you", and the stand-offs hold the fade
   for minutes. *Reviewer:* define chasing as alert, seeing and closing in,
   then add a spec number such as `chase_pause_most: 10` with a vector. The
   stand-off itself looks like a T70 guard issue for a separate task. Not
   done here: it is the owner's.
2. **Off by default**, like the particles. *Reviewer:* keep it off until
   the manual check. Kept.
3. **The whole cycle held on one chosen level** (generated 10, where the
   player is never found). *Reviewer:* acceptable as written, now that the
   test says why that level was chosen and how to pick another. Revisit
   after decision 1.
