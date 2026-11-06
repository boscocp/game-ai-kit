# Review: wave/146-the-rts-frees-what-it-made-at-exit

T138. Closing `make demo-rts` printed `21 ObjectDB instances were leaked
at exit` and `15 resources still in use at exit`. The PR finds 15
`GDScript` and 6 `GDScriptNativeClass` left alive. It traces them to one
signature in `rts.gd`, `_clocked(side) -> GakRtsController`, and replaces it
with `_seat(sides, side) -> RtsHumanClock`. It adds `make test-rts-exit`, a
GDScript runner that starts a child Godot with `OS.execute` and reads the
two exit lines, with a planted leak. To let that runner pass, it adds a
by-path exception to V1 of `lint-llm-validated`, the net for invariant 7.

A fresh context reviewed PR #100 at head 8837f23 (base origin/main
b364e9f), in a throwaway worktree. It reproduced the leak, ran the gate
against main's `rts.gd` and against plants, and mutated the lint's new
exception one way at a time, restoring each change before the next and
clearing `__pycache__` afterwards. It made no commit, push or PR comment.

**Verdict: changes requested. No blocker, three should-fix findings and
two nits.** The fix works. The 21/15 reproduce on main, and the fixed
`rts.gd` closes clean in every load order tried. The gate is red on main,
green on the fix, and takes about 2 s. Three things need work. The
exception in invariant 7's net can be avoided. The runner can hang for an
hour. And the stated cause is narrower than what was measured.

## What was reviewed

