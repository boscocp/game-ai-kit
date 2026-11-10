# T148 — A cold import that crashes is explained, or survived

Size: S · Prereqs: T112 · Files: `godot/project.godot`, `scripts/check_import_threads.py`, `Makefile`, `docs/godot/cold-import.md`

## Goal

`./scripts/godot --headless --path godot --import` on a cold cache (a new
worktree, or after `git clean`) has crashed with signal 11, exit 139, at
least three times on 4.7.2: the review of wave 140 (T120), the full
`make check` before #90 merged (wave 142), and the review of wave 147
(T134). Each time a rerun passed. STATUS of 2026-11-06 said "if it comes
back, it is one"; it came back. A stranger's first `make check` may be
the run that crashes, and it reads as the kit's fault.

## Decisions written down first (the owner confirms in review)

- **Measure before retrying.** Reproduce it in a loop of fresh worktrees,
  with `--verbose`, and keep the backtrace. Read the 4.7.2 issue tracker
  for a known crash on import. If the cause is ours (an addon, a resource,
  an import setting), fix it there.
- **Only if it is the engine's**: the import step retries once on exit
  139, says so on stderr, and records the engine issue in `docs/godot/`.
  A second crash fails as before. No retry hides any other exit code.
- A retry has a planted case: a fake binary that crashes once passes with
  the note, one that crashes twice fails (invariant 4).

## Steps

1. Reproduce and record (count, backtrace, load).
2. Fix the cause, or the bounded retry with its planted case.

## Acceptance

```bash
make worktree-setup
make lint-selftests
make lint-tasks lint-status
```

## Manual check

None.

## Notes

- After T113-T115, with the other follow-ups (the owner, 2026-11-06).
- Done in wave 167, with no retry. The crash is the engine's, but it
  happens only with `editor/import/use_multiple_threads` on. That is an
  import setting, which the first decision counts as a fix on our side.
  So `project.godot` turns it off and `lint-import-threads` keeps the line.
  A retry on exit 139 would also have let the exit 134s through, the
  shutdown crash the setting removes too. Counts, the upstream issue and
  when to take the line out: `docs/godot/cold-import.md`.
