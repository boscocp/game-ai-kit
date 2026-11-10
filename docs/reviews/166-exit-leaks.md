# Review: wave/166-exit-leaks

The PR closes T146. It adds `check_exit_leaks.py --demos`, which sweeps
every scene in `check_demos.py`'s list after one planted leak, and two
targets: `make test-demos-exit`, owned by `menu`, and `make test-squad-exit`,
owned by `squad`. It also removes two leaks in game code:

- `SquadRuleset.build_controller`'s `is/as SearchingSquad` moves to
  `SquadRoster.for_the_scene`;
- in the behaviour demo, `BrainPanel._draw` tells the brains apart by the
  keys `thinking()` returns, and `GuardBrain.every()` builds the four
  brains.

A fresh context reviewed PR #124 at the branch head. **Verdict: approve
after the shoulds, no blocker. There are four shoulds and three nits.**
The gates are real, and the squad fix is held by its own planted case.
The behaviour demo's fix is held by the sweep, but not in the way the
page tells it: one of its two changes is held by nothing.

## What was reviewed

- **The planted cases, reverted one at a time in this worktree and then
  restored.**
  - `squad_ruleset.gd` at `origin/main`: `check_exit_leaks.py
    res://test/squad/exit_ruleset_first.tscn` exits **1**, with 18
    objects and 17 resources, as the page says. At the head it exits 0.
  - `brain_panel.gd`, `behaviour_demo.gd` and `guard_brain.gd`, all three
    at `origin/main`: `--demos` exits **1**. `behaviour_demo.tscn`
    leaks 36 objects, 27 resources and 7 dummy-texture RIDs. The other 16
    scenes close clean.
  - Each behaviour change alone, measured in the scene and with a scratch
    `-s` loader. The results are in finding 1.
- **The self-test.** `--self-test` exits 0. Each new case was tested on a
  scratch copy of the script, with `scripts/` on the path, and the tree
  was left untouched:
  - dropping the empty-list refusal makes "a sweep of no scene" fail;
  - truncating or unsorting `demo_scenes` makes "the demo list" fail;
  - keeping the last scene's code instead of the worst survives
    (finding 2).
- **Exit codes, called directly and not through make.**
  - Exit 2: no argument, and both `--demos` and a scene.
  - Exit 1: a leak, as above.
  - Exit 0: the head, with `--demos` at 17 scenes in 15.3 s at load 18,
    and with the case scene.
  - A killed child is 2 (`scene_reading`). Under `max`, a killed child
    hides a leak in another scene behind exit 2 (nit 7).
- **Behaviour.**
  - `GuardFsm.thinking()` returns `states` and `GuardTree.thinking()`
    returns `trail`. GOAP and HTN return neither, so they still reach
    `_plan_rows`.
  - `for_the_scene` is the old body moved, line for line. Its only
    caller is `SquadRuleset.build_controller`. The duel and match runners
    still call `SquadRoster.build`, unchanged.
  - `make test-godot-some SUITES="test/squad test/demo_behaviour"`:
    141/141 passed, 14 suites.
  - `make test-demo-overlays`: 17 examples and 1 more mode in pt_BR, 0
    failures. The `SCRIPT ERROR`s it prints are the planted anonymous
    `gdscript://` scripts, and nothing else.
- **Squad mode, by hand.** `--quit-after 60 -- --open=demo-tactical
  --mode=squad` loads `squad_ruleset.gd` and prints no leak line. The
  sweep does not run this form (finding 3).
- **Modules.**
  - `check_modules.py`: ok, 40 modules.
  - With `affected.py --paths`, a change to `brain_panel.gd`,
    `racing3d.gd`, `ai_fuzzy`, `game/main.gd` or `squad_roster.gd`
    selects `test-demos-exit`. A change to `squad_roster.gd`,
    `tactical_rules.gd`, `board/unit.gd` or `ai_constraints` also
    selects `test-squad-exit`, so the scripts that the case compiles
    through select it.
  - The Makefile diff only adds lines: two new targets after
    `test-rts-exit`, and nothing removed.
- **Timing gates, each run alone.**
  - `make test-rts-budget`: 0 failures, at load average 4.82 (1 min),
    9.76 (5 min).
  - `make test-rts-flock`: 0 failures, at load average 4.84 (1 min),
    9.68 (5 min).
  - Rerun alone at 13:24, at load average 10-13 (1 min), both failed.
    The flock's mean was 5.41 ms against a 4.0 ms share, where it had
    been 2.70 ms at load 4.8.
  - They pass at low load and fail at high load, with the same code. So
    the failures are load, not regressions. Neither module is touched by
    this PR.
