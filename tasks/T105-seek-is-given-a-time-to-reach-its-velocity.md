# T105 — Seek is given a time to reach its velocity

Size: S · Prereqs: T22, T75 · Files: `godot/addons/ai_steering/`, `python/gameaikit/steering/`, `spec/vectors/steering/`, `godot/test/ai_steering/`, `python/tests/test_steering*.py`, `godot/test/demo_racing/racing_line_example.gd`, `docs/concepts/steering.md`, `docs/techniques/ai_steering*.md`, `docs/techniques/racing_driver*.md`

## Goal

Wave 90's review found that `ai_steering`'s seek closes the gap between
the velocity it wants and the one it has at an implicit gain of one a
second: `Steering.towards_velocity` returns the gap, and
`SteeringVehicle.step` adds force times seconds. The racing example on
`docs/techniques/racing_driver.md` had to multiply seek's force by
`RESPONSE = 10` to stay on its line; at 1 it left the ±30 band (1019
failures). Arrive already has the knob that says how fast, Millington's
`time_to_target`. Give seek (and pursue, which runs a seek) the same knob,
keep today's behaviour as its default, and let the example use it.

## Steps

1. Read Reynolds (1999) and Millington (chapter 3, and his `aicore`
   source) on how the steering force relates to the velocity gap and
   time; write it, with URLs, in `docs/concepts/steering.md`, with the
   choice between a per-behaviour time, a vehicle-level gain (Reynolds'
   mass), and a bare multiplier, and why.
2. `Steering.towards_velocity(vehicle, desired, time_to_target = 1.0)`;
   `SeekBehaviour.new(target, within = 1.0)`;
   `PursueBehaviour.new(at, moving, look_ahead, within = 1.0)`; arrive
   through the same function. The Python twin equal; `derive.py` and two
   new vectors that use the knob; the runners accept the field.
3. Measure before and after: steering properties, the steering vectors,
   the racing ladder and does-not-cheat, the 3D ladder and does-not-cheat,
   the demo overlays, the suites. Nothing that passes today may fail; the
   default stays where it moves nothing.
4. The racing example uses `SeekBehaviour.new(aim, TIME_TO_TARGET)`; the
   technique pages in both languages follow, `translation_of` recomputed;
   the STATUS follow-up line goes.
5. A mutation round: the knob ignored (the old implicit gain) must turn the
   new tests red.

## Acceptance

```bash
make test-steering-vectors
make test-steering-properties
make test-python-some PYTESTS="test_steering test_steering_vectors"
make test-godot-some SUITES="test/ai_steering test/demo_racing test/racing3d"
make test-racing-ladder
make test-racing-does-not-cheat
python3 scripts/check_translations_docs.py
```

## Manual check

`make demo-steering`: seek, with its default, looks exactly as it did
before this task -- the same overshoot round the target.
