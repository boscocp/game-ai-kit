# T141 — Every `-s` gate fails on an engine error

Size: M · Prereqs: T88 · Files: `Makefile`, `scripts/godot_checked.py`, `scripts/check_godot_checked.py`, `godot/test/menu/`

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
python3 scripts/check_godot_checked.py --self-test
make lint-godot-checked
make check
make lint-tasks lint-status
```

## Manual check

None.

## Notes

- Opened by the owner's ratification of item 12 (2026-11-06). The trap
  itself went into CLAUDE.md the same day.
- Runs alone: it touches every module's gate line.

## What wave 180 decided and found (the owner confirms in review)

**Every `-s` line, gate or not.** All 82 `$(GODOT) ... -s` lines that
started a script now run through `godot_checked.py`: the gates, and the
measurements, recordings and exports too (`measure-*`, `rts-measure`,
`league`, `rts-league`, `tactical-win-rates`, `record-replay`,
`record-stand-ins`, `clone-rows`, `record-talk`, `fighter-strips`'
`crop.gd`, `measure-llm-requests`' probe). A recording or a table built
by a script that stopped half-way is the same silent wrong answer as a
gate's. The ones whose size a person sets (`GAMES`, `SEEDS`, a model)
carry `--timeout 86400`, as `measure-squad-duel` already did (review 180 added `test-squad-match` and `measure-bandit`).

**Left starting Godot itself, named in `check_godot_checked.py`'s
`ALLOWED`, one target and one script each:**

- `test-godot`, `res://addons/gdUnit4/bin/GdUnitCmdTool.gd`: gdUnit4's
  runner reports a failed test itself, and its suites provoke engine
  errors on purpose as they test.
- `test-godot-some`, the same runner on the suites `SUITES` names.

**The wrapper's new options.** `--fixed-fps N` (the 3D racer's gates and
`test-locale-screen`), `--windowed` (no `--headless`: `measure-3d` times a
real renderer), and `--expect-error TEXT`, given once per error on the
line that needs it: an error line holding TEXT is forgiven, a blank TEXT
is refused, and an expected error that is NOT printed fails the run (the
plant did not happen). The wrapper now prints a gate's output as it comes,
every half second, so a fifteen-minute gate does not look hung.

**Gates that went red when wrapped.** Each printed an engine error on
purpose; none was a hidden failure:

- The error counters `PerceptionErrors` and `Racing3DErrors` push one
  planted error before each gate that uses them (invariant 4). Named on
  each of those lines by `$(PERCEPTION_PLANT)` or `$(RACING3D_PLANT)`:
  `test-perception-vectors`, `test-infiltration`,
  `test-infiltration-properties`, `test-infiltration-tracking`,
  `test-racing3d-vectors` and the five `test-racing3d-*` gates.
- `test-menu-walk`'s planted example pushed `ERROR: planted`, a text too
  common to forgive; it now says `menu_walk: an error planted on purpose`,
  and the line expects that.
- `test-demo-overlays`' planted crashing step called `free()` on null,
  whose error names nothing of the plant; it now calls
  `demo_overlays_planted_crash()`, and both lines expect that name.

**Not run here.** The measurements, recordings and `measure-3d` (it opens
a window) were checked only by `make -n`; a windowed run may print a
renderer error that now fails it, which is the point, and is the owner's
to see the first time.
