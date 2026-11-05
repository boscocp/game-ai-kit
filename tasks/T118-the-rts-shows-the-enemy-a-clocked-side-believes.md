# T118 — The RTS shows the stale enemy a clocked side believes in

Size: S · Prereqs: T55 · Files: `godot/game/rts/`, `godot/test/rts/`, `godot/locale/`, `docs/concepts/rts-ai.md`

## Goal

The owner ratified on 2026-11-05 ("todas conforme recomendado") the
recommendation of STATUS's item A11, T55's decision 10: a follow-up task.

`RtsHumanClock` shows a side the enemy as it stood `reaction_ms` ago.
Nothing on screen shows that late view: the thinking panel draws the
inner side's squads, not the enemy it was given (PR #70, decision 10).
So a person watching with K on sees the side react late and cannot see
why. Invariant 13 asks for the decision, not only the outcome.

## Decisions written down first

_The owner ratified only the item quoted above. The decisions below are this session's proposal, written on 2026-11-05; the wave that takes the task confirms them, or brings them back to the owner._

- **Drawn with the thinking overlay**, only when the side is clocked: the
  enemy units the side was handed, at the places it believes, beside or
  under the current ones, and their age in milliseconds.
- **Read from the clock, not recomputed.** The overlay draws exactly
  what `RtsHumanClock` handed the inner side, so it cannot show a view
  the side did not get.
- **Waiting commands are shown too**, if the cap holds any: how many,
  and how long the oldest has waited.

## Steps

1. A read-only accessor on `RtsHumanClock` for the last view it handed
   on.
2. The overlay, and its line in the thinking panel, in both languages.
3. A test that the drawn enemy equals the handed view, and is absent
   without the clock.

## Acceptance

```bash
make test-godot-some SUITES="test/rts"
make test-rts-clock-limits
make test-demo-overlays
python3 scripts/check_demos.py
python3 scripts/check_translations_game.py
python3 scripts/check_readability.py
make lint-tasks lint-status
```

## Manual check

Play `make demo-rts` with K on and the thinking view open. During a
raid, is the late enemy visibly behind the real one, and does the side's
answer follow the late one?

## Notes

- Shares no folder with T88 or T96.
