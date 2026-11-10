# Review: wave/167-cold-import

T148. A cold `./scripts/godot --headless --path godot --import` on 4.7.2
crashed with exit 139 in three reviews, each time passing on a rerun. The
PR measures it, finds the crash only with the engine's threaded import,
sets `[editor] import/use_multiple_threads=false` in `godot/project.godot`,
adds `scripts/check_import_threads.py` (`make lint-import-threads`, in
`check-no-engine`) to keep the line, and records the counts and the
upstream issue in `docs/godot/cold-import.md`. It adds no retry.

A fresh context reviewed PR #123 at head 0001f5e, based on 75caf84
(current `origin/main`, so the head under review is the rebased one).
**Verdict: approve. No blocker. Two shoulds and four nits.**

## What was reviewed

- The PR title and body, the task file, its decisions and its acceptance.
- `git diff origin/main...origin/wave/167-cold-import`: `Makefile`,
  `docs/godot/cold-import.md`, `godot/project.godot`,
  `scripts/check_import_threads.py` and the STATUS row.
- **The upstream issue, fetched** (`gh issue view 125245 -R
  godotengine/godot`): it exists, is open, was filed 2026-11-08 against
  `v4.7.2.stable.mono.official`, and reports exit 139 or 134 on a fresh
  `--headless --import` with the setting on (1 SIGSEGV in 27 runs), none
  in 54 with it off. One contributor comment asks for a test on master or
  4.8 beta 2; no fix is linked. #123622 and #125063 are both closed
  "not planned" with the `archived` label, as the page says.
- **The source at the `4.7.2-stable` tag**:
  `editor/file_system/editor_file_system.cpp`, `reimport_files`, reads
  `GLOBAL_GET("editor/import/use_multiple_threads")` under
  `THREADS_ENABLED` (forced `false` on web), and only then groups files of
  one importer into a `WorkerThreadPool` group task. So the setting is a
  project setting, as the page says. `ResourceImporterCSVTranslation`
  returns `true` from `can_import_threaded()`, so the twenty
  `res://locale/*.csv` do import as one threaded group, as the page says.
- **The official docs**: `doc/classes/ProjectSettings.xml` at the tag,
  `editor/import/use_multiple_threads`, `bool`, default `true`, "If true
  importing of resources is run on multiple threads."
- **That the line takes effect**: a `-s` probe in a scratch copy printed
  `ProjectSettings.get_setting("editor/import/use_multiple_threads")` as
  `false`.
- **The gate, planted on the real file** (copies in the scratchpad, never
  the checkout): the real `project.godot`, exit 0; the line set to `true`,
  exit 1; the line removed, exit 1; the line commented out, exit 1;
  `False`, exit 1; a missing project directory, exit 2; an unknown
  argument, exit 2. `--self-test`: 0 failures, and `run_selftests.py`
  finds it by name.
- **A cold-import sample**, in fresh copies of `godot/` from `git archive`
  plus gdUnit4, no `.godot/`, `--verbose`, sequential, load about 3-4 on
  12 threads: 30 runs with the setting `false`, all exit 0; then 30 with
  `true`, all exit 0 too. See finding 2.
- `python3 scripts/check_readability.py`, `make lint-tasks lint-status`,
  `make lint-docs-freshness`: 0.
- `make check-affected BASE=origin/main` on 0001f5e: see the end.

## Findings

1. **Should.** The page and the gate say more about #125245 than the issue
   does. The page says it "reports the same thing"; the gate's docstring
   says "The engine bug is upstream (godotengine/godot#125245)". The issue
   is a C# project, its crash handler faults inside libcoreclr's handler
   chain, its import has no CSV tables, and its core dumps put the fault
   on the **main** thread -- where the page puts this project's 139 on a
   **worker**, next to the CSV reimport. What the two share is the
   symptom (139/134 on a fresh headless import) and the workaround (the
   same setting off), not an established cause. Proposed fix: "reports a
   crash with the same symptom and the same workaround, in a C# project,
   with the fault on the main thread; whether it is the same race is not
   known" on the page, and "a similar crash is reported upstream" in the
   docstring and in `project.godot`'s comment. Optional, for the owner:
   the issue has no MRP and a contributor asked for one tested on 4.8
   beta 2; this repository, public, is one.

