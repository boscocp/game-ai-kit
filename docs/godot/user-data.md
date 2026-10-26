# Where `user://` lives, and why each checkout has its own

<!-- doc-meta
half_life: practice
verified_on: 2026-10-26
tier: 1
source: https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html ; https://docs.godotengine.org/en/stable/classes/class_os.html#class-os-method-get-user-data-dir ; https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html
invalidated_if: Godot stops deriving user:// from XDG_DATA_HOME (APPDATA on Windows), gains a command-line option for it, or gdUnit4 stops clearing user://tmp after each suite
teaches: none
-->

> T83, wave 93. What the 4.7 documentation says about `user://`, what was
> measured on the pinned engine (4.7.2) from two checkouts, and the decision
> it led to (ADR 0022).

## What the documentation says

Read on 2026-10-26, the 4.7 pages:

- `user://` is `~/.local/share/godot/app_userdata/[project_name]` on Linux
  and `%APPDATA%\Godot\app_userdata\[project_name]` on Windows. Godot
  follows the XDG base directories on Linux, and `XDG_DATA_HOME`,
  `XDG_CONFIG_HOME` and `XDG_CACHE_HOME` "change the editor and project data
  paths".
- `OS.get_user_data_dir()` "returns the absolute directory path where user
  data is written (the `user://` directory in Godot)".
- Self-contained mode (`._sc_` beside the binary) moves "all editor data,
  settings, and cache" into `editor_data/`. It says nothing of `user://`,
  and ADR 0002 measured that it does not cover it.
- `application/config/use_custom_user_dir` and `custom_user_dir_name` rename
  the folder; they live in `project.godot`, which every checkout shares, so
  they cannot tell two checkouts apart.
- The command line has no option for the user data directory; `--log-file`
  moves only the log.

So the environment is the one per-process handle there is, and
`scripts/godot` is the one place that sets it.

## What was measured

1. **Before T83, two checkouts, one directory.** A `-s` script printing
   `OS.get_user_data_dir()`, run through `scripts/godot` from this worktree
   and from a second clone, printed the same path from both:
   `/mnt/games/gamedev/toolchain/xdg/godot/app_userdata/game-ai-kit`.
2. **After it, two.** The same script printed
   `<checkout>/.user-data/xdg/godot/app_userdata/game-ai-kit` in each,
   and `OS.get_data_dir()` printed `<checkout>/.user-data/xdg`.
3. **Godot makes the folder itself.** With `XDG_DATA_HOME` pointed at a path
   that did not exist, a run created it down to
   `godot/app_userdata/game-ai-kit/logs` and nothing appeared under `~`. The
   wrapper therefore does not `mkdir` it.
4. **How the collision happened.** gdUnit4 v6.2.2 keeps a suite's temporary
   files under `user://tmp` (`create_temp_dir`) and deletes the whole of
   `user://tmp` after every suite (`GdUnitTestSuiteAfterStage` calls
   `GdUnitFileAccess.clear_tmp()`). The botmatch effects shards test writes
   its shards there and reads them back. With one `user://` for every
   checkout, the end of *any* suite in another checkout deletes them. Shown
   without a race: checkout one left `user://tmp/marker.txt`, checkout two
   ran `test/locale/language_test.gd`, and the marker was gone, both
   pointed at one scratch `XDG_DATA_HOME`. Through each checkout's own
   `scripts/godot`, the marker was still there.
5. **Two checkouts testing at once.** `make test-godot-some
   SUITES="test/locale test/ai_planning"` started at the same moment in both
   checkouts: 63 of 63 cases passed in each, and each wrote its own logs
   and `planning_vector_test/` folder. Six rounds of the shards test against
   another checkout's suites in a loop did *not* fail on the shared layout:
   the window lasts milliseconds, which is why it failed once in many
   waves and not every time.

## What the repository does with it

- `scripts/godot` sets `XDG_DATA_HOME=<checkout>/.user-data/xdg` (Windows:
  `APPDATA` and `LOCALAPPDATA` under `<checkout>/.user-data/`, written as
  `D:/...` by `pwd -W`). `.user-data/` is ignored by git.
- `scripts/godot --gak-print-redirect` prints that redirect and exits
  without starting Godot. `bootstrap.sh`, `export.py` and
  `check_disk_layout.py` ask it rather than repeat the rule.
- `check_disk_layout.py` asks every checkout `git worktree list` names:
  D6 a `user://` under home, D7 two checkouts sharing one, D8 one outside
  its own checkout, inside `godot/`, or not ignored by git. These are
  findings for the checkout running the gate (D7 for a pair it is in). In
  another worktree they are notes.
- A `.user-data/` is inside the checkout, so the repo-wide scanners skip
  dot folders below their root (`check_readability.py`,
  `check_no_training.py`). gdUnit4 leaves `.gd` mocks in `user://tmp` when
  a run is killed.
- A test that writes `user://` still uses a file of its own and removes it:
  within one checkout, the suites of one run share it.
