# T162 — Loading every addon closes clean

Size: S · Prereqs: T159, T146 · Files: `godot/addons/`, `scripts/check_published.py`, `scripts/store/load_every_class.gd`, `docs/godot/exit-leaks.md`

## Goal

On 2026-11-10 the owner installed the kit from the editor's AssetLib tab
into an empty project. T159's loader, `scripts/store/load_every_class.gd`,
loaded all 107 scripts and counted 107 `class_name`s, and printed no
`SCRIPT ERROR`. At exit, though, the engine printed:

```
ERROR: 7 resources still in use at exit (run with --verbose for details).
```

`godot_checked.py` does not count that line as an engine error, so the run
exited 0. T146 found leaks of the same kind in the demos. There, which
script the engine compiled first decided whether a leak appeared. This
one appears in what a stranger installs, so it is fixed before 0.2.0
(T161).

## Decisions written down first

_The owner asked for this task on 2026-11-10, after the store install.
This session proposes the decisions below; the wave confirms them._

- **Measure first.** Run the loader with `--verbose` in a blank project
  holding the 0.1.0 archive. Then run it on HEAD's kit zip, since main
  has `ai_bayes` and the flock rules. Name the 7 resources and the
  addon(s) they come from. Bisect by addon, using T146's method in
  `docs/godot/exit-leaks.md`.
- **Fix it in the addon, not in the loader.** A user who loads the kit
  the same way would see the same line. If the cause is the engine's
  compile order, as in T146, the page says so, and the fix is the
  smallest change to the addon that removes the trigger.
- **The check fails on it.** `check_published.py`'s install step, and
  `library-check`'s install of the kit zip from T160, treat "still in use
  at exit" or "leaked at exit" as a finding. A planted case shows the
  check catching it.

## Acceptance

```bash
python3 scripts/check_published.py --self-test
make library-check
make test-demos-exit
```

## Manual check

- In an empty project, install HEAD's kit zip, open it in the editor and
  close it. The output panel's last lines say nothing about resources
  still in use.
