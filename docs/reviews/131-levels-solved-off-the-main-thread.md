# Review: wave/131-levels-solved-off-the-main-thread

T122: the infiltration's levels are solved off the main thread.
`LevelSolving` runs the unchanged `LevelConstraints.solve(seed, true)` as
one `WorkerThreadPool` task. The scene polls it each physics frame
(`is_task_completed`, then the wait) and waits for a running task in
`_exit_tree`. The old level plays on meanwhile, and the panel's first line
says "solving level N". Headless, the scene solves inline.

A fresh context reviewed PR #73 at head 496015a in a throwaway worktree.
It planted faults one at a time and ran only `level_solving_test.gd` plus
a scratch probe suite. The probe was copied into the tree only while it
ran, and is kept at `scratchpad/review-73/probe_test.gd`. Each plant was
restored. Nothing was pushed, committed or commented.

**Verdict: changes requested. No blocker, two should-fix findings.** The
threading is sound. The worker shares nothing with the main thread, the
result is read only after the wait, and the pool's level equals the
inline one step for step. The lifecycle code is also correct today:
probes for L pressed mid-solve, a solve that turns stale, and the scene
freed mid-solve all behave. But three plants in that lifecycle survive
the PR's suite, so nothing would catch a regression. And the panel tells
the person a level is coming when none is.

## What was reviewed

The diff against main: `level_solving.gd`, the hunks in `infiltration.gd`,
`level_solving_test.gd`, `level_solving_measure.gd`, the two docs pages,
the concepts line, `infiltration.csv` and the task file. The review also
read the solver's whole path for shared state: `LevelConstraints.solve`
and `_declare`, `ConstraintSolver`, `ConstraintProblem`, `ConstraintDraws`,
`LevelConstraintRules`, `LevelSketch`, `LevelGenerator.with_reserve` and
`BotArena`.

What holds:

- **Thread safety.** Every object the solve uses is built inside the
  task. That includes a local `RandomNumberGenerator`, the solver's own
  `ConstraintDraws` state, `ConstraintProblem`, `LevelSketch` and
  `BotArena`. The task reads two JSON files through `FileAccess` and
  `JSON.parse_string`. The repository has only two `static var`
  declarations outside gdUnit4: `InfiltrationWords`'s RegExes and
  `match_bot.gd`'s `_defaults`. Neither is on the solver's path. The task
  touches no node and no singleton state. The one member it writes,
  `_result`, is read by the main thread only after
  `wait_for_task_completion`, and `start` clears it before `add_task`.
- **Determinism.** `test_the_pool_solves_the_level_the_inline_call_solves`
  compares data, assignment, counts, restarts and the whole trace on seeds
  3, 54 and 144. The author planted seed + 1. This review planted
  `record=false` in the worker (`level_solving.gd:65`), and the test
  failed it with 3 failures.
- **Headless does exercise the threaded path.** The pool runs under
  `--headless`. The first two tests drive `LevelSolving` directly, and the
  scene test sets `solve_in_background = true`. So the decision to solve
  inline headless does not leave the threaded code untested. What goes
  untested is the scene's lifecycle around it (finding 2).
- **Wait discipline.** `wait()` is guarded by `busy()` and resets `_task`.
  A second wait, or a poll after the wait, returns null without calling
  the pool, and `test_one_solve_at_a_time` holds that. Every task is
  waited for: by `poll` once it completes, or by `_exit_tree`.
- **Lifecycle, measured by probe.** L pressed twice during a solve: the
  second level arrives, solved after the first. K back to drawn during a
  solve: the drawn world is kept when the stale solve ends. Scene freed
  during seed 144: `free()` blocks until the task ends, and `busy()` is
  false afterwards.
- `check_readability.py` exits 0. `level_solving.gd` is 65 lines, with a
  header that says what it solves, the complexity and when not to use it.
  Every function is short, and each doc comment says why. The doc page has
  its `source` URLs and `verified_on: 2026-11-05`. What it quotes from the
  4.7 `WorkerThreadPool` and thread-safe APIs pages matches those pages.

## Mutation round

| plant | where | caught by |
|---|---|---|
| worker solves with `record=false` | `level_solving.gd:65` | `test_the_pool_solves_...` (3 failures) |
| `_collect_solved` rebuilds the world unconditionally | `infiltration.gd:299-300` | **nothing in the PR**; probe `stale_solve_does_not_restart_the_drawn_world` |
| `_collect_solved` rebuilds only if the finished seed is the one now asked for (L mid-solve lost) | `infiltration.gd:299` | **nothing in the PR**; probe `l_mid_solve_reaches_the_level_asked_for` |
| `_exit_tree` no longer waits | `infiltration.gd:306` | **nothing in the PR**; probe `scene_freed_mid_solve` (busy after free) |

## Findings

