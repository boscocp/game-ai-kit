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

T53's survey decides the techniques; this task is rewritten from it. Until
then, the plan below is T23's controller grown up, and T23's rule holds:
the hard car is faster because it is driven better, never because it was
given anything.

## Steps

1. **The car.** Suspension as a spring and damper per wheel ray; tyre force
   from slip, saturating at a grip limit; one parameter resource shared by
   every car. Fixed physics rate. Kept to what a reader can follow in one
   file under 400 lines.
2. **The track.** Built from an open pack (Kenney's Racing Kit is the
   candidate) referenced in `assets.json`, with a box-and-plane fallback
   (ADR 0018). A racing line through it, drawn.
3. **The driver**, on a snapshot (ADR 0018's invariant 5 rule): look ahead
   along the line, steer with `ai_steering`, choose a target speed from the
   curvature ahead and the grip the car has, and correct with feedback when
   the car does not do what was asked. Its Python twin and vectors pin the
   decision from a stated snapshot.
4. **What the player toggles**: 1-3 techniques chosen from T53, each
   visible -- for example the lookahead point, the braking point computed
   from the grip, and the slip each tyre is at.
5. **Three levels** over the knobs T23 already names (lookahead, braking
   margin, steering wander) and nothing else unless written down here.
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
./scripts/godot --headless --path godot -s res://test/racing3d_ladder.gd
./scripts/godot --headless --path godot -s res://test/racing3d_does_not_cheat.gd
```

`racing3d_ladder.gd`: every level finishes three laps on a fixed seed set;
a harder level's mean lap is lower by a margin stated as a number; the
order is monotonic. `racing3d_does_not_cheat.gd`: every car uses one
physics resource, field for field, and no car exceeds its stated top speed
or grip on any physics frame of a recorded race. If T50 measured that
physics does not replay identically, both state their tolerance as a
number in the script's header.

## Manual check

Race against each level with the overlay on. Can you see why the hard car
is faster -- a later braking point, a wider entry, less wander -- and does
the car feel like a car, sliding when pushed rather than turning on rails?
