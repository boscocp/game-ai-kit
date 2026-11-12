# T124 — The XCOM mode plays with V off, and teaches with it on

Size: S · Prereqs: T85 · Files: `godot/game/tactical/`, `godot/test/tactical/`, `godot/game/squad/`, `godot/test/squad/`, `godot/test/menu/`, `godot/menu/catalogue.json`, `scripts/check_demos.py`, `docs/godot/squad.md`, `Makefile`

## Goal

The owner ratified on 2026-11-05 ("todas conforme recomendado") the
recommendation of STATUS's 2026-11-04 item B17: V off in play, on in the
teaching view.

V, the computer's view, is on by default (`_showing_decision` in
`tactical.gd`). On every computer turn the board then shows what the
computer sees, which is all of its own pieces. So a person playing with
the default sees the whole enemy squad once a round, and the fog is a
formality (T85's review, `docs/reviews/119-xcom-style-mode-you-can-play.md`,
O2).

## Decisions written down first

_The owner ratified only the item quoted above. The decisions below are this session's proposal, written on 2026-11-05; the wave that takes the task confirms them, or brings them back to the owner._

**The owner's decision, 2026-11-11 (wave 191):** "the teaching view" is
**a launch option**, `make demo-tactical MODE=squad VIEW=teach` -- with
it the XCOM mode opens with V on; otherwise V starts off. V still
toggles in play. Only the XCOM mode changes; Advance Wars keeps V on.
Invariant 13 still holds: `make test-demo-overlays` and `check_demos.py`
find the squad overlay populated in the teaching view, and the menu
card's `watch` line says how to get there. The proposals below stand as
confirmed, the first reading of the three chosen.

- **Only the XCOM mode changes.** The Advance Wars mode has no fog to
  lift, and keeps V on.
- **What "the teaching view" is, is the task's first decision.** Nothing
  in the kit is called that today. Three readings, to be put to the owner
  if the wave cannot choose from the code:
  - a launch option, such as `make demo-tactical MODE=squad VIEW=teach`;
  - V on whenever no person plays a side (both sides the computer's);
  - V on until the person's first move, then off.

  Only the first is a view a person opens. The second and third are
  triggers that switch V by themselves.
- **Invariant 13 still holds.** `make test-demo-overlays` and
  `check_demos.py` hold the squad scene's overlay populated. They must
  still find it, in the teaching view, and the card's `watch` line says
  how to get there.
- **V still toggles** in play, as now; the person may lift the fog on
  purpose.

## Steps

1. Choose the teaching view, as above.
2. The default per mode and per view, and the card's line.
3. Scene tests: in play the computer's turn shows the person's fog; in
   the teaching view it shows the computer's view.

## Acceptance

```bash
make test-godot-some SUITES="test/squad test/tactical"
make test-demo-overlays
python3 scripts/check_demos.py
python3 scripts/check_translations_game.py
python3 scripts/check_readability.py
make lint-tasks lint-status
```

## Manual check

Play the XCOM mode on both sides with the defaults: is the enemy hidden
on the computer's turn? Then open the teaching view: is the computer's
reasoning on the board without pressing anything?

## Notes

- Shares `godot/game/squad/` and `godot/test/squad/` with T88 and T96;
  it does not run beside either.
- T126 moves the XCOM mode's presentation hooks out of `tactical.gd`, and
  this task changes one of them. Run them one after the other; if T126
  lands first, the default lives in the mode view.