2. **Should.** The sample here did not reproduce the crash: 0 of 30 with
   the setting `true`. At the page's overall rate (11 in 115) that has a
   chance of about 5%; at its first row's rate (8 in 40, `--verbose`,
   nothing else running), well under 1%. That does not refute the
   author's numbers -- 11 of 115 against 0 of 160 is strong on its own
   (Fisher's exact test, two-sided, p about 1e-4) -- but it does say the
   rate depends on the machine's state more than the page lets on, and
   that "one run in ten" in the gate's finding text and in `Makefile` is
   one machine's afternoon. It matters for the page's own removal step:
   a loop that shows nothing on a new pin can be a quiet machine rather
   than a fix. Proposed fix: say on the page that the rate varied from 1
   in 50 to 1 in 5 across the rows, that a reviewer's 30 on the same
   machine showed none, and that the removal loop should run with
   `--verbose` and the setting **on at 4.7.2 first**, to show the loop
   can still see the crash before it is trusted to show its absence.

3. **Nit.** `invalidated_if` lists "the project stops importing CSV
   translation tables". The 134s were not tied to the CSV group, and the
   upstream report has no CSV at all, so dropping the tables would not
   make the line safe to remove. Proposed fix: drop that clause, leaving
   the pin and the upstream fix.

4. **Nit.** The gate reads the **first** `import/use_multiple_threads`
   line; Godot's `ProjectSettings::_load_settings_text` calls `set()` for
   each assignment in order, so the **last** one wins. A file with
   `=false` then `=true` under `[editor]` exits 0 here (measured) and
   imports on several threads. The editor never writes a duplicate, so
   this takes a hand edit or a bad merge. Proposed fix: keep reading and
   return the last match (or report a duplicate as a finding), with a
   planted case in the self-test.

5. **Nit.** The task's decision tied "the engine's" to the bounded retry.
   The PR found the bug to be the engine's and did not retry, on the
   reading that the task's first bullet allows "an import setting" as a
   fix on our side. I agree with that reading, and with the reason given
   (a retry on 139 would not catch the 134s, and the setting removes both),
   and the PR body puts it to the owner. But the task file is unchanged:
   its Notes do not record the outcome, and its Files line still names
   `scripts/godot` and `scripts/worktree_setup.py`, which were not
   touched. Proposed fix: a Notes line in T148 saying what was done
   instead of the retry and why, as recent tasks record their outcome.

6. **Nit.** One line of the gate's module docstring runs well past the
   others ("...`make check`. The engine bug is upstream
   (godotengine/godot#125245); the setting is"), a leftover from a joined
   paragraph. Proposed fix: rewrap; the readability gate does not measure
   docstring lines, so only a reader notices.

## Not findings

- **The setting's place is right.** `[editor]` plus
  `import/use_multiple_threads` is the project setting
  `editor/import/use_multiple_threads`, read with `GLOBAL_GET` at 4.7.2,
  and the probe saw it as `false`. It is not an editor setting, so
  `._sc_` and the editor's own settings file are not involved.
- **Fixing it on our side is the right reading of the task** (see 5 for
  the record only). A retry would have been the weaker fix: it hides one
  exit code and lets the other through, and it adds a fake-binary planted
  case to keep up for a crash the setting removes.
- **The gate's planted cases are real** and run on the real file, not only
  on the self-test's strings: `true`, removed and commented out each exit
  1, and 1 (a finding) stays apart from 2 (unreadable, or bad usage).
  The self-test also plants the empty file, the missing section, the
  wrong section and a missing file. It passes on nothing empty.
- **The message for the wrong section is accurate.** Under
  `[application]` the key becomes `application/import/use_multiple_threads`,
  which nothing reads.
- **The `;` comment in `project.godot`** follows the file's existing
  convention (its first six lines), so it is no new risk.
- **The page says when to remove the line**: a pin that fixes #125245,
  and a loop of cold imports first, not one green run. Finding 2 only
  asks that the loop be shown able to see the crash.
- **The cost claim** (3.2 s against 2.3 s cold) was not remeasured here:
  the sample's timer had no `bc` on this machine. The order of magnitude
  is not in doubt, and a warm import imports nothing either way.
- **The inference about `propagate_notification`** is labelled as an
  inference, with the reason (no symbols), as the house rule asks.
- **doc-meta** has `half_life`, `verified_on` (2026-11-10), `tier`,
  `source` (the issue, the docs and the source at the tag) and
  `invalidated_if`, and `lint-docs-freshness` passes.
- **Invariant 8**: the gate writes only in a `TemporaryDirectory`, and
  the samples here ran through `./scripts/godot`.
- The commit and the PR title and body carry no tooling byline.

## make check-affected

`make check-affected BASE=origin/main` on 0001f5e, run here after the
import sample had finished (it selects all of `make check`: `scripts/`
and `project.godot` are global): **exit 0**, first run, no timing gate
failed, so none needed a rerun. This closes the gap the PR body names
("the engine gates were not rerun on the rebased head"). The cold import
it starts with did not crash, with the setting off.

Its nine `SCRIPT ERROR` lines are the known planted ones and nothing
else: two "must implement ... abstract methods" and one "Cannot construct
abstract class `GakPathfinder`" from the abstract-port checks, and six
`Nonexistent function 'free' in base 'Nil'` at `step_decision`, which is
`demo_overlays.gd`'s planted crash. No signal 11 and no `handle_crash`
anywhere in the log.