- `make check-affected BASE=origin/main` selects everything: the
  Makefile, the manifests and `check_exit_leaks.py` are global. It ran 47
  minutes, with load between 4 and 15 from other worktrees.
  - It reached `test-rts-flock` and stopped there. The flock's mean was
    5.28 ms against a 4.0 ms share.
  - Every gate before it was green, `test-demos-exit` and
    `test-squad-exit` included.
  - Its output has 9 `SCRIPT ERROR`s, and each is planted: six
    `step_decision` errors in `demo_overlays`' anonymous scripts, and
    three `GDScript::reload` parse errors from the interface tests'
    "forgets to implement" and "cannot construct" cases.
  - The targets after `test-rts-flock` in `make check`'s order did not
    run in this pass.

## Findings

1. **Should. The behaviour demo's "two triggers" are not what the scene
   measures, and the `BrainPanel` change is held by no gate.** Measured
   here, the scene and the scratch `-s` loader disagree:

   | Changes from the PR present | `behaviour_demo.tscn` | `brain_panel.gd` loaded first |
   |---|---|---|
   | all three | clean | clean |
   | `GuardBrain.every()` only (old panel, old inline list) | **clean** | clean |
   | the panel only (old `swap_brain`, no `every()`) | **leaks 36/27** | clean |
   | none | leaks 36/27 | leaks 16/15 |

   So in the scene, adding `every()` to `guard_brain.gd` is enough, even
   with nothing calling it. Reverting the panel change, or `swap_brain`,
   leaves every gate green. Three things follow:

   - The page's "two triggers" is true only of scripts loaded alone.
   - "Each was fixed by naming that class somewhere else" does not hold
     for the scene. The old inline list in `BehaviourDemo` closes clean
     once `GuardBrain` names its subclasses.
   - The panel now dispatches on dictionary keys instead of `is GuardFsm`.
     That is a cost to the reader (invariant 1), and no gate pays it back.

   One number also disagrees: `GuardBrain.every()`'s comment says 22
   objects, and the page says 36.

   **Fix:** choose one of two.
   - (a) Revert the `BrainPanel` change, keep `is GuardFsm`, and let
     `every()` carry the fix.
   - (b) Keep the change and give it a planted case. That would be a bare
     scene whose script loads `brain_panel.gd` first, held like
     `exit_ruleset_first`.

   Either way, rewrite the page's behaviour paragraph with the table above
   and reconcile 22 with 36.

2. **Should. `run`'s "worst scene's code" has no planted case.** Replace
   `worst = max(worst, code)` with `worst = code` and `--self-test` still
   says ok. With the behaviour demo leaking, it is first in the sorted
   list, so that mutant would print `exit 1` for it and then exit 0 for
   the sweep. Every self-test case today either asks a reading of planted
   output or calls `run([])`, and none sweeps two scenes.
   **Fix:** factor the fold into a pure function, for example
   `sweep_code(codes: list[int]) -> int`, and call it from `run`. Then
   add the case `[1, 0] -> 1` to the self-test, and `[0, 2, 1]` for
   whatever nit 7 decides.

3. **Should. The sweep checks scenes, not modes, and the squad scene is a
   mode.** The XCOM board is reached only through the menu, as
   `-- --open=demo-tactical --mode=squad`. `test-demo-overlays` holds
   that form ("1 more mode"). `--demos` runs `game/tactical/tactical.tscn`
   in Advance Wars only, and `game/main.tscn` with no arguments. Today
   squad mode closes clean (measured by hand, above), and
   `test-squad-exit` holds the one trigger found. But the sweep's claim,
   "every demo", is wider than what it runs, and T146's manual check is
   exactly that mode.
   **Fix:** read the extra modes from the same overlays file, and run each
   through `main.tscn` with its user arguments. Failing that, say on the
   page and in the target's comment that modes are not swept, and keep
   the manual check.

4. **Should. The module decision departs from the options written down
   first, and the owner has not confirmed it yet.** The task's decision
   offered two options: one target per scene, or one target that the
   selector maps to the changed scenes. The PR does neither. It ships one
   target that runs all 17 scenes whenever any example or addon changes.
   Its reasoning is in step 3 of the notes: about 10 s, and no second
   list. It holds with `check_modules.py` (M7, one owner) and with
   `affected.py`. It is still a third option, though, and the task says
   "the owner confirms in review".
   **Fix:** name it in the PR body as an owner decision to confirm. If
   confirmed, record it in STATUS's decisions with the measured time:
   15.3 s here at load 18, and about 10 s quiet.

