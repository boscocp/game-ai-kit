# The 3D racer: a car the driver does not own, measured

<!-- doc-meta
half_life: practice
verified_on: 2026-10-21
tier: 2
source: https://github.com/boscocp/game-ai-kit
invalidated_if: the car's physics, the driver's decision, the levels or the tracks change, and racing3d_ladder.gd, racing3d_effects.gd or racing3d_does_not_cheat.gd print different numbers
teaches: none
-->

> T54's example, built and measured. Where its techniques come from is
> [the racing AI page](../concepts/racing-ai.md); this page says what they
> did here, including the claim that did not hold and the five changes the
> physics forced on the plan.

## What it is

You and three AI levels in one car, on a track whose racing line every
driver finds for itself (`make demo-racing3d`). The car is a `RigidBody3D`
on four ray-cast wheels: a spring and damper on each, tyres whose sideways
force grows with their slip angle to a peak and then slides, the engine and
the brakes inside each tyre's friction circle. Weight transfer is written
nowhere; the tyres push at the road below the centre of mass, and braking
pitches the body. The driver is an agent: it sees a `RaceView3D` -- the
road ahead in its own frame, its speed, how far it is off the line, the cars
near it -- and sets the wheels and pedals. Nothing in the decision is a
track, and `racing3d_portable_test.gd` holds that by reading its code.

Before the start every car is driven on a test pad of the same tarmac
(`GripTest3D`): braked hard from 25 m/s, then held at 13 m/s with the wheels
turned slowly to full lock. Each driver keeps what its own car did, for that
race only:

