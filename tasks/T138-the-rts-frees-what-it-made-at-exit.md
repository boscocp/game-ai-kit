# T138 — The RTS frees what it made, at exit

Size: S · Prereqs: T20 · Files: `godot/game/rts/`, `godot/test/rts/`

## Goal

Closing `make demo-rts` on 2026-11-06 (exit 0) printed:

```
WARNING: 21 ObjectDB instances were leaked at exit
ERROR: 15 resources still in use at exit
```

The tactical, talk and menu demos closed the same morning with neither.
Something the RTS makes is held past the scene tree: an object never added
to the tree and never freed, or a reference cycle between `RefCounted`s.
It costs nothing while the game runs, and it is an `ERROR` line in every
log a person reads after it.

## Decisions written down first (the owner confirms in review)

- **Measure first.** Run the scene with `--verbose` and name each leaked
  class before changing anything; the fix follows what it names.
- A cycle is broken where it is made, with a sentence why, not by a
  blanket `free()` at exit.
- If a gate can see it -- the scene run headless for a few frames and
  quit, its output read for the two lines -- the gate comes with a planted
  leak it refuses (invariant 4). If headless does not reproduce it, that is
  written down, and the check stays manual.

## Steps

1. Reproduce, with `--verbose`, and list the classes.
2. Fix each at its source.
3. The gate, or the sentence why there is none.

## Acceptance

```bash
make test-godot-some SUITES="test/rts"
make test-rts-clock-limits
python3 scripts/check_readability.py
make lint-tasks lint-status
```

## Manual check

`make demo-rts`, play a minute, close the window: do the last lines hold
no `leaked` and no `still in use`?

## Notes

- Opened by the owner's manual checks of 2026-11-06, read from the log.
