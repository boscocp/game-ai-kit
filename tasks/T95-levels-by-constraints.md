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
