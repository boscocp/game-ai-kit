# Review: wave/75-the-racer-starts-on-you

A fresh context reviewed the wave at `9383dcf`: the 3D racer's camera
starts on your car, the panel says the keys wait for the grid, and
`make test-racing3d-you-drive` holds both through the scene a person
opens. It was not allowed to edit the worktree. It ran the new gate on the
branch and on a scratch copy of the old scene (two findings: the camera,
the silent panel), and on a mutant whose throttle read only W (Up held
moved the car 0.18 m, one finding) -- so `Input.parse_input_event`
reaches `Input.is_key_pressed` headless, and the idle window rules out a
car that moves by itself. It ran `check_readability`, `check_modules`,
`check_demos`, `check_acceptance` and `check_tiers`, all green.

**Verdict: merge**, with two cheap fixes first.

## What was reviewed

- `CLAUDE.md`, T54's task, `docs/godot/racing3d.md`, and
  `git diff origin/main...HEAD`.
- Whether `watched = race.drivers.find(human)` holds on R and T: the
  human is entered last, so it is car 3 every time.
- Whether anything else read `watched`: `demo_overlays.gd` skips the
  human and never reads it; no other test does.
- Whether the gate could go green with the bug present: the panel read,
  the key injection, the idle window, and each planted case.

## Findings

Each one is followed by what was done about it.

1. **A number that was not the gate's** (low): the gate's comment and its
   honest planted case said 9.6 m; the gate prints 9.32 and the doc says
   9.3. *Fixed*: 9.3 in both.
2. **Two promises not held** (low): the camera back on your car after a
   restart (R or T) once another car was watched, and the panel's racing
   hint, "Tab until \"you\"". *Fixed*: both are claims, each with a
   planted case it refuses. Writing the second showed the panel is read a
   frame early -- `process_frame` is emitted before the scene's
   `_process` -- so the gate waits two frames; it went red, not green, on
   the early read.
3. **The test reads `scene._status` and an untyped scene** (nit). *Left*:
   the scene has no `class_name`, and a test reading its label is the
   honest way to see what a person sees.
4. **R and T now always bring the camera back to your car** (nit, for the
   owner): before, the watched car was kept. *Left*: it is the point of the
   fix; the owner can say otherwise after playing.
5. **T54's "21 m in three seconds"** is the probe before the fix, not the
   gate's number (nit). *Left*: it is history, and the doc cites the
   gate's 9.3 m.

## What was done about them

Findings 1 and 2 were fixed on the branch in `16254f9`, and the gate run
again: 0 failure(s), your car 0.10 m idle and 9.32 m with Up held, the
racing panel naming Tab, the camera back on car 3 after a restart. 3 to 5
were left, each for the reason given beside it above.