1. **Should-fix: the panel says a level is coming when none is**
   (`infiltration.gd:335-336`). `_show` prepends "solving level N: this
   one plays until it is ready" whenever `_solving.busy()`. Take a stale
   solve: K pressed back to drawn mode, or L cycled onto a hand-made level,
   while a solve runs. The panel then promises the drawn or hand-made
   level will be replaced, and it will not be, for up to 2.5 s. *Proved
   by:* probe `panel_on_a_stale_solve` (L onto a generated level, K to
   drawn, one frame later the panel contains "solving level"). The line
   also names the seed being solved, not the one asked for. After L
   mid-solve it says "solving level 4" while level 5 is the one coming.
   *Fix:* show the line only while the current level is one waiting on a
   solve, for example when `_level()` returned null on the last build. Name
   the seed that will be played.
2. **Should-fix: the scene's lifecycle around the task has no test**
   (`infiltration.gd:294-306`; `level_solving_test.gd`). Three plants
   survive the PR's suite (table above). The first rebuilds the world when
   a stale solve ends, which restarts the drawn or hand-made level the
   person is playing. The second loses the level asked for by L
   mid-solve. The third drops the `_exit_tree` wait. Without that wait, a
   freed scene leaves the task never waited for. And because a `Callable`
   holds only the object's id, the scene's last reference to
   `LevelSolving` can drop while the worker is still writing `_result`
   into it. The code is right today. The three probes in
   `scratchpad/review-73/probe_test.gd` pass on the PR and fail each
   plant. *Fix:* add them, or tests like them, to `level_solving_test.gd`.
   Keep the panel probe (finding 1) in its own test, as a failing test
   hides the ones after it.
3. **Nit: the stall moves to leaving the scene** (`infiltration.gd:306`).
   Freeing the scene during seed 144 blocked the main thread for 3689 ms
   in the probe, under test load. Both pages say the scene waits. Neither
   says that the wait freezes the window for the rest of the solve, for
   example on Esc back to the menu. One sentence on
   `worker-thread-pool.md` would do (see owner item 2).
4. **Nit: two claims on `docs/godot/infiltration.md`.** Line 423 says the
   scene solves inline "in every seeded test", but `level_solving_test.gd`
   sets `solve_in_background = true` on purpose. "Headless, unless a test
   asks for the pool" is accurate. Line 417 quotes "solving level 144",
   which the demo cannot show (the PR's own decision 8).
5. **Nit: `worker-thread-pool.md:25` lists `OK` and
   `ERR_INVALID_PARAMETER` only.** The 4.7 page also lists `ERR_BUSY`,
   returned when the wait is made from inside another task and could
   deadlock. That case does not arise here, but the next reader of the
   page may nest tasks.
6. **Nit: `_exit_tree` discards the result** (`infiltration.gd:306`). A
   scene removed and added back mid-solve would come back with `busy()`
   false and the level never built. No current path re-adds the scene. A
   comment saying so is enough.

## For the owner

1. The PR's decisions 1-8 are sound as recommended. Decision 3 (headless
   inline) does not cost coverage of the pool itself. It does cost
   coverage of the scene's lifecycle, which finding 2 restores.
2. Leaving the scene mid-solve freezes the window for the rest of the
   solve, up to about 2.5 s on seed 144 (finding 3). The other answer is
   to hand the running `LevelSolving` to something that outlives the
   scene, such as an autoload that waits on it later. That is more
   machinery than the cost seems to deserve today. *Recommended:* keep the
   wait, and say so on the page.
3. The manual check names seed 144, and the demo cannot reach it
   (decision 8). The review agrees: check on seeds 3-5, and take a
   command-line seed as a follow-up only if you want to see 144.

## What was done about them

1. **Applied.** The panel no longer reads the pool. `Infiltration._awaited`
   holds the seed of the solved level that will replace the one played,
   or -1 when none will. It is set when a solve is asked for: L pressed
   mid-solve sets the next seed while the pool still runs the first. It
   is cleared whenever a world is built, for example K back to drawn or L
   onto a hand-made level. The panel names `_awaited`, and a finished
   solve rebuilds the world only while one is awaited. Two tests cover
   it. `test_a_solve_no_longer_wanted_leaves_the_level_played_alone`
   checks the panel on a drawn level. The first scene test checks that
   the panel names the level while it solves, and no longer afterwards.
2. **Applied.** The reviewer's probes are now three tests in
   `level_solving_test.gd`:
   - L pressed twice mid-solve reaches the level asked for last.
   - A solve that turns stale leaves the drawn world alone.
   - The scene freed mid-solve waits for the task.

   Four faults were planted one at a time, and each was caught by its own
   test: (a) an unconditional rebuild, (b) a rebuild only for the
   finished seed, (c) `_exit_tree` not waiting, and (d) the panel read
   from the pool, as before.
3. **Applied.** `docs/godot/infiltration.md` now says that leaving the
   scene mid-solve freezes the window for the rest of the solve: up to
   about 2.5 s on seed 144, and 3.7 s measured under load. It also says
   why the wait is kept. `worker-thread-pool.md` says the stall moves
   there. This is owner decision 9 in the PR, recommended: keep the wait.
4. **Applied.** The page now says headless solves inline "unless a test
   asks for the pool". It quotes "solving level 4", which the demo can
   show.
5. **Applied.** `worker-thread-pool.md` lists `ERR_BUSY`.
6. **Applied.** The comment on `_exit_tree` says the level is dropped and
   that nothing adds the scene back. A scene that was added back would
   have to ask again.
