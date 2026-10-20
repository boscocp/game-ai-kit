# Steering: which way to push, and how hard, right now

<!-- doc-meta
half_life: concept
verified_on: 2026-10-19
tier: 1
source: https://www.red3d.com/cwr/steer/gdc99/ ; book:Ian Millington, "AI for Games", 3rd edition, CRC Press, 2019 -- chapter 3 on movement
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
so the two can be held to one answer. `spec/vectors/steering/` pins six
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
- Ian Millington, *AI for Games*, 3rd edition, CRC Press, 2019, chapter 3.
