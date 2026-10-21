# T54 — Racing in 3D, with physics the driver does not own

Size: L · Prereqs: T50, T53, T23 · Files: `godot/game3d/racing/`, `godot/addons/ai_steering/`, `python/gameaikit/`, `godot/test/`

## Goal

The owner's 3D racing game, in milestone 4 beside T22/T23. T23's car is
crude on purpose and says so: a heading, a speed, a grip limit. This one has
the physics T23 leaves out -- four wheels on suspension, tyres that grip up
to a slip and then slide, weight that moves forward when it brakes -- and
the lesson changes with it: **the driver no longer knows exactly what its
car will do**, so it has to look ahead, measure, and correct.

The physics is not the lesson and the file says so, as T23's does. It is
written on `RigidBody3D` with ray-cast wheels, not on `VehicleBody3D`, whose
own reference says it "isn't designed to provide realistic 3D vehicle
physics" (ADR 0018) -- and because a reader should be able to see the four
forces each wheel adds.

T53's survey (`docs/concepts/racing-ai.md`) chose the techniques: T23's
driver, plus what a car it does not fully know demands. T23's rule holds:
the hard car is faster because it is driven better, never because it was
given anything, and no knob moves with the player's position.

## Steps

1. **The car.** Suspension as a spring and damper per wheel ray; tyre force
   from slip, saturating at a grip limit; one parameter resource shared by
   every car. Fixed physics rate. Kept to what a reader can follow in one
   file under 400 lines.
2. **The track.** Built from an open pack (Kenney's Racing Kit is the
   candidate) referenced in `assets.json`, with a box-and-plane fallback
   (ADR 0018). A racing line through it, drawn.
3. **The driver**, on a snapshot (ADR 0018's invariant 5 rule): T23's pure
   lookahead and speed profile, with the grip the profile uses **measured**
   rather than read off a constant -- the kit's own choice, not a source's
   (Game AI Pro reads grip from the physics). It is measured in one
   calibration lap before the race, per car, kept in memory for that race
   and never saved. That is a measurement, not training: no weight is
   fitted, and it is as reproducible as the physics T50 measured. If
   `check_no_training.py`'s net catches it, the measurement is moved to a
   Python step that writes the number down, as invariant 6 wants. The
   grip has to be measured because it now comes from the tyres. Its
   Python twin and vectors pin the decision from a
   stated snapshot.
4. **What the player toggles** (T53's three):
   - **PID control** of speed and of the distance from the line (Melder &
     Tomlinson). Toggle: proportional only, and the car settles off the
     line -- the steady-state offset, drawn as a trace of the error.
   - **The heat line for overtaking** (Melder's heat vision): an array
     across the track's width under each car, and the ball rolling to the
     coolest place. Toggle: off, and cars react to one rival at a time.
   - **The measured grip**: toggle to the constant, and the driver brakes
     for a car it is not driving.
5. **Three levels** over the knobs T23 already names (lookahead, braking
   grip margin, steering wander) and nothing else unless written down here.
   T23's name for the braking knob is "grip margin"; it means the same
   here.
6. **The overlay** (invariant 13): the line, the lookahead point, the target
   and actual speed, the braking point, each tyre's slip as a colour; and a
   2D map of the track with every car on it.

## Acceptance

```bash
make test-godot
make test-python
make test-vectors
python3 scripts/check_readability.py
python3 scripts/check_no_assets.py
python3 scripts/check_demos.py
```

```bash
./scripts/godot --headless --fixed-fps 60 --path godot -s res://test/racing3d/racing3d_ladder.gd
./scripts/godot --headless --fixed-fps 60 --path godot -s res://test/racing3d/racing3d_does_not_cheat.gd
./scripts/godot --headless --fixed-fps 60 --path godot -s res://test/racing3d/racing3d_car.gd
./scripts/godot --headless --fixed-fps 60 --path godot -s res://test/racing3d/racing3d_effects.gd
```

`racing3d_ladder.gd`: every level finishes three laps on a fixed seed set;
a harder level's mean lap is lower by a margin stated as a number; the
order is monotonic. `racing3d_does_not_cheat.gd`: every car uses one
physics resource, field for field; no car exceeds its stated top speed or
grip on any physics frame of a recorded race; and the knob values each
controller actually used are the same on every frame (T23's check, with
its planted case). If T50 measured that
physics does not replay identically, both state their tolerance as a
number in the script's header.

## Manual check

Race against each level with the overlay on. With PID's proportional
term only, watch whether the car settles off the line or weaves: the
chapter says a small gain leaves an offset and a large one oscillates.
Can you see why the hard car is faster -- a later braking point, a wider entry, less wander -- and does
the car feel like a car, sliding when pushed rather than turning on rails?

## Done in wave 73 (2026-10-21)

What was built differs from the steps above in these places, each on
purpose and each measured; `docs/godot/racing3d.md` has the numbers.

- **The scripts live in `test/racing3d/`** (a new file must have a module,
  CLAUDE.md), and run with `--fixed-fps 60`: the physics step is the same,
  but without it Godot paces the frames in real time. Under it Jolt warns
  once a run that its job system ran out of jobs; T50's floor test prints
  the same warning that way, and `Racing3DErrors` forgives that one text.
- **The track is the kit's own geometry, the pack its scenery.** Kenney's
  Racing Kit (referenced in `assets.json`, fetched by `make assets-3d`) is
  modular tiles on a grid; a track built from tiles would have to be a grid
  too, and the portability check needs a second track of any shape. So the
  road is a triangle strip from the track's centre and width, and the pack
  gives the four cars, trees and a grandstand; with nothing downloaded each
  is a primitive.
- **The racing line is found, not written down** -- an elastic band that
  makes the sum of squared bends least, the same on every track -- so the
  driver can be put on the kidney untuned.
- **The lookahead knob is in seconds of travel**, not T23's metres: a
  16-metre aim weaved this car off the road at 35 m/s.
- **"One calibration lap" became a test pad of the same tarmac**: braking
  from 25 m/s, and a slow steering ramp at 13 m/s. It also measures how far
  past the arc the wheels are worth turning, without which the driver
  turned further as the front slid. Not training: nothing is fitted, and
  `check_no_training.py`'s net did not catch it.
- **The car needed wider rear tyres, a front brake bias, an engine held to
  its power, and no default damping** before any driver could keep it on
  the road; with the same tyres all round every car spun.
- **The heat line's claim did not hold** and is printed, not gated: the
  cars changed passing side more often with it (74 against 40), though they
  touched less (1088 car-frames against 1370). The owner's rule from T51
  applies: say what was measured.
- **P only swings rather than settling off the line.** The manual check's
  two outcomes are the chapter's; this car at this gain shows the second.
- **Two gates beyond the task's**: `racing3d_car.gd` (the car's three
  physics claims and its reproducible measurement) and
  `racing3d_effects.gd` (what each switch does), plus
  `racing3d_portable_test.gd`, which reads the decision's code: only an
  allow-list of classes, no other door to the world, no level title, no
  track name. A reading cannot see a number tuned to one track; the
  untuned kidney in the ladder is the real defence (review of wave 73).

Measured: laps easy 50.61, normal 48.43, hard 47.20 s on the loop; 43.90,
41.85 and 40.41 on the kidney; the ladder's gap 1.0 s. The does-not-cheat
race is 6197 frames and matches its honest twin bit for bit; nine planted
cheats are each refused by their rule. Fourteen vectors at 1e-9. The
manual check is still the owner's.
