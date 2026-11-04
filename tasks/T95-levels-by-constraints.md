# T95 — Levels declared, not drawn: a constraint solver places the infiltration level

Size: M · Prereqs: T70 · Files: `godot/addons/ai_constraints/`, `godot/test/ai_constraints/`, `modules/ai_constraints.json`, `python/gameaikit/constraints/`, `spec/vectors/constraints/`, `python/tests/`, `godot/game3d/infiltration/`, `godot/test/infiltration/`, `docs/techniques/`, `docs/concepts/`, `Makefile`

## Goal

The owner, 2026-10-26, answering T73's question 1: every entry of part A,
"todos" -- after the recommended three, the rest: CSP and wave function
collapse for levels (this task and T96), the MDP, bandits, player
modelling, `ai_llm`.

Constraint satisfaction teaches **declaring what a solution is instead of
how to find it** (AIMA 4th ed., ch. 6: propagation in 6.2, backtracking in
6.3, with variable and value ordering in 6.3.1). Foged and Horswill's
chapter is about writing exactly such a solver for a game [GAP2 ch. 26].

The infiltration level already has the contrast built in.
`LevelGenerator` draws shelves, lamps, hiding places, routes and a sentry
at random, and "a level is kept only when the exit can be walked to from
the start and every route point and post from the start too; otherwise
the next draw is tried" -- generate and test, up to `TRIES` = 40 draws. A
solver states those conditions, and more a designer would want, and
finds a level that meets all of them or says none exists.

## Decisions written down first (the owner confirms in review)

- **A new technique addon, `ai_constraints`**: finite domains, binary and
  global constraints, AC-3 propagation, backtracking with
  minimum-remaining-values and least-constraining-value -- AIMA's names,
  top to bottom like its pseudocode. Its own Python twin. No dependency on
  another addon (invariant 2); reachability, a global constraint, is given
  as a callback the game supplies.
- **Home: the infiltration level** (recommended), so that the lesson is a
  before-and-after on one generator; the XCOM mode's maps (T84) are the
  alternative, and T96's WFC goes there instead.
- **What the level must satisfy**, as constraints in a file
  (`godot/game3d/infiltration/level_constraints.json`, beside
  `guard_types.json`): the exit reachable from
  the start; every route point and post reachable; no guard's post in
  sight of the start; at least N hiding places within reach of each
  patrol's route; lamps leaving at least one dark path from start to exit.
  The last two are new -- a designer's intent that generate-and-test can
  only hope for.
- **Seeded and reproducible**: the variable and value orders break ties
  by a seeded generator, so a seed gives one level, in both languages.
- **Invariant 6 untouched**: a solver searches; it fits nothing.

## Steps

1. Python first: `python/gameaikit/constraints/` with map colouring and a
   small Sudoku as its tests (AIMA 6.1.1 and 6.2.6), then the level.
2. `godot/addons/ai_constraints/`, held to Python by vectors: the same
   problem, the same seed, the same assignment, the same count of
   backtracks.
3. `LevelGenerator` gains a constraint mode beside its draw-and-test one;
   key N's new world uses the chosen mode.
4. Measured: over 200 seeds, levels found, draws or backtracks spent, and
   the share of draw-and-test levels that break the two new constraints;
   in the infiltration page.
5. The technique page for `ai_constraints`, both languages; a concepts
   section on CSP; the literature page's CSP row names the addon.

## Acceptance

```bash
python3 -m unittest discover -s python/tests -t python -p "test_constraints*.py"
make test-constraints-vectors
make test-godot-some SUITES="test/ai_constraints test/infiltration"
python3 scripts/check_addon_deps.py
python3 scripts/check_translations_docs.py
python3 scripts/check_literature_table.py
make lint-modules
python3 scripts/check_readability.py
make lint-tasks lint-status
```

## Manual check

Generate ten levels each way (N, with the mode switched) and play two of
each: do the constraint-built levels feel designed where the drawn ones
feel random? Is there always a dark way through?

How invariant 13 is met: a "generation" view (K -- free in the
infiltration demo, where 1-6, G, H, L, N, P, Tab and the movement keys are
taken; named on its legend) shows the solver at work -- each variable's remaining domain as a count on its cell, the
cell chosen next by minimum remaining values, propagation crossing values
out, and a backtrack drawn as the cells it undoes -- so the person sees
the decisions that built the level, not only the level.

References, opened on 2026-10-26: AIMA 4th ed., contents (ch. 6)
<https://aima.cs.berkeley.edu/contents.html>; Foged & Horswill, GAP2 ch.
26, as cited by T73.

## Done (wave 120), and where it departs from the above

Recorded for the owner's review; none of these is decided until the owner
says so.

1. **The level is solved in GDScript only.** Step 1 asked for the level in
   Python too. The level's constraints read the game's own ground -- the
   arena's walk rule, its sight lines, the level's light -- and the Python
   side has no `BotArena`. The Python twin holds the solver (map colouring,
   Sudoku, queens, the vectors); the level is held instead by `LevelAudit`,
   which measures every solved level on the arena the game builds.
2. **Candidates, not every cell.** Each variable's domain is 16 places drawn
   from the seed, not every cell of the level: with every cell, AC-3 and LCV
   over the box pairs would cost seconds per level in GDScript.
3. **Restarts.** Chronological backtracking thrashed on a few seeds (before
   restarts, 6 of 200 hit a 3,000-assignment limit, one after 57 s). The
   level now restarts with the ties broken by another seed when 400
   assignments run out, up to four times: 6 restarts over 200 seeds, every
   seed found. Backjumping (AIMA 6.3.3) would be the textbook's answer; it
   is named on the pages and not built.
4. **K is a three-way cycle** -- drawn, solved, solved with the view -- since
   the task names K for the view and also needs a switch between the modes.
   Without it, N keeps the mode chosen. A seed the solver gives up on falls
   back to the drawn level.
5. **The numbers in `level_constraints.json` are the kit's own:** boxes 1 m
   apart, lamps 6 m apart, a hiding place within 6 walk steps of a route,
   "dark" under 0.3, "in sight" a clear line at 1.6 m within the guard
   type's farthest zone. None was tuned against a playtest.
6. **"No guard's post in sight"** covers the sentry's post and each
   patrol's first route point (where a patrol stands at the start).
7. **K is named on the panel's switch line, not on the legend.** A legend
   line ran past the window's gutter (`test-demo-overlays`), so the line
   reads `..., 6 director on, K level solved and shown`; the view carries
   its own key, and says in one line when the solver gave up and the level
   is the drawn one. K on a hand-made level changes only the mode.
8. **The counts are listed beside the map, not on each variable's cell.**
   An unassigned variable has 16 candidate cells and no one cell of its
   own, so the view lists every unplaced thing with its count (the next one
   first) and draws the next one's candidates on the map.
9. **The solve runs on the main thread** and stalls the frame -- 120-140
   ms a level, 2.2-2.5 s on the slowest seed. The last solved level is kept
   by its seed, so N and the second K do not solve it again. Pending the
   owner: solve in the background?

The manual check above is still the owner's.