- `CLAUDE.md` (invariants 4, 7, 11 and 12, "Check the documentation before
  writing the rule", the traps, the module rules), the task file
  `tasks/T138-the-rts-frees-what-it-made-at-exit.md`, and the PR body with
  its four decisions and five recommendations.
- The whole diff: `godot/game/rts/rts.gd`, `godot/test/rts/rts_exit.gd`,
  `godot/test/rts/planted_exit_leak.gd`, their `.uid` files, the
  `Makefile`, `modules/rts.json`, `scripts/check_llm_validated.py`,
  `docs/godot/exit-leaks.md` and the `tasks/STATUS.md` row.
- For context: `scripts/godot_checked.py`, `scripts/godot_shards.py`
  (`engine_errors`, `FORGIVEN`, `wait_or_kill`, `kill_tree`,
  `godot_command`), `godot/addons/ai_rts_core/rts_controller.gd`, every
  file that names `GakRtsController`, and the review record of wave 142
  for shape.

## What was run (at 8837f23 unless stated)

- `./scripts/godot --headless --path godot --import`: exit 0 on the first
  try. No exit 139 this time.
- With main's `rts.gd` swapped in: `./scripts/godot --headless --verbose
  --path godot res://game/rts/rts.tscn --quit-after 1` printed 21 and 15,
  with the same 15 `GDScript`, the same 6 `GDScriptNativeClass` and the
  same 15 paths the PR lists. `make test-rts-exit` was red. The script
  printed `rts exit: 1 failure(s)` and named all 15 files. (`make` reports
  it as 2.)
- `make test-rts-exit` on the head: green 5 times out of 5, about 2 s each,
  with no `SCRIPT ERROR` in the output.
- Load order, using a scratch `-s` script that only calls `load()` on its
  arguments:
  - main's `rts.gd` alone leaks 21/15.
  - With `rts_controller.gd` loaded first, it does not.
  - With `rts_command.gd` or `rts_snapshot.gd` loaded first, it still does.
  - The fixed `rts.tscn` is clean whichever script loads first. Tried with
    each of `addons/ai_rts_core/*.gd`, `game/rts/*.gd`,
    `game/league/rts_roster.gd` and `menu/*.gd`.
- Every `.gd` under `game/`, `game/*/`, `addons/ai_*/` and `menu/`, loaded
  alone (58 s). Only two leak: `game/squad/squad_ruleset.gd` and
  `game/squad/squad_map_words.gd`, each with 18 instances and 17
  resources. `game/league/rts_roster.gd` declares seven
  `-> GakRtsController` signatures and loads clean.
- Every `.tscn` under `game/` and `menu/`, run with `--quit-after 30`: all
  10 close clean, the RTS included.
- A plant in `planted_exit_leak.gd`: a call on a null `Node` before
  `quit()`. The runner hung, and `timeout 25` killed it at 25 s. No child
  Godot was left running.
- `check_llm_validated.py --self-test`: ok. `check_llm_validated.py`: 0.
  Mutations of the exception:
  - allowing `create_process` too: caught;
  - matching by folder: caught;
  - applying it to every file: caught;
  - matching by basename (`relative.name == EXIT_READER.name`): **not
    caught**.
- `make lint-modules lint-tasks lint-status lint-docs-freshness` and
  `check_readability.py`: all 0.
- Both commits are authored by Adalberto Pereira
  <adalbertobosco@gmail.com>. No trailer or tooling line appears in the
  commits, the PR title or the PR body.
- Upstream: two web searches found no Godot issue for this. They found one
  forum report of the same symptom on 4.3, with no root cause
  (forum.godotengine.org/t/95708). The search was not exhaustive, and the
  GitHub tracker was not searched directly.

## Findings

1. **should fix** -- `scripts/check_llm_validated.py:128-129, 243, 271`
   and `godot/test/rts/rts_exit.gd:57`. **The exception in invariant 7's
   net can be avoided.** It is narrow, which is why this is not a blocker:
   it is matched by exact path and allows only `execute`, and three of
   four mutations were caught. But it allows `rts_exit.gd` to run *any*
   program with any arguments, and the lint cannot see what is run. The
   PR rejects moving the reader to Python because "`godot_checked` counts
   `ERROR:` lines only". That argument applies to `godot_checked`, not to
   a reader written for this purpose. `godot_shards.py` already has
   `godot_command`, `wait_or_kill` and file-backed output. Its `FORGIVEN`
   tuple even ignores "resources still in use at exit" on purpose, so the
   leak lines are a deliberate per-gate choice, not a limitation.
   **Fix:**
   - Write `scripts/check_exit_leaks.py`. It runs `planted_exit_leak.gd`,
     then the scene with `--quit-after 30`, both through `scripts/godot`,
     and reads both lines.
   - Its `--self-test` holds the planted readings: a run that printed
     nothing, one that printed only the `WARNING`, and one that printed
     only the `ERROR`.
   - Point `test-rts-exit` at it and delete `rts_exit.gd`.
   - Revert every `check_llm_validated.py` change: V1 goes back to
     refusing any `OS.execute` outside `ai_llm`.

2. **should fix** -- `godot/test/rts/rts_exit.gd:57`. **The runner can
   hang for an hour.** `OS.execute(..., true)` waits with no deadline.
   Planted: a call on a null object in the child before `quit()` (the
   `-s` trap in `CLAUDE.md`). The gate never returned until killed. Under
   `make` it would sit until `godot_checked.py`'s default `TIMEOUT` of
   3600 s. **Fix:** finding 1's Python reader fixes this with
   `wait_or_kill(process, 60)` per child. If the GDScript runner stays,
   start the child with `OS.create_process` and poll
   `OS.is_process_running` against a deadline, then `OS.kill`. That needs
   yet more of the lint exception, which is one more reason for finding 1.

3. **should fix** -- `docs/godot/exit-leaks.md:50-60` and
   `godot/game/rts/rts.gd:169-173`. **The cause is stated as more proven
   than it is.** The comment says a signature "naming that port before
   anything had loaded it left 15 scripts alive". That is the observed
   trigger, not the mechanism:
   - `rts_roster.gd` declares seven `-> GakRtsController` signatures and
     loads clean as the first script.
   - The doc itself says the same signature in a three-line script did
     not leak.
   - Two squad scripts that do not name the port leak 18/17 when loaded
     first. Today's scenes do not load them first, but this is the same
     order-dependent kind of leak, in another module.

   The fix to `rts.gd` is still right, as a workaround. **Fix:**
   - Reword the comment above `_seat`, and the doc's "What leaked, and
     why", to say: "the trigger observed was ...; the engine mechanism is
     not identified; a Godot issue was not found".
   - Record the squad measurement in the doc.
   - Make the owner's recommendation 4 a task now: an exit check over
     every scene in `check_demos.py`'s list. It costs about 2 s a scene.

4. **nit** -- `docs/godot/exit-leaks.md:7`. `object.cpp` and `resource.cpp`
   are cited from `master`, and the command-line page from `en/4.5`. The
   text says they were read on 4.7.2-stable (`rts_exit.gd:9-10`). **Fix:**
   pin both source files to the `4.7.2-stable` tag, as the two gdscript
   files already are, and cite the docs version that matches.

5. **nit** -- `scripts/check_llm_validated.py:581`. The planted "another
   test file" is `rts_exit_copy.gd`. A mutation that matches the
   exception by basename survives the self-test. **Fix:** this goes away
   if finding 1 is taken. If not, plant a file with the same name in
   another folder, for example `godot/game/rts/rts_exit.gd`.

## What was done about them

1. Taken, at the coordinator's decision. `scripts/check_exit_leaks.py` runs the planted leak and then the scene through `godot_shards`' `godot_command`, `wait_or_kill` and `godot_checked`'s file-backed `run_to_file`, and reads both exit lines. Its `--self-test` refuses leaking readings (nothing printed, only the `WARNING`, only the `ERROR`) and passes a clean one. `make test-rts-exit` calls it. `rts_exit.gd` is deleted, and `check_llm_validated.py` is back to main's text, so V1 refuses any `OS.execute` outside `ai_llm` again.
2. Taken through 1. Each child runs under `wait_or_kill`, with `--timeout 60` in the Makefile. A planted call on a null `Node` before `quit()` in `planted_exit_leak.gd` made the gate exit 2 at a 10 s deadline, with no child left. The self-test plants a child that never ends, killed at 1 s.
3. Taken. The comment above `_seat` and the doc's section, now "What leaked, and what is known of why", call the signature the observed trigger and the fix a workaround. They say the engine mechanism is not identified. The doc records `rts_roster.gd`'s seven clean signatures, the squad scripts' 18/17, and the 4.3 forum report. T146, "Every demo closes without an exit leak", is opened for the check over every demo scene and the squad leak.
4. Taken. object.cpp and resource.cpp are cited at `4.7.2-stable`, and the doc cites their line numbers (2536, 817), which match what Godot printed. The command-line page is cited at `en/4.7`.
5. Gone with 1: there is no exception left to match by basename.

## Second review

PR #100, head ecf83becd400949741cb351c70dd5c402c601ec9. The reviewer did not write this code, and saw only the fixes applied after the first review. Each check below was run in a detached worktree of that head.

Verified:
- `python3 scripts/check_exit_leaks.py --self-test` passes. `run_selftests.py` finds it by glob.
- Six parser mutations were planted. The self-test caught five of them; finding 3 is the sixth.
- `make test-rts-exit` passes on the branch. With main's `rts.gd`, it fails 1 and names the 21/15 leak and each leaked instance.
- The planted child was made to abort before `quit()` (a call on null). With `--timeout 5`, the gate was killed at 5.0 s and exited 2, and no Godot process was left.
- Output goes through `run_to_file`, which writes to a file, not a pipe, so the 64 KiB pipe deadlock cannot happen.
- Usage errors exit 2.
- `git diff origin/main -- scripts/check_llm_validated.py` is empty. These all pass: `lint-llm-validated`, `lint-readability`, `lint-tasks`, `lint-status` and `lint-modules`.
- Invariant 11: no byline in the three commits, the PR title or the PR body.

Findings:

1. **should fix** -- `scripts/check_exit_leaks.py:80-89`. If the scene's script does not load, the gate still says "closed clean". Measured: with a parse error appended to `rts.gd`, the run exits 0, reads "closed clean" and returns 0. A three-line empty `.tscn` also passes. A scene that never ran its script leaks nothing, so this is the "passes on an empty scene" case of invariant 4. The output does show the failure: the broken run printed `SCRIPT ERROR: Parse Error` and `ERROR: Failed to load script "res://game/rts/rts.gd"`. A clean run of the branch's scene prints no `^(SCRIPT ERROR|ERROR):` line at all. **Fix:** in `scene_reading`, add every line that matches `godot_shards.ENGINE_ERROR` to `named`. Do not use `engine_errors()`, because it forgives the IN_USE line. Then add a self-test case: `scene_reading(scene, 0, started + "SCRIPT ERROR: Parse Error: x\n")` must give 1.

2. **should fix** -- `scripts/check_exit_leaks.py:84-85`. When the exit code is not 0, the gate prints only `<scene> exited N` and drops everything Godot printed. Measured: on `res://nope.tscn`, the only output was "exited 1", with no reason. **Fix:** on a nonzero exit, also print the engine-error lines, as `godot_checked.run` does. Optionally, treat a scene that cannot be opened as 2 (usage).

3. **nit** -- `scripts/check_exit_leaks.py:51/133`. The self-test does not hold the `"Leaked instance:"` entry of `NAMING`. Removing it from the tuple leaves the self-test at "ok". **Fix:** add a case `scene_reading(scene, 0, "Leaked instance: GDScript:1 - Reference count: 1\n")` that must give 1.

4. **should fix** -- `tasks/T146-every-demo-closes-without-an-exit-leak.md:44-49`. The goal is "every demo", but the acceptance runs only `make test-rts-exit` and the lints. If every acceptance command passes, a demo can still leak, so the goal is not a command (invariant 3). **Fix:** add the command the task builds, for example `make test-demos-exit`, or `python3 scripts/check_exit_leaks.py --every-demo`, named now and refined in step 3. Also add a line that runs the bisected squad case, for example `check_exit_leaks.py` on a scene or script that loads `squad_ruleset.gd` first.

5. **nit** -- `tasks/T146-...md:26`. "Each scene costs about 2 s" was not borne out. Here, the planted run and an RTS scene with `--quit-after 30` took 0.7 s together. **Fix:** cite the measurement and the machine, or drop the number.

The docs claim no more than was shown. `docs/godot/exit-leaks.md` and the `_seat` comment in `rts.gd` both call the signature the observed trigger and say the mechanism is not identified. T146 follows T135's format (header line, Goal, Decisions, Steps, Acceptance, Manual check, Notes), and its prerequisite is real (T138).

Verdict: **changes required**. Finding 1 lets the gate pass on a scene that never ran. Each fix is a few lines.

### What was done about the second review's findings

1. Taken. `scene_reading` now refuses a scene that printed any `^(SCRIPT ERROR|ERROR):` line (`godot_shards.ENGINE_ERROR`, not `engine_errors()`, which forgives the in-use line). An empty scene prints no engine error, so it is also refused when the verbose log shows no `Completed load for: '....gd'`: a scene that ran no script says nothing. Measured: a parse error appended to `rts.gd` now exits 1 and names `SCRIPT ERROR: Parse Error`. A three-line empty `.tscn` exits 1 with "loaded no script". Both self-test cases failed on the code before the fix (0, expected 1).
2. Taken. A nonzero exit prints its engine-error lines. On `res://nope.tscn` it prints `Cannot open file`, `Failed loading resource` and `Failed loading scene`, and exits 1. A self-test case holds that the reason is printed. It failed before the fix.
3. Taken. A self-test case reads a lone `Leaked instance:` line and must give 1. With that entry removed from `NAMING`, the self-test fails ("1 wrong").
4. Taken. T146 names its gate now, `make test-demos-exit`, and its acceptance runs it. A second line reads the squad case through a scene step 2 keeps, `godot/test/squad/exit_ruleset_first.tscn`.
5. Taken. Measured again: the RTS scene with the planted leak took 0.70 s in each of three runs (a Ryzen 5 9600X, 12 threads). T146 says that, with the machine, in place of "about 2 s".
