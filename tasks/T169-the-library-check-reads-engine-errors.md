# T169 — The library check fails on an engine error

Size: S · Prereqs: T141 · Files: `scripts/library_check.py`

## Goal

T141 (wave 180) made every `-s` line in the `Makefile` run through
`godot_checked.py`, so a `SCRIPT ERROR` fails a run that exits 0.
`library_check.py` starts Godot on its own: `run_runner` runs
`stranger.gd -s` in a blank project and judges it by the exit code and a
marker the example prints. If a `SCRIPT ERROR` is printed after the marker,
or in a function that still lets the marker print, the run still passes.
`lint-godot-checked` reads only the `Makefile`, so it does not see this.

## Decisions written down first

_From the review of wave 180, 2026-11-11. The wave confirms the details._

- **Read the output the way the wrapper does.** `run_runner` judges its
  run with `godot_checked.verdict` (or its `engine_errors`): an engine
  error that is not forgiven fails the step, as the exit code and the
  missing marker already do. It should reuse the wrapper's code, not copy
  it.
- **A planted case.** A planted runner that prints the marker and then a
  `SCRIPT ERROR` must fail the self-test, beside the `silent_runner` case
  that is already there.
- Keep T168 in mind: it makes the same self-test faster, so the two waves
  touch the same file and do not run together.

## Acceptance

```bash
python3 scripts/library_check.py --self-test
make lint-selftests
```

## Manual check

None.

## Notes

- Out of T141's scope on purpose: T141 is about the `Makefile`'s lines,
  and this runner lives inside a Python gate that already has its own
  planted cases.
- Left open by wave 185 (its review): the two `--import` runs go through
  `run_blocks`, which reads only the exit code, not engine errors as
  `check_published.install_findings` does. Measured by the review, a
  broken script or `.tres` imports today with exit 0 and no `ERROR`
  line, so reading them would show nothing yet.
