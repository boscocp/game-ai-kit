# Review: wave/84-xbox-controller

A fresh context reviewed T82 before it was committed: `PadAsKeys`, which
turns an Xbox controller into the keys each example already reads, its
tables in the menu and six real-time demos, the claims test and
`docs/godot/a-controller.md`. The reviewer was not allowed to edit the
worktree nor run Godot (another checkout was running Godot gates, and runs
share one user://). It ran the readability, module, freshness and demo
gates: all green.

**Verdict: fix before merge.**

## What was reviewed

- Each demo's own input code against its table: whether every mapped key
  is read the way the pad presses it -- an event's keycode, a key held, a
  physical key held, Shift on the event, the mouse button, the mouse moving
  only while captured -- and does what the comment and the doc say.
- Conflicts: one key from two pad inputs, a mapped key with a second use,
  the menu's table and an example's both live, keys left held when an
  example is freed or the menu swaps tables.
- `PadAsKeys` itself: hysteresis, `match ... when` falling through, pause,
  `_exit_tree`, the look's frame-rate dependence, the legend.
- Whether the claims test can pass on nothing, and whether its planted
  cases are refused for the right reason.

## Findings

1. **The racers lost their throttle while steering** (high). The stick's up
   and RT both press Up; a key had one owner, so the stick's y wobbling
   near zero as you steer let go of the Up RT still held. The same for the
   brake, and in the menu for the D-pad and the stick.
2. **The 3D racer's D-pad was described as choosing the level** (medium);
   1-3 toggle the full PID, the heat line and the measured grip.
3. **The fourteen-claim version had not been run** (medium), and only it
   measured a false `when` guard falling through.
4. **Shift was lost when LB and a direction came in one frame** (low): the
   pad's own Shift was still queued when the arrow read `Input`.
5. **The bot match's D-pad also walks a played bot** (low, docs), as the
   arrows do.

Sound, by the reviewer's reading: every other mapping reads as its demo
reads; no mapped key has a second use; no example maps View; the hysteresis,
pause, release on leaving and the look's `delta` are right; the test cannot
pass on nothing, and each planted case is refused for its own reason.

## What was done about them

1. A key now has holders, "stick up", "RT", "button 0"; it goes down with
   the first and up with the last. A claim: RT held, the stick up and back
   near zero, Up still held, then released with RT. Planted: the
   one-owner pad, which must fail exactly that claim -- it does.
2. Corrected in the comment and the doc's table.
3. Run: `make test-pad`, seventeen claims, 0 failures, no SCRIPT ERROR;
   both planted pads refused. `trigger_held` holds, so the guard falls
   through as the docs say.
4. The pad's own Shift and Ctrl count at once. A claim sends LB and Up in
   one frame; with the old line restored it fails ("shift_same_frame did
   not hold"), with the fix it holds.
5. Said in the comment and the doc's table.

Re-run after the fixes: `make test-pad`, `make test-menu-walk` (14
examples), `make test-demo-overlays` (14 examples; its three `free` SCRIPT
ERRORs are there on main too, measured), `make test-racing3d-you-drive`,
and the readability, module, freshness, demo, status, task, link and
workflow gates -- all green. Not yet done, and only a person can: playing
it with a pad (T82's manual check).
