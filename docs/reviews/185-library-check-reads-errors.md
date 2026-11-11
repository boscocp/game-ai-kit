# Review: wave/185-library-check-reads-errors

PR #143, task T169. `library_check.py`'s `run_runner` now fails a
`stranger.gd -s` run that exits 0 and prints its marker but also prints
an engine error. It reads those errors with `godot_shards.engine_errors`
and its `FORGIVEN`. A planted runner prints the marker, asks to quit,
then hits a `SCRIPT ERROR`.

A fresh context reviewed head 56e6358. **Verdict: no blocker.** There
are two nits to apply and one note that needs no action.

## What was reviewed

- The whole diff against the task and its decisions, CLAUDE.md
  invariants 1, 4 and 11, and the two traps about `-s` scripts: an
  aborted function goes on, and a typed function returns its default.
- **The plant, by mutation.** Two mutations were tried. Dropping the
  engine-error read turned the self-test red on the new plant. So did
  reading `stdout` alone, which shows the error reaches the output the
  check reads.
- **The real check** exits 0, so `stranger.gd` prints no error that is
  not forgiven today. The self-test stayed stable on repeated runs under
  load.
- **Authorship.** The commit and the PR body are by Adalberto Pereira,
  with no `Co-Authored-By`, no "Generated with" and no tooling byline.

## Findings

### Nits

1. The two `--import` runs go through `run_blocks`, which checks only
   the exit code and never reads engine errors.
   `check_published.install_findings` does read them. The reviewer
   measured that a broken script or `.tres` imports with exit 0 and no
   `ERROR` line today, so reading them would show nothing yet. **Fix:**
   name the gap in T169's notes and its STATUS row. Change the code only
   if that is trivial.
2. The missing-marker branch filtered lines with a plain
   `"ERROR" in line`. **Fix:** use `engine_errors` there too.
3. No action needed: `BROKEN_RUNNER` covers only `route`. That is
   enough, because `infer` and `kit` use the same `run_runner`. Say so
   in a comment beside the plant.

## What was done about them

All three were applied on the branch in one push. Main had not moved
since e04059a, so the branch needed no rebase.

- **Nit 1: named, not coded.** T169's notes and its STATUS row now name
  the gap and the review's measurement. Reading the import's output
  would make `run_blocks` know which block is an import, and it would
  have nothing to catch on the pinned engine.
- **Nit 2.** `run_runner` now reads `engine_errors` once, before both
  branches. The missing-marker finding lists the first five of those
  errors, so a forgiven line no longer shows up in it.
- **Note 3.** A comment beside `BROKEN_RUNNER` says the plant is
  `route`'s alone. `infer` and `kit` reach the same `run_runner`, and a
  follow stops at its first failing step.

Re-run after the changes:

| check | exit |
|---|---|
| `library_check.py --self-test` | 0 |
| `make lint-readability lint-tasks lint-status` | 0 |
| `check_branch_base.py --check-review` | 0 |
