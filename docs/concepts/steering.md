# Steering: which way to push, and how hard, right now

<!-- doc-meta
half_life: concept
verified_on: 2026-10-26
tier: 1
source: https://www.red3d.com/cwr/steer/gdc99/ ; book:Ian Millington, "AI for Games", 3rd edition, CRC Press, 2019 -- chapter 3 on movement ; https://github.com/idmillington/aicore
invalidated_if: ai_steering's behaviours change their formula, or test/ai_steering/steering_properties.gd's thresholds change
teaches: steering
-->

> How the four vehicles in `make demo-steering` decide. The code is
> [`godot/addons/ai_steering/`](../../godot/addons/ai_steering/), the same
> maths in Python is [`gameaikit.steering`](../../python/gameaikit/steering/),
> and the numbers below were measured on both.

## A different question

Everything else in this kit decides on a grid, in turns: which cell, which
move, which plan. A car has a heading, a speed and a steering angle, and the
question is not *where* but *how hard to turn, right now*. Reynolds (1999)
splits a moving character into three layers -- choosing what to do,
steering, and the locomotion that carries it out -- and steering behaviours
are the middle one: each is a function from "where I am, and where that is"
to a force.

The vehicle is crude on purpose (`SteeringVehicle`): a point with a
velocity, a top speed and a largest force. A force changes the velocity, the
velocity changes the position, sixty times a second.

## Seek, and why it never stops

Seek wants full speed straight at the target. Its force is the difference
between that velocity and the one the vehicle has -- Reynolds'
*steering = desired velocity - velocity* -- shortened to what the vehicle
can apply. Nothing in it ever asks for less than full speed, so a vehicle
seeking a point drives through it, turns, comes back through it, and keeps
doing that. Over 300 random starts, in both languages, seek's longest
stretch spent under a thousandth of its top speed was **one step**.

## How fast the gap closes: the time it is given

Seek's force is a gap between two velocities, and a force is a change of
velocity per second -- so something has to say how many seconds the gap
gets. The two books say it differently.

**Reynolds (1999), section "A Simple Vehicle Model".** The vehicle has a
`mass`, and each step

    steering_force = truncate (steering_direction, max_force)
    acceleration   = steering_force / mass
    velocity       = truncate (velocity + acceleration, max_speed)
    position       = position + velocity

with seek's `steering = desired_velocity - velocity`. There is no `dt`:
the update is per step, and the mass is the knob. With a mass of 1 the
whole gap closes in one step (up to `max_force`); a mass of 10 closes a
tenth of it a step.

**Millington (*AI for Games*, chapter 3).** Forces are accelerations
integrated over seconds -- his `aicore` source, the code that shipped with
the first edition, does `velocity += steer.linear * duration`
(`src/location.cpp`). The behaviours that match a velocity, velocity
matching and the dynamic arrive, divide the gap by a `timeToTarget`, 0.1
s; `aicore`'s kinematic arrive carries the same idea in its comment, "We'd
like to arrive in timeToTarget seconds" (`src/kinematic.cpp`). His seek
is different again: `aicore`'s `Seek::getSteering` asks for full
acceleration towards the target, no velocity gap at all
(`src/steering.cpp`). Read in this wave: Reynolds' paper and `aicore`'s
source; the third edition's chapter was not opened again -- the 0.1 is
the form T22 took for arrive from it.

This kit had Reynolds' formula on Millington's integrator: the gap,
added times seconds, without Reynolds' per-step mass. So seek closed the
gap at an implicit gain of one a second -- a one-second time constant
nobody chose. At sixty steps a second that is sixty times softer than
Reynolds' own mass-1 vehicle, and it showed: the racing example
(`docs/techniques/racing_driver.md`) ran wide of every corner with plain
seek, and wave 90 multiplied its force by ten to keep it on the line.

**What the kit chose:** Millington's time, on seek and pursue as it
already was on arrive -- `SeekBehaviour.new(target, time_to_target)`,
`PursueBehaviour.new(at, moving, look_ahead, time_to_target)`, all three
through `Steering.towards_velocity(vehicle, desired, time_to_target)`,
which returns `(desired - velocity) / time_to_target`, clamped. Why this
one:

- a reader of Millington recognises it, and it is the knob arrive already
  has here -- one name for one idea, not two;
- it is in seconds, so it means the same at any frame rate; Reynolds' mass
  is per step, and would mean something else at 30 and at 120 frames a
  second on this integrator;
- it belongs to the behaviour that asks, not to the vehicle. A
  vehicle-level gain (Reynolds' mass, in effect) would also scale avoid,
  which asks for `max_force` sideways and no gap, and arrive, which
  already divides by its own time; and `RacingDriver`, which adds seek's
  force to a velocity itself, never calls `step` and would not see it;
- a bare multiplier (`force * RESPONSE`) is the same number upside down,
  1 / time, and names nothing a book does.

**The default is one second**, what seek always was here, so no one who
calls `SeekBehaviour.new(target)` sees a change. Measured before and after
on 2026-10-26, on every gate that runs steering, the same to the last
printed digit:

| gate | before and after |
|---|---|
| the six existing steering vectors | unchanged, byte for byte, when `derive.py` writes them again; 0 failures in both languages |
| steering properties | 100 starts, arrive settled in 100, 0 failures |
| racing ladder (2D) | 32.52 / 31.30 / 29.89 s a lap |
| racing does-not-cheat (2D) | 3 cars, 3931 frames, 0 failures |
| racing3d ladder | 50.61 / 48.43 / 47.20 s on the loop, 43.90 / 41.86 / 40.41 on the kidney |
| racing3d does-not-cheat | 6198 frames, 0 failures (it steers with `PidController` and `HeatLine`, not seek) |
| demo overlays | 14 examples in each language, 0 failures |
| suites `ai_steering`, `demo_racing`, `racing3d` | 65 cases before, 67 after (the two new), 0 failures |

A sharper default would be closer to both books, and it would move
measured results. With seek's default at a tenth, measured: the 2D racing
ladder goes to 32.46 / 31.17 / 29.67 s (the AI driver adds seek's force
to its velocity, so a sharper seek is a sharper driver), its race runs
3987 frames instead of 3931, and 36 of the 44 vector samples fail --
the vectors pin the default on purpose. So the default stays at a second,
and a caller who wants sharper asks for it.

On the racing example's circle (radius 200, the car started 60 off the
line), its test holds the car within 30 of the line from the third second
on, every frame for twenty seconds:

