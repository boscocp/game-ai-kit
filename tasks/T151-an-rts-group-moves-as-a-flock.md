# T151 — An RTS group moves as a flock

Size: M · Prereqs: T150 · Files: `godot/game/rts/`, `godot/test/rts/`, `docs/techniques/`

## Goal

In the RTS, a group sent to one point follows one flow field. Each unit
walks alone, and the column converges on each cell's middle. The core
turns separation off on a move order for that reason: in T19 it jammed
the two armies in the wall's gaps (`ai_rts_core/rts_world.gd`, `_keep_apart`).

With the three rules from T150, a selected group can move as a loose
flock that holds together and spaces itself, and does not file into a
line.

## Decisions written down first

_The owner asked for this task on 2026-11-06. The decisions below are this session's proposal; the wave that takes the task confirms them, or brings them back to the owner._

- **In the game, not in `ai_rts_core`.** The core may not depend on
  `ai_steering` (invariant 2). `godot/game/rts/` uses both: the flow field
  gives each unit its heading, and the flock's three rules adjust it
  among the units of the same order.
- **Only for a group's move order.** A unit alone, or a group gathering
  or fighting, keeps today's behaviour.
- **The wall-gap jam is the planted case.** T19's scenario has two armies
  through a gap. With the flock, it must not jam where it did. A replay
  that lands in the gap and stays there for the budget's twenty seconds
  fails the test.
- **A key switches it** (on/off), so the column and the flock can be
  compared. Shown, as invariant 13 requires: the watched unit's three
  forces, as in T150's demo.
- `test-rts-budget` still holds: the flock's cost is counted in the frame
  budget. The neighbour query reuses the core's spatial hash through the
  world's snapshot. A query from scratch is not allowed.

## Acceptance

```bash
make test-godot-some SUITES="test/rts"
make test-rts-budget
make test-rts-simulation
python3 scripts/check_addon_deps.py
make test-demo-overlays
```

## Manual check

In `make demo-rts`, select twelve units, order them across the map, then
press the flock key and order them back. Does the flock hold together and
go through a gap without jamming? Does it look more like a group than the
column does?
