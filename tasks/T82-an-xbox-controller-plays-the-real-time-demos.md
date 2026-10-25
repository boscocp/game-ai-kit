# T82 — An Xbox controller plays the real-time demos

Size: M · Prereqs: none · Files: `godot/game/pad_as_keys.gd`, `godot/test/game_shared/`, `godot/menu/menu.gd`, the six real-time demos, `docs/godot/a-controller.md`

## Goal

The owner asked on 2026-10-25 for the kit to work with an Xbox controller,
and chose the scope: the menu, and every example where a person drives
something in real time -- the 2D and 3D racers, infiltration, the bot match
(a bot taken over), the fighting game and the stealth hall. The board and
click examples (checkers, tactics, the RTS, search, tic-tac-toe) stay on the
mouse.

Every one of those reads the keyboard its own way: a key's event, a key held
(`Input.is_key_pressed`), a physical key held (the fighting game), the mouse
moving. None uses the InputMap, and measured on 4.7.2, Godot's own `ui_*`
actions name no pad button at all, not even the D-pad. A second way in for
each example would double every input path a reader follows; so the pad is
translated into the keys instead, by one node, from a table each example
declares.

## Steps

1. **`PadAsKeys`** in `godot/game/`: a button presses a key, the left stick
   four direction keys, the triggers two keys (a racer's brake and
   throttle) or the right trigger the left mouse button, and the right stick
   moves the mouse -- through `Input.parse_input_event`, so the example's own
   reading sees it held. A press threshold and a lower release threshold,
   so a stick resting near the line does not chatter. A table swapped
   mid-press lets go of what it held.
2. **The claims first**, in `test/game_shared/pad_as_keys_claims.gd`:
   pressed and released, physical and not, the stick's hysteresis and its
   sign, the click, the look, the swap, the triggers, Shift carried on the
   key after it. Planted: each claim broken alone found by name, and a pad
   pressing only the keycode refused.
3. **The tables**: the menu (D-pad or stick, A, LB/RB; View back from any
   example) and the six demos, each a `PAD_BUTTONS` constant with its
   reading in a comment. The table goes in the legend only when a pad is
   connected.
4. **Document** the tables in `docs/godot/a-controller.md`.

## Acceptance

```bash
make test-pad
make test-demo-overlays
make test-menu-walk
make test-racing3d-you-drive
python3 scripts/check_readability.py
python3 scripts/check_modules.py
python3 scripts/check_doc_freshness.py
```

## Manual check

With an Xbox controller connected, `make menu`: the D-pad chooses, A plays,
View comes back. Then each: `make demo-racing` and `make demo-racing3d` (RT
drives, LT brakes, the stick steers), `make demo-infiltration` (the right
stick looks once RT has taken the camera), `make demo-botmatch` (A takes a
bot), `make demo-fighting` (X, Y, A, B attack), `make demo-stealth` (the
D-pad walks). Does the legend show the pad's table?
