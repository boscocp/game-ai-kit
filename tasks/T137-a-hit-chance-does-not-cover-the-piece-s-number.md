# T137 — A hit chance does not cover the piece's number

Size: S · Prereqs: T85 · Files: `godot/game/squad/`, `godot/game/tactical/`, `godot/test/squad/`, `godot/test/tactical/`

## Goal

Found by the owner on 2026-11-06 in `make demo-tactical MODE=squad`: with
the cursor over an enemy, the hit chance drawn on that cell sits on the
piece's own number, in the same bottom-right corner, and the two read as
one ("60" over a soldier, "5" and "55" on a truck). The legend promises "a
% on an enemy: your chance", and a person cannot read it.

## Decisions written down first (the owner confirms in review)

- **Each number has its own corner.** The piece's number stays where it
  is in both modes (Advance Wars draws it there too); the chance moves to
  a corner nothing else on a piece uses, and carries its `%`.
- Drawing only: no rule, no search and no vector changes.

## Steps

1. Find where each number is drawn (`SquadView` and the tactical board's
   drawing) and name each corner once, as a constant.
2. A test that the chance's corner and the number's differ, recorded as
   the overlays are.
3. The legend line, if its words change.

## Acceptance

```bash
make test-godot-some SUITES="test/squad test/tactical"
make test-demo-overlays
python3 scripts/check_readability.py
make lint-tasks lint-status
```

## Manual check

`make demo-tactical MODE=squad`, hover each kind of enemy piece, wounded
and whole: are the chance and the number both readable? And in Advance
Wars mode (M), does nothing move? Then watch an enemy turn with T on and
the cursor on one of its pieces: does a weighed option's score (top centre)
meet the chance (top right) on that piece's own cell?

## Notes

- Opened by the owner's manual checks of 2026-11-06 (screenshot of round 2).
- Wave 160's review: during the computer's turn with T on, a weighed
  option's score label, drawn high in the cell, can meet the top-right
  chance on the computer piece's own cell. Not a regression -- at the bottom it
  could meet the option's own chance, drawn low -- and left for the manual
  check above rather than moved again unseen.
