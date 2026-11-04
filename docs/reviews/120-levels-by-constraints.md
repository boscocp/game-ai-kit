# Review: wave/120-levels-by-constraints

T95: levels declared, not drawn. The new technique addon `ai_constraints`
(`ConstraintProblem`, `ConstraintSolver`, `ConstraintDraws`), its Python twin
`gameaikit.constraints`, nine vectors from an independent `derive.py`; the
infiltration level declared as a CSP (`LevelConstraints`,
`LevelConstraintRules`, `LevelSketch`), checked on the real arena by
`LevelAudit`; K and the generation view; the measurement; the pages in both
languages.

A fresh context reviewed PR #61 at head 732a9a5, reading only, in a
throwaway worktree.

**Verdict: changes requested, one blocker.** One blocker, four should-fix
findings and six nits.

## What was reviewed

The whole diff against main. Every file in `godot/addons/ai_constraints/`,
`godot/test/ai_constraints/` and `python/gameaikit/constraints/`;
`derive.py`, the vectors and their README; both vector runners and their
planted solvers; `level_constraints.gd`, `level_constraint_rules.gd`,
`level_sketch.gd`, `level_audit.gd`, `generation_view.gd`, the changes to
`infiltration.gd`, `infiltration_keys.gd`, `infiltration_words.gd` and
`level_generator.gd`; `level_constraints_test.gd`, `constraint_measure.gd`;
the manifests, the Makefile, `infiltration.csv`; the technique pages, the
concepts page, the infiltration section, the glossary rows; the task file.
The legend-fix commit (732a9a5) was read on its own.

### What was run, and held

- `python3 -m unittest ... -p "test_constraints*.py"`: 20 tests, OK.
- `make test-constraints-vectors`: 9 vectors, 0 failures.
- `derive.py` rerun into an empty directory: byte-identical to the
  committed nine.
- `make test-godot-some SUITES="test/ai_constraints test/infiltration"`:
  73/73.
- `check_addon_deps`, `check_modules`, `check_readability`,
  `check_translations_docs`, `check_literature_table`, `check_license`,
  `check_no_training`: all exit 0. `ai_constraints` uses nothing outside
  its own folder, not even `ai_core`; `modules/ai_constraints.json` has no
  `depends_on`; `infiltration.json` declares it. `affected.py` for a change
  to the solver selects `ai_constraints`, `infiltration`, `menu` and the
  `test/ai_constraints` suite.
- `make measure-level-constraints`: reproduces the PR's table exactly
  (200/200, 201 draws, 7,090 assignments, 2,304 backtracks, 6 fresh
  starts, 107 / 71 / 90 drawn levels breaking the three conditions, 0
  solved levels breaking the audit). Time: 24.1 s for 200, so 120 ms a
  level, the slowest 2.2 s (the PR says 136 ms and 2.5 s; machine noise).
  With `record` on, as the game solves: 24.2 s, the slowest 2.2 s (seed
  144), longest trace 271 steps (about 5 s of replay).

### Solver against AIMA fig. 6.5 and 6.3

The file reads top to bottom as the book: `_backtrack` and `_try` are
BACKTRACK split in two (assign, infer, recurse, remove assignment and
inferences); `_select` is MRV with the degree heuristic as the tie-break;
`_values` is LCV with an explicit stable tie; `_ac3`, `_requeue` and
`_revise` are AC-3, with MAC seeded by the arcs into the variable just
assigned, as AIMA describes. The complexity line (O(c d^3)) is right. The
twins do the same steps in the same order.

### Planted faults (invariant 4)

Planted one at a time, `__pycache__` cleared after each:

| fault | Python | GDScript |
|---|---|---|
| the degree heuristic dropped from MRV | 4 failures | 4 vector failures |
| LCV reversed | (planted solver in the suite) | 17 vector failures |
| `limit` off by one | 1 failure | -- |
| no AC-3 before searching | 3 failures | -- |
| an emptied domain not reported | 2 failures | -- |
| `LevelSketch` ignores lamps | -- | `level_constraints_test` fails |
| "no post in sight" always true | -- | fails (3 assertions) |
| "a hiding place near each route" always true | -- | fails |

