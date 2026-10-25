# Review: wave/85-fighting-dpad

A fresh context reviewed the owner's request of 2026-10-25, after playing
`make demo-fighting` with a pad: the D-pad should walk the fighter as well
as the left stick, both at once. The change maps the D-pad to A, D, W and S
in the fighting game's `PAD_BUTTONS` -- the keys the stick already presses
-- and relies on wave 84's holders, so a key goes up only when the last of
the two lets go. The reviewer read the code; it did not run Godot.

**Verdict: merge.**

## What was reviewed

- That the fighting game reads A, D, W and S where the D-pad reaches them
  (`is_physical_key_pressed`, and `_send_key` sets the physical key), and
  that none of the four has a second use in `_unhandled_input`.
- Collisions with the menu's tables: `MENU_PAD` is swapped for
  `PLAYING_PAD`, View only, while an example plays.
- Whether the new claim exercises two holders, and the claim count in the
  doc against `ALL_HELD`.

## Findings

1. **The new claim had no planted case of its own** (minor): the one-owner
   pad fails it, but only `shared_kept` was asserted, so a later rewrite of
   the throttle claim would have left the D-pad claim unguarded.
2. **One release order is tested** (minor): the stick first. The other
   order runs the same code.

## What was done about them

1. The one-owner pad must now fail both `shared_kept` and
   `stick_and_dpad_kept`, each by name. `make test-pad`: nineteen claims,
   0 failures, no SCRIPT ERROR, both planted pads refused.
2. Left: the same `_hold` serves both orders.

Also run: `make test-demo-overlays` (14 examples, 0 failures), and the
readability, freshness and module gates.
