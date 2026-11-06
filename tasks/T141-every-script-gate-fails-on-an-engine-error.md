# T141 — Every `-s` gate fails on an engine error

Size: M · Prereqs: T88 · Files: `Makefile`, `scripts/godot_checked.py`, `godot/test/`

## Goal

The owner ratified on 2026-11-06 item 12 of STATUS's list of that date.
A `SCRIPT ERROR` in a `-s` gate aborts the function it is in, and a typed
function then returns its type's default: an empty `Array` reads as
"nothing wrong", and the gate prints its summary and exits 0 (CLAUDE.md's
traps). `scripts/godot_checked.py` (wave 136) fails a gate on any engine
error in its output, but only T88's duel runs through it. About eighty
other `-s` invocations in the `Makefile` do not.

## Decisions written down first (the owner confirms in review)

- **Every `-s` gate in the `Makefile` runs through `godot_checked.py`.**
  A gate that must print an engine error on purpose (an in-memory planted
  script) says so by an argument the wrapper reads, named per line, never
  a blanket switch.
- A lint (`make lint-godot-checked`, or a rule in an existing one) refuses
  a new `-s` line that bypasses the wrapper, with a planted `Makefile`
  line it must reject (invariant 4).
- The `Makefile` is global to `affected.py`, so this wave runs all of
  `make check`, and runs alone.

## Steps

1. List every `-s` invocation and what it prints today; note any that
   print an engine error already.
2. Move them, a family at a time, through the wrapper.
3. The lint and its planted case.

## Acceptance

```bash
python3 scripts/godot_checked.py --self-test
make check
make lint-tasks lint-status
```

## Manual check

None.

## Notes

- Opened by the owner's ratification of item 12 (2026-11-06). The trap
  itself went into CLAUDE.md the same day.
- Runs alone: it touches every module's gate line.