5. **Nit. `--self-test` prints a gate's message as if it were a finding.**
   The case `run([], ...)` prints "no scene to check: a sweep of none
   would read as clean" above "self-test: ok". Someone reading the log
   sees a failure line on a green run.
   **Fix:** with the fold factored out as in finding 2, test the empty
   case on a pure function. Or have `run` return the reason, and let
   `main` print it.

6. **Nit. Nothing tests that the scene's enemy searches a frame at a
   time.** `squad_rules_test` checks only the controllers' names. If
   `for_the_scene` quietly lost its `spread_over_frames`, no test would
   fail. That was true before this PR too, but the code has just moved.
   **Fix:** one assertion, in the squad tests, that `build_controller`
   returns an MCTS controller whose work per frame is set. That needs a
   read-only accessor, or the check goes through `step_decision`'s
   behaviour.

7. **Nit. Under `max`, a scene killed at the deadline (2) hides another
   scene's leak (1) behind "usage or unreadable".** Each scene's line is
   still printed, so nothing is lost from the log. Only the exit code
   says less than it could.
   **Fix:** decide which wins and say it in the docstring's exit codes.
   1 winning over 2 fits the house meaning of 2 better.

## Not findings

- `exit_ruleset_first.gd`'s unused parameter and empty body are the
  point of the case, and the page says why it is kept bare.
- The page says honestly that the engine mechanism is not identified, and
  that compile order is part of it. It lists the extra scripts that each
  hid the leak, and that `every()` in `GuardActions` closed clean too.
- `test-rts-exit` staying beside the sweep is right. It is in T138's
  acceptance, and `rts` owns it.
- `from check_demos import listed_scenes` reads the one list, and it is
  not a dependency between addons (invariant 2 is about `godot/addons/`).
- `run` is 25 lines with nesting 3, within the house limits.
- `test-rts-budget` and `test-rts-flock` pass alone at low load.
- The `SCRIPT ERROR` lines in `test-demo-overlays` are its planted
  anonymous scripts.

## What was done about them

1. **Done, option (a).** `brain_panel.gd` is back as it is on `main`,
   with `is GuardFsm` and `is GuardTree`. `GuardBrain.every()` carries the
   fix, and `swap_brain` still calls it. Remeasured after the revert:
   `behaviour_demo.tscn` closed clean in three runs, and `brain_panel.gd`
   loaded first closes clean. `every()`'s comment now gives 36/27 for the
   scene and 22/20 for `behaviour_demo.gd` loaded alone. The page's
   behaviour paragraph is this review's table, a row added for what
   ships. It says that `every()` works even uncalled, and that the panel
   change was reverted because it fixed only the script loaded alone.
2. **Done.** `sweep_code(codes)` is the fold, and `run` calls it. The
   self-test plants five cases on it: `[1, 0]` and `[0, 1]` give 1,
   `[0, 2, 1]` gives 1, `[0, 2]` gives 2 and `[0, 0]` gives 0. A mutant
   that keeps the last code fails the first case.
3. **Done.** `--demos` also runs every key of `demo_overlays.gd`'s
   `MODE_REQUIRED`. Each one is opened through the menu, with the card's
   target from `menu/catalogue.json`: `-- --open=demo-tactical
   --mode=squad`, the form `make demo-tactical MODE=squad` uses. A mode
   whose scene has no card fails 1. A verbose run of that form loads
   `squad_ruleset.gd` and `squad_view.gd`. The self-test plants a
   catalogue and an overlays file, and reads two modes from them: one
   with a card, one without. A key in another block is ignored. The sweep
   now prints "18 scene(s) and mode(s)" and took 9 s. The page and the
   target's comment say so.
4. **The owner's decision.** On 2026-11-10 the owner approved one
   `make test-demos-exit` target, owned by `menu` and sweeping all 17
   scenes. The task's Notes and the STATUS row record it. The code is
   unchanged.
5. **Done.** The empty case is asked of `sweep_code([])` now, not of
   `run([])`. A green self-test prints only "self-test: ok".
6. **Not done.** It is optional, and it needs a read-only accessor on
   `SearchingSquad`, which is a change of its own.
7. **Done.** A leak wins over a kill. That is in `sweep_code`'s doc
   comment, in the exit codes in the script's docstring, and on the page.
