# Review: wave/180-every-gate-checked

PR #138, task T141. Every Godot `-s` line in the `Makefile` (82 of them)
now runs through `scripts/godot_checked.py`. The wrapper gains
`--fixed-fps`, `--windowed` and a per-line `--expect-error`, and prints a
gate's output as it comes. A new lint, `make lint-godot-checked`
(`scripts/check_godot_checked.py`), refuses a line that bypasses the
wrapper. Only gdUnit4's runner is allowed, by name.

A fresh context reviewed head ff9bd7e. **Verdict: no blocker.** There is
one medium finding (the lint missed five spellings), one low finding (a
plant that did not protect what it named), and seven nits.

## What was reviewed

- The whole diff against the task, the PR body's decisions, CLAUDE.md
  invariants 1, 3, 4 and 11, "Readable by a person", the two `-s` traps,
  and `docs/howto/parallel-batch.md`.
- **The conversion.** Every `-s` line in main's `Makefile` was compared
  with its new form: the script, its arguments after `--`, `--fixed-fps 60`
  where the old line had it, `--windowed` for `measure-3d`'s two lines, and
  `measure-llm-requests`' probe inside its shell sequence, where `$?` now
  reads the wrapper's exit code.
- **The forgiven errors.** All four are named per line and each one is
  printed by a plant: the `PerceptionErrors` and `Racing3DErrors`
  counters' self-checks, `menu_walk`'s pushed error, and `demo_overlays`'
  crashing step. The two renamed plants still fail their own gate's
  planted case.
- **Authorship.** The commit and the PR body are by Adalberto Pereira,
  with no `Co-Authored-By`, no "Generated with" and no tooling byline.

The reviewer confirmed each spelling in finding 1 by appending one line to
the real `Makefile` and running `check_godot_checked.py`: each exited 0.
For finding 2, line 113 was mutated to check the script alone, and the
self-test still passed.

## Findings

### 1. Medium: the lint misses five spellings

`check_godot_checked.py:67-68,95-99` matched only `$(GODOT)` or
`scripts/godot` followed by `-s`, and only on lines that start with a tab.
Each of these passed it:

- `--script res://y.gd`, Godot's long form of `-s`;
- `${GODOT}`;
- a variable wrapping the command, `GODOT_RUN := $(GODOT) --headless
  --path godot`, then `$(GODOT_RUN) -s ...` in a recipe. Lines that do not
  start with a tab were skipped;
- a recipe on the rule's own line, `test-y: ; $(GODOT) ... -s ...`, which
  `RULE_HEAD` skipped;
- a `define` block that holds the command.

**Fix:** accept `--script`, `${GODOT}` and the `; recipe` form. Refuse any
line outside a recipe (a variable, a `define` body) that holds the Godot
command with `-s` or `--script`. Add one plant per spelling.

### 2. Low: the per-target plant did not protect per-target keying

The self-test case "the allowed script under another target" renamed the
allowed target. Mutating line 113 to check only the script still failed
that case, but only through the unused-allowance finding, so the mutation
passed. **Fix:** keep the allowed line, and add a second target that runs
the same script, so only the bypass finding can fail it.

### Nits

- `test-squad-match` (`$(or $(GAMES),100)`) and `measure-bandit`
  (`$(EXPLORATION)`) take a size a person sets: give them
  `--timeout 86400` like the others.
- Nothing proved the echoed stream shows the final output: dropping the
  last `echo(reader.read())` in `wait_and_echo` passed the self-test.
- `--expect-error`'s docstring should say it forgives every line holding
  the text, any number of times; the lines are not counted.
- `allow_abbrev=False` on both parsers, so `--expect` cannot quietly
  become `--expect-error`.
- `found = []` in `direct_runs` needs its type annotation.
- A missing Godot raised `FileNotFoundError` from `Popen`. Make it exit 2
  with a one-line message.
- Out of scope: `scripts/library_check.py:378` runs `-s` directly and
  judges it by its exit code and a marker. Open it as a task, not here.

## What was done about them

All of them were applied on the branch, in one commit:

- **Finding 1.** The lint now reads `-s` and `--script` (with a space or
  `=`), `$(NAME)` and `${NAME}`. It follows every variable or `define`
  whose value holds a Godot until none is new, so `$(GODOT_RUN)` counts.
  It reads what follows `;` on a rule's line as that target's recipe. A
  Godot with a script outside a recipe (a variable, a `define` body) is a
  finding that no allowance can excuse. There are six new plants:
  `${GODOT}`, `--script`, a rule-line recipe, a variable wrapping Godot, a
  variable holding the whole run, and a `define` holding the run.
- **Finding 2.** The plant now keeps `test-runner` and adds `test-other`
  running the same script. Each mutation was applied to a copy of the
  lint and its self-test went red ("caught"): script-only keying,
  `--script` dropped, `${GODOT}` dropped, the rule-line recipe ignored,
  wrapping variables not followed, `define` bodies skipped, and lines
  outside a recipe skipped. The lint has 14 planted Makefiles, plus a
  missing one.
- **Nits.**
  - `--timeout 86400` on `test-squad-match` and `measure-bandit`.
  - A plant `the last output shown after the gate ends`: a stub that
    prints once and exits must reach the echo. Dropping the final echo
    turns the self-test red, as checked.
  - The `--expect-error` docstring says the lines are not counted.
  - `allow_abbrev=False` on both parsers: `--expect` now exits 2.
  - `found` is annotated.
  - A Godot that cannot be started exits 2 and prints "could not start
    Godot (...); run make bootstrap". A plant covers it, and dropping the
    handling turns the self-test red.
  - `library_check.py` is T169, a new task file with its row in STATUS
    (todo, and not to run with T168, which edits the same file).

Re-run after the changes: `godot_checked.py --self-test` 0,
`check_godot_checked.py --self-test` 0, `make lint-godot-checked` 0 (82
findings on main's `Makefile`), `lint-selftests` 0, `lint-readability` 0,
`lint-tasks` 0, `lint-status` 0, `test-squad-match` 0.