| | the car's sheet | measured |
|---|---|---|
| sideways grip | 10.29 m/s^2 (tyre grip times gravity) | 9.44 m/s^2 |
| braking | 9.58 m/s^2 (brake force over mass) | 8.37 m/s^2 |
| steering past the arc worth asking | 0.12 rad (the tyre's peak slip) | 0.067 rad |

The same car measures the same numbers bit for bit, every time
(`make test-racing3d-car`). Braking from 25 m/s the front tyres carry up to
2.08 times the rear's load.

## Playing it

Arrows or WASD drive. 1 switches the PID between full and proportional
only, 2 the traffic between the heat line and one rival at a time, 3 the
grip between measured and the car's sheet. Tab watches the next car, C
the camera, T the other track, R starts again, Space pauses. On the road:
a white post where each car steers, a white bar where it must already be
braking, a post at each tyre (green with grip to spare, yellow near it,
red sliding), and across the road ahead of the watched car the heat line
and its yellow ball. Under the panel, the trace of the watched car's
distance off where it wants to be; the map shows the race from above.

## The ladder, and the second track

`make test-racing3d-ladder`: every level alone, three laps from a standing
start, three seeds, on two tracks. The kidney is narrower, runs the other
way and has a hairpin and a chicane; nothing was tuned on it.

| level | lookahead | grip margin | wander | the loop | the kidney |
|---|---|---|---|---|---|
| easy | 0.5 s | 0.75 | 2.0 m | 50.61 s | 43.90 s |
| normal | 0.7 s | 0.86 | 1.0 m | 48.43 s | 41.85 s |
| hard | 0.9 s | 0.97 | 0.3 m | 47.20 s | 40.41 s |

Every rung is more than the stated second apart on both tracks. The racing
line comes from an elastic band, the same on every track: it bends 0.92 as
much as the centre on the loop, whose corners leave little room for its
width, and 0.73 on the kidney.

## What each switch does

`make test-racing3d-effects` (about 75 s), the hard driver alone for three
laps unless said:

| | mean distance off where it wants to be | frames on the grass | laps |
|---|---|---|---|
| full PID, measured grip | 2.03 m | 0 | 49.7, 46.1, 46.0 s |
| proportional only | 302 m | 20284 | 51.7 s, then off the road |
| on the car's sheet | 83 m | 16148 | 85.6, 88.4, 142.3 s |

- **The PID.** With the proportional term alone this car does not settle
  off the line in a long bend; it swings, wider each time, until it leaves
  the road. Melder & Tomlinson say a small gain leaves an offset and a large
  one oscillates: 0.04 rad a metre is a large one for this car at this
  speed. Held: the full PID is closer.
- **The measured grip.** On its sheet the driver brakes late for a car it
  is not driving, and slides off. Held: the measured driver spends fewer
  frames on the grass.
- **The heat line is printed, not claimed.** In a race of four (two easy, a
  normal, the hard car last on the grid; three seeds), the claim first
  written for it -- that the cars change the side they pass on less often
  with it -- **did not hold**: 74 changes of side with the heat line, 40
  reacting to one rival at a time. The cars touched less with it, 1088
  car-frames against 1370, and the hard car finished its nine laps with it
  (49.2 to 63.0 s) and not without (two laps of 202 and 277 s, off the
  road). The hard car led at the end of none of the six races, either way:
  three laps from the back is not enough. What the heat line does is held
  where it can be stated exactly, in the conformance vectors
  (`heat-goes-round-two-cars-at-once`, `one-rival-at-a-time`).

## No cheating

`make test-racing3d-does-not-cheat` records a race of the three levels,
cars colliding, two laps -- 6197 physics frames -- and on every frame holds
one `CarPhysics3D` for all, unchanged; no car past its top speed, no tyre
past its grip; the knobs each driver used are the ones entered; every car
covers its laps. It then races an honest twin from what it entered, with
plain drivers, and every car's place and velocity and every decision must
equal the twin's. They do, bit for bit: Jolt replays a run on one binary
(T50), so the tolerance is zero. Nine planted races are each refused by the
rule they break -- a stronger shared engine, a car given a stronger copy, a
launch past the top speed, a rubber band in the knob and one on the pedal,
a nudge, a level changed and reported, a margin used whole and reported as
the level's, a stall -- and loosening the twin's tolerance lets the three
only the twin can see through.

## What the physics forced, each measured

- **The lookahead is in seconds, not metres.** T23's 16-metre aim weaved
  this car off the road at 35 m/s. The knob is still one number a level,
  read once a decision.
- **The steering stops where the slip stops paying.** The driver turned
  the wheels further as the front slid, and slid more. The grip test now
  also measures how far past the arc the wheels were at the peak, and the
  driver never asks for more.
- **The engine's push is held to its power**, 100 kW: full push at speed
  left the rear tyres no grip to turn with.
- **The brakes are 80 per cent on the front**, about the share of the load
  the front carries braking hard. At 60 per cent the rear locked and spun.
- **The rear tyres are wider**, 1.15 times the grip and a peak at 0.75 of
  the slip. With the same tyres all round, every car oversteered and spun
  whenever the brakes or the engine took some of the rear's grip; with
  these the front lets go first, and the car runs wide, which a driver can
  catch.
- **The project's default damping** slowed every car by a tenth of its
  speed a second; the car replaces it with none.
- **A car alongside is three times hotter** on the heat line than one at
  the bumper: two cars that only leaned away measured seconds of rubbing
  doors. And a car is followed where it is as well as where it means to
  be: one that had only decided to pull out was still behind the other, and
  ran into it.

## Under `--fixed-fps`

Every racing check runs with `--fixed-fps 60` (the Makefile targets pass
it): the physics step is 1/60 s either way, but without it Godot paces the
frames in real time and a three-lap ladder takes minutes. Measured on
4.7.2: under `--fixed-fps` Jolt prints, once a run, "Jolt Physics job system
exceeded the maximum number of jobs ... Waiting for jobs to become
available". T50's floor test prints it too when run that way, and counts it
as an error. It is a warning, and nothing measured changes with it;
`Racing3DErrors` forgives that one message by its text and counts every
other. `Engine.time_scale` is not a way round: it scales the physics step
itself.