Three survived, and each is a semantic no-op, not a gap: requeueing the
reverse arc (it can never lose a value), revising arcs into assigned
variables (their single value is already supported), and testing every
global rather than those naming the variable (monotone tests). The vector
runners refuse an empty directory (exit 2) and the Python side refuses
fewer than 8 vectors.

## Findings

1. **Blocker -- a constraint with no label is never enforced.** Both
   twins return the broken constraint's *label* from `_refusal` and test it
   against the empty string: `constraint_solver.gd:109-110`
   (`if refused != ""`), `solver.py:73-74` (`if refused:`). `label`
   defaults to `""` in `add_binary` and `add_global`
   (`constraint_problem.gd:61,72`, `problem.py:280,289`). So an unlabelled
   global is never applied, and nor is an unlabelled binary once
   `propagate` is off. The default call returns a wrong answer and no
   error:

   ```
   cd python && python3 -c "
   from gameaikit.constraints.problem import ConstraintProblem
   from gameaikit.constraints.solver import ConstraintSolver
   q=ConstraintProblem(); q.add_variable('a',[1,2]); q.add_variable('b',[1,2])
   q.add_global(['a','b'], lambda s: not ('a' in s and 'b' in s and s['a']==s['b']))
   print(ConstraintSolver(q).solve())"        # {'a': 1, 'b': 1}
   ```

   The same happens with `add_binary(...)` and `propagate=False`. The
   game, the vectors and the page's example all pass labels, so nothing in
   the PR catches it. The page's knob table lists `label` as an ordinary
   argument. Fix: let the refusal say "refused" apart from "why" (an
   index, or null for none), or make an empty label a declaration
   mistake that `problem()` reports. Then plant the case in
   `test_constraints.py` and `constraint_solver_test.gd`.

2. **Should-fix -- the solve blocks the frame, and N solves the same seed
   again.** `Infiltration._level` (`infiltration.gd:246`) calls
   `LevelConstraints.solve(generated, true)` on the main thread, from
   `_new_world`. K, N and L all reach it. Measured: 120 ms a level, 2.2 s
   on seed 144, a frozen window with nothing on it. N keeps `_level_index`,
   so it solves the identical seed again. The second K press (solved, then
   solved and shown) solves it a third time just to show the view. Nothing
   on the infiltration page or among the owner's items says the game
   stalls. Fix: keep the last `LevelConstraints` by seed, so N and K reuse
   it. Then either solve on `WorkerThreadPool` (the solver touches no
   scene) or write the stall down as a measured, accepted cost.

