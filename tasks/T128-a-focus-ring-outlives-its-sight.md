# T128 — A focus ring outlives its sight

Size: S · Prereqs: T118 · Files: `godot/game/rts/`, `godot/test/rts/`, `docs/concepts/rts-ai.md`

## Goal

The owner ratified on 2026-11-05 ("1 a 12 conforme recomendado") item 6 of
STATUS's second 2026-11-05 list. It is this session's proposal, not PR
#75's.

A fighting squad's focus ring (`RtsThinking._seen_at`) marks where the
target is now, read from the current snapshot. When the focused target
leaves the computer's current sight, `_seen_at` returns INF and the ring
disappears, while the squad still holds that focus. The person then sees a
squad attacking nothing. The case is older than T118 and was found by its
review (`docs/reviews/130-the-rts-shows-the-enemy-a-clocked-side-believes.md`).

## Decisions written down first

- **Fall back to the last place the side was told of** (proposed here:
  PR #75 names only the handed position). That is the handed position
  when the side is clocked, and the last seen position otherwise. The
  ring is drawn there, marked as stale (proposed here: in the same style
  as T118's hollow rings), so it never claims a current place the side
  cannot see.
- **Drawing only.** Nothing the squad decides changes; the ring reads, it
  does not feed back (T55's leaks stay closed).

## Steps

1. A test that fails today: a squad focused on a target that walks out of
   sight still has a ring, at the fallback place, recorded as T118
   records its rings.
2. The fallback in `_seen_at` or beside it, and the stale mark.
3. One sentence on the concept page.

## Acceptance

```bash
make test-godot-some SUITES="test/rts"
make test-rts-clock-limits
make test-demo-overlays
python3 scripts/check_readability.py
make lint-tasks lint-status
```

## Manual check

In `make demo-rts` with V on, chase a squad's target out of the
computer's sight: does the ring stay, marked as stale, where the side last
knew it? Without the clock that is the last decision's sighting, so the
ring jumps back by up to half a second of the target's walk when it goes
stale; that is meant. A killed focus also leaves a short-lived stale ring
on its last place, until the squad's next decision (longer under the
clock, whose handed view still holds it): the side's honest belief, not a
fault (review of wave 137, finding 7).

## Notes

- Shares `godot/game/rts/` with no open task. Its test folder is also in
  T121's Files (`godot/test/`).