| `time_to_target` | failed assertions |
|---|---|
| 1 (the default; the old implicit gain) | 1019 -- the number wave 90 measured with `RESPONSE = 1` |
| 0.75 | 963 |
| 0.5 | 0 |
| 0.33 | 0 |
| 0.2 | 0 |
| 0.1 (the example's, as `RESPONSE = 10` was) | 0 |

`seek-sharp-turns-in-a-tenth` and `pursue-sharp-a-crossing-quarry` pin
the knob in both languages; ignoring it -- the old gain -- turns both red.

## Arrive: the few lines that look competent

Arrive is seek with a braking radius. Outside it, it wants what seek wants,
full speed at the target; inside it, the speed it wants falls with the
distance left -- half way in, half speed -- so it asks to be stopped exactly
as it reaches the target. Millington's form also asks the velocity to change
within a tenth of a second rather than at once, which damps the approach:
without it, the slow-down rocks the vehicle past the target before it
settles. It also means arrive asks ten times as hard as seek for the same
change, outside the radius too -- so the two are not the same there, only
headed the same way. Over the same starts, every arrive came to rest inside
its radius and stayed there: its last speed was around 1e-11 in Python, and
at most 1.2e-4 in GDScript's 32-bit floats -- both far under the thousandth
of top speed (0.01) that counts as rest.

`test/ai_steering/steering_properties.gd` holds both as measurements, over a hundred
seeded starts, and is first shown seek passed off as arrive, and arrive as
seek, so a check that only goes green cannot pass.

## Pursue: aim where it will be

Seeking a moving target trails it. Pursue guesses ahead: the quarry's
position plus its velocity times how long the chase would take -- distance
over top speed -- and never more than a second ahead, because a guess about
the far future is about a quarry that will have turned. Then it seeks the
guess. In the demo, the ring is the guess, and the vehicle cuts across the
quarry's circle towards it.

## Avoid, and why it only pushes sideways

Avoid looks along its velocity, a stretch shorter as it slows, and pushes
at full strength, sideways, away from the side of the line the first round
obstacle on that stretch is on; dead ahead, with no side to choose, it turns
left. Alone it only swerves; it does not know where the vehicle wants to
go. Added to seek -- `Steering.combined`, each force times a weight, summed,
clamped once -- the two go round.

Only sideways, and that is a lesson this kit learned by getting it wrong.
The first version pushed away from the obstacle's centre from the end of
the stretch, which near an obstacle on the line points straight back. Avoid
then braked, seek pulled straight on, and the vehicle stalled in front of
the obstacle for good. It looked like the weighted sum's fault, and the
first draft of this page said so; the review measured otherwise -- the
same weights with a sideways push go round. A weighted sum can still tie
(two avoids pushing opposite ways, say), and a priority order -- the first
behaviour with something to say wins -- is the cure for that; but this tie
was the behaviour's. `seek-and-avoid-head-on` pins the fix.

## Two languages, one answer

The Python half exists so the lesson needs nothing but Python (tier 1), and
so the two can be held to one answer. `spec/vectors/steering/` pins eight
trajectories, written by a third copy of the maths that imports nothing
from either. Godot's `Vector2` holds 32-bit floats and Python's 64
([why it matters](../godot/vector2-is-single-precision.md)), so the vectors
allow 1e-3; the largest difference measured was 9.4e-6. That is still tight
enough to see a real change: asking arrive for 0.11 s instead of 0.1 moves
its vector by 4e-2.

## When not to use them

- **Walls, corridors, crowds.** Avoidance against circles is a poor wall,
  and two obstacles pushing opposite ways trap the vehicle between them. A
  flow field (`ai_rts_core`) or a navigation mesh routes; steering then
  follows the route.
- **A car that has to feel like a car.** These vehicles turn on the spot at
  any speed. T23 drives a track with them and says out loud that it is not
  a driving simulator.
- **Deciding where to go.** Which target to seek is a choice made above
  steering -- by a plan, a state machine, a player's click.

## References

- Craig W. Reynolds, "Steering Behaviors For Autonomous Characters", Game
  Developers Conference, 1999. <https://www.red3d.com/cwr/steer/gdc99/>
  Read in wave 98 from a copy of the paper's PDF
  (<https://ics-websites.science.uu.nl/docs/vakken/mcrws/papers_new/Reynolds%20-%201999%20-%20Steering%20behaviors%20for%20autonomous%20characters.pdf>),
  section "A Simple Vehicle Model"; red3d.com refused the connection that day.
- Ian Millington, *AI for Games*, 3rd edition, CRC Press, 2019, chapter 3.
- Ian Millington, `aicore`, the code of the first edition (2003-2009;
  its README calls it "a historical curiosity" next to the third edition's
  listings): <https://github.com/idmillington/aicore> -- `src/steering.cpp`,
  `src/kinematic.cpp`, `src/location.cpp`, read at commit 52fc032.
