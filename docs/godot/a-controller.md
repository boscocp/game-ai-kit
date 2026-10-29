# A controller that presses the keys

<!-- doc-meta
half_life: practice
verified_on: 2026-10-25
tier: 1
source: https://docs.godotengine.org/en/stable/tutorials/inputs/controllers_gamepads_joysticks.html ; https://docs.godotengine.org/en/stable/classes/class_input.html#class-input-method-parse-input-event
invalidated_if: Godot's default ui_* actions gain pad buttons, Input.parse_input_event stops updating is_key_pressed, or an example's keys change
teaches: none
-->

> T82, wave 84. How an Xbox controller plays the menu and the real-time
> examples, without any example learning that a controller exists.

## The choice

Every example here reads the keyboard its own way: a key's event, a key held
with `Input.is_key_pressed`, a *physical* key held (the fighting game, so its
moves sit in the same place on any layout), the mouse moving. None goes
through the InputMap. And measured on 4.7.2, Godot's default `ui_*` actions
name no pad button at all -- `ui_accept` is Enter, keypad Enter and Space;
`ui_up` is Up -- so nothing moved with a pad before this.

Two ways to add a pad: give every example a second reading, or translate the
pad into the keys it already reads. The second keeps one input path a reader
has to follow, and the table that does it is a few lines anyone can change.
`PadAsKeys` (`godot/game/pad_as_keys.gd`) is that translation:

- a button presses a key, and lets it go with the button;
- the left stick presses four direction keys, past 0.5, and lets go under
  0.35 -- the gap keeps a stick resting near the line from chattering;
- the triggers press two keys (a racer's brake and throttle), or, in an
  example that looks around with the mouse, the right trigger is the left
  mouse button;
- the right stick moves the mouse, 900 pixels a second fully pushed.

A key two inputs reach -- the racers' throttle is the stick's up and RT --
goes down with the first and up only with the last. Wave 84's first version
gave a key one owner, and its review found the cost: steering wobbles the
stick's y near zero, and that lifted the throttle RT was still holding.

The keys go in through `Input.parse_input_event`, with both the key and the
physical key set and Shift carried, so `is_key_pressed`,
`is_physical_key_pressed` and an event's `shift_pressed` all see them.
**When not to do it this way**: in a game made for a pad, read analogue
values through the InputMap. Here a stick pushed halfway is a key held, and
the racers steer as they do from a keyboard.

## The tables

| example | stick | buttons |
|---|---|---|
| menu | chooses | D-pad chooses, A plays, LB/RB scroll the card; View comes back from any example |
| `make demo-racing` | steers | RT drives, LT brakes, D-pad left/up/right the AI 1-3, Y watches, X again, B one step paused, Menu pauses |
| `make demo-racing3d` | steers | RT drives, LT brakes, D-pad left/up/right the full PID, heat line and measured grip on and off (1-3), Y watches, B camera, LB track, X again, Menu pauses |
| `make demo-infiltration` | walks | right stick looks, RT shoots (the first pull takes the camera, as a click does), A takedown, B crouch, X prone, RB throws, LB held sprints, Y next guard |
| `make demo-botmatch` | walks | A takes a bot over; playing, right stick looks, RT fires, B held crouches, LB held sprints, X reloads; Y next bot, RB camera, D-pad orbits the camera (and, playing, walks the bot, as the arrows do), Menu pauses |
| `make demo-fighting` | walks, jumps, crouches | the D-pad too, with the stick or alone; X/Y light/heavy punch, A/B light/heavy kick, RB throw, LB or back twice evade, Menu pauses |
| `make demo-stealth` | -- | D-pad walks a cell, with LB held two; A waits, Y danger map, X again |

Each example's table is its `PAD_BUTTONS` constant. With a pad connected,
the legend shows it under the AI's colours, as many bindings a line as fit
the legend's width (T103: three a line ran off the window in the racers and
the stealth hall, in English), and in the language chosen. The words are
translated -- "pad", "stick", the D-pad's directions -- and the key names
and the names printed on the pad (A, LB, View, Menu) stay as written.

## Held by

`make test-pad` drives a `PadAsKeys` with pad events made the way a real
pad's arrive, and reads `Input` after each, then reads the legend's line in
English and in pt-BR (T103): twenty-four claims, each one broken
alone and found; a planted pad that sets only the keycode -- which the
fighting game would never see -- refused; and one where a key has a single
owner, refused on the throttle the racers share between the stick and RT.
Headless, the events do reach the nodes: the test counts the mouse moving
in an `_unhandled_input`.

What no command holds is whether it is *pleasant*: that is the manual check
in T82.