3. **Should-fix -- the `constraints` list in `level_constraints.json` is
   read by nothing.** The PR ("The conditions live in
   `level_constraints.json`"), the infiltration page ("The conditions are
   in `level_constraints.json`") and the task decision all say the file
   holds the constraints. The code reads only its numbers: `grep -rn
   'rules\["constraints' godot/` finds nothing. The five globals are
   hard-coded in `LevelConstraintRules.add`. Delete an entry from the list
   and every level is unchanged. The list's wording also differs from the
   labels ("the exit can be walked to from the start" against
   `EXIT_REACHED`, "the exit can be walked to"). Fix: either have `add`
   declare only the globals the list names, by label, so the file really
   switches them, or say on the page and in the file's `about` that the
   file holds the numbers and the list is a description.

4. **Should-fix -- after the legend fix, K is named nowhere on the game
   screen, and a give-up is silent in "shown" mode.** 732a9a5 dropped the
   legend line `solver (K): ...` (`infiltration.gd` `_show_legend`), and
   nothing replaced it. The task says K is "named on its legend". The HUD's
   switch line (`infiltration.csv:22`, "1 belief ..., 6 director ...")
   does not carry the mode, so the only on-screen sign of mode 2 is the
   level's name ("solved level N"). In mode 3, a seed the solver gives up
   on falls back to the drawn level with `_generation.visible = false`
   (`infiltration.gd:243-249`), so pressing K shows nothing and says
   nothing. The overlay's `solved: false` is the only trace. That has not
   happened on seeds 1-200, but the code path exists. Fix: add
   `K {generator}` (drawn / solved / shown) to the switch line, which is
   already checked by `test-demo-overlays`. When the view is asked for and
   there is no solved level, show one line saying the solver gave up and
   this is the drawn level. Record the legend change in the task's "Done"
   section.

5. **Should-fix -- the audit re-checks "no post in sight" with the
   solver's own model, so the page overstates it.** `LevelAudit
   ._a_post_in_sight` (`level_audit.gd:230-238`) uses the same
   `LevelConstraints.farthest_sight()`, the same `eyes` from the same
   file, the same cell centres and the same "farthest zone, any facing"
   reading as `_out_of_sight`. Only the line test is independent
   (`arena.first_block` against `BotArena.segment_hits_box`). For walking
   and light the audit is independent, built on the arena and
   `InfiltrationLevel.light`, and the lamp fault above is caught. But
   "measures every condition on the level the game builds" and "a sketch
   that drifted from the arena would be caught"
   (`docs/godot/infiltration.md`, the T95 section) are not true of sight:
   if the sight rule is wrong, both sides are wrong together.
   `test_the_sketch_walks_where_the_arena_walks` also holds only the
   blocked mask cell for cell, on 6 seeds, not the step rule (the sketch
   floods four ways, the arena over `walk_graph`). That direction is safe,
   because the sketch is stricter. Fix: say on the page which conditions
   the audit measures independently and which it re-derives. For sight,
   the stronger check is to ask `InfiltrationSenses` / a guard's real
   vision zones whether a guard at its post would see the player standing
   at the start.

6. **Nit -- a solver solved twice keeps its old counters.** `solve()`
   resets `domains` and `assignment` but not `assignments`, `backtracks`,
   `pruned`, `refusals`, `trace` or `gave_up` (`constraint_solver.gd:82-88`,
   `solver.py:51-56`). Solving with `limit=5` and then again with
   `limit=0` returns a solution with `gave_up` still True and the counts
   summed. `LevelConstraints` makes a new solver per restart, so the game
   is unaffected. Reset them in `solve()`, or document one solve per
   solver.

7. **Nit -- the twins disagree on a problem with no variables.** GDScript
   returns `{}`, which its doc reads as "none". Python returns `{}`, which
   its contract (None for none) reads as a solution. `problem()` refuses
   it, but `solve()` never asks `problem()`.

8. **Nit -- pt-BR: the game says "resolvedor" and "retrocessos" while the
   glossary keeps *solver* and *backtrack* in English.** The new glossary
   row says *solver* "fica em inglês porque 'resolvedor' quase não se usa".
   `infiltration.csv:80` uses exactly that word. Pick one.

9. **Nit -- the view departs from the task's description, and the
   departure is not recorded.** The task asks for "each variable's
   remaining domain as a count on its cell". The view lists the counts
   beside the map (`generation_view.gd:163`). That is a reasonable choice,
   but the task file's "Done" list doesn't mention it. After the replay
   ends, the last chosen variable's 16 candidates stay drawn over the
   finished level.

10. **Nit -- K on a hand-made level restarts it and changes nothing
    visible.** `next_generator` always calls `_new_world`
    (`infiltration.gd:148-157`). Either ignore K on a hand-made level, or
    let it change the mode without restarting.

11. **Nit -- the level's sketch caches stay alive for the whole level.**
    `Infiltration.solved` holds the `LevelConstraints`, and with it every
    flood, mask and light map `LevelSketch` kept during the search
    (`_floods`, `_blocked`, `_dark`). The view reads only `candidates`,
    `sketch.width/depth/start/exit_cell` and the trace. Clearing the three
    caches at the end of `solve` (beside the `binaries.clear()` that is
    already there) costs nothing.

## Items for the owner

- The six "not yet ratified" decisions in the task file. The reviewer has
  no objection to 1, 2, 3, 5 or 6. On 4 (a give-up falls back to the drawn
  level), see finding 4: the fallback is fine, but it should say so on
  screen.
- Finding 2 is a choice between a stall that is measured and written
  down, and a background solve. The owner should pick one.
- The manual check is still the owner's: L to a generated level, K, ten
  levels each way, two played; is there always a dark way through?

## What was done about them

1. **Blocker, fixed.** `_refusal` now answers null (Python `None`) for
   "nothing refused" and the label for "refused, and why", in both twins
   (`constraint_solver.gd`, `solver.py`); the callers test `!= null` / `is
   not None`. An empty label is still a valid label. Planted in both
   suites: an unlabelled global `a != b`, and an unlabelled binary with
   `propagate` off (`test_an_unlabelled_global_constraint_still_refuses`,
   `test_an_unlabelled_binary_constraint_still_refuses_without_propagation`).
   Mutating the test back to "an empty label means nothing refused" fails
   both in Python (2 failures) and each in GDScript (run once with the other
   renamed away, since gdUnit4 stops a file at its first failure). The
   technique page's knob table now has a `label` row saying an unlabelled
   constraint is enforced all the same.
2. **The minimum, as asked.** `Infiltration` keeps the last
   `LevelConstraints` by its seed (`_solved_for`), so N and the second K do
   not solve again; L to another level does. No `WorkerThreadPool`. The
   stall is written down on the infiltration page ("The solve stalls the
   frame -- a known cost": 120-140 ms a level, 2.2-2.5 s on seed 144), on
   the concepts page, and in the task's Done list as item 9, "solve in the
   background?", pending the owner.
3. **The first option.** `level_constraints.json`'s `constraints` now
   lists the ten rules by exactly `LevelConstraintRules`' labels, binary
   first, and `LevelConstraintRules.add` declares only the ones the list
   names, in its order (a `match` on the label, one line a rule); a name no
   rule has is a `push_error` and skipped. `LevelConstraints.declared`
   records what was declared. The file's `about` and the infiltration page
   say the file names the rules and holds their numbers, while the rules
   are written in `LevelConstraintRules`. New test: the default declares
   every label; a list without "a dark way to the exit" declares nine and
   not that one. The declaration order is unchanged, so the measurement
   reproduces exactly (7,090 assignments, 2,304 backtracks, 6 restarts).
4. **K is back on screen.** The switch line reads `..., 6 director {on},
   K level {drawn | solved | solved and shown}`, both languages; the mode
   moved into `InfiltrationRules` (`level_generator`, `show_generation`) so
   the panel reads it like the other switches. When the view is asked for
   and the solver gave up, `GenerationView.show_gave_up` draws one line:
   "the solver gave up on seed N: this is the drawn level" (tested). Done
   list item 7. `test-demo-overlays` passes in en and pt_BR with the longer
   line.
5. **Said on the page.** The infiltration page now lists which audit
   conditions are independent of the solver's model (walking, light: the
   arena's walk graph and the level's light map) and which are not (sight:
   the line test is the arena's, the reading of "in sight" is the solver's).
   The concepts page says the same in one clause. Asking the guards' real
   vision was not simple enough for this wave (zones, facing, body points
   and light at once), so it is named as not asked.
6. `solve()` now starts the counts, the trace and `gave_up` afresh, in
   both twins; a test solves with `limit = 5`, then without, and gets the
   fresh solver's count.
7. Both twins now refuse a declaration `problem()` refuses: no answer
   (`{}` / `None`) for a problem with no variables; tested in both.
8. pt-BR: the game says *solver* and *backtracks*, as the glossary keeps
   them ("solver: passo ... backtracks, ... recomeços"); "resolvedor" and
   "retrocessos" are gone.
9. Recorded as Done item 8 (counts beside the map, why). The chosen
   variable's candidates are no longer drawn once the replay has ended.
10. K on a hand-made level changes only the mode, for the next generated
    level, and does not restart the world.
11. `LevelSketch.forget()` drops the floods, masks and light maps at the
    end of `solve`, beside the constraints cleared there.

## Runs after the fixes

- `test_constraints*.py`: 24 tests. `make test-constraints-vectors`: 9
  vectors, 0 failures. `make test-godot-some SUITES="test/ai_constraints
  test/infiltration"`: 79 cases. `test-demo-overlays`: en and pt_BR, 0
  failures. `make measure-level-constraints`: the same counts as before.
- The full `make check-affected BASE=origin/main` on the final head: see
  the pull request body.
