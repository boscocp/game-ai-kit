# Conformance vectors: steering

<!-- doc-meta
half_life: structure
verified_on: 2026-11-06
tier: 1
source: https://github.com/boscocp/game-ai-kit
invalidated_if: a behaviour's formula changes, the vehicle stops being explicit Euler, or Vector2 becomes double precision
teaches: none
-->

> Eight trajectories and five flock cases, two languages, and the files that
> say they came out the same.

`ai_steering` (GDScript) and `gameaikit.steering` (Python) implement the same
vehicle and the same four behaviours. Each vector is one `.json` file: a
vehicle's start, the behaviours it runs and their weights, and at each
sampled step where it is, how it moves and the force it is about to be
given. Both sides replay it and check every number against the file, never
against each other: `make test-vectors` on the GDScript side, `make
test-python` on the Python side.

## Where the numbers came from

From neither implementation: `derive.py`, beside the vectors, is a third
copy of the maths in plain tuples that imports nothing from this
repository. Independent of the code, not of its author: it makes the same
design choices (which side head-on is, the first threat on a tie), so it
catches a slip in transcribing them, not a choice that is wrong.

    python3 spec/vectors/steering/derive.py spec/vectors/steering

## The tolerance

1e-3 in the vector's own units, on every coordinate. Godot's `Vector2` holds
32-bit floats and the file 64-bit answers
([`docs/godot/vector2-is-single-precision.md`](../../../docs/godot/vector2-is-single-precision.md)).
Measured on 4.7.2, the largest difference on the GDScript side was 9.4e-6
on one coordinate, in `arrive-slows-and-stops`;
Python lands far closer. A sample moved by ten times the tolerance fails
both sides' tests, and a real change is far bigger than the tolerance:
arrive given 0.11 s instead of 0.1 moves its vector by 4e-2.

A field a vector leaves out -- `time_to_target`, `max_prediction` -- is left
to the library's own default on both sides, so the vectors pin the defaults
too.

## The eight

| file | what it pins |
|---|---|
| `seek-turns-and-overshoots` | on a vehicle whose force is under twice its speed, so the clamp shapes the turn: seek reaches the target at speed near step 240 and is past it by 300 |
| `arrive-slows-and-stops` | arrive brakes inside its radius and is still on the target by step 300 |
| `pursue-a-crossing-quarry` | pursue aims ahead of a quarry crossing in front, which moves on after every step |
| `avoid-swerves-alone` | avoid pushes sideways while the obstacle is ahead, then asks for nothing and the vehicle coasts past |
| `seek-and-avoid-go-round` | the two, weighted 1 and 2, go round an obstacle a little off the line |
| `seek-sharp-turns-in-a-tenth` | seek given `time_to_target` 0.1 instead of its default second, on a vehicle with force to spare: it swings round far sooner; ignoring the time (the old implicit gain of one a second) moves every sample after the first (T105) |
| `pursue-sharp-a-crossing-quarry` | the crossing chase with `time_to_target` 0.25, handed on to the seek pursue runs: it closes on the quarry sooner (T105) |
| `seek-and-avoid-head-on` | the obstacle on the line: avoid turns left and the two go round (its first version stalled in front, for good) |

## The shape

```json
{
  "name": "seek-turns-and-overshoots",
  "why": "what this vector is for",
  "steps_per_second": 60,
  "vehicle": {"position": [0, 0], "velocity": [0, -5], "max_speed": 10, "max_force": 20},
  "behaviours": [{"kind": "seek", "target": [20, 15], "weight": 1}],
  "samples": [{"step": 0, "position": [0, 0], "velocity": [0, -5], "force": [8, 11]}]
}
```

A behaviour is `seek` (`target`, optional `time_to_target`), `arrive` (`target`, `braking_radius`,
optional `time_to_target`), `pursue` (`quarry` with `position` and
`velocity`, optional `max_prediction` and `time_to_target`; the quarry moves on by its velocity
after every step) or `avoid` (`centres`, `radii`, `look_ahead`). A field a
kind does not know is refused on both sides.

## The flock, in `flock/` (T150)

Five more files pin `Flock` and its three rules, written by
`flock/derive.py`, which imports nothing from the repository either:

    python3 spec/vectors/steering/flock/derive.py spec/vectors/steering/flock

Two shapes, told apart by `shape`. A **forces** vector is one boid
(`position`, `velocity`, `max_speed`, `max_force`), the `neighbours` it is
handed (`position`, `velocity`), the `separation_radius`, optional
`time_to_target` and `weights`, and the `expected` forces of `separation`,
`alignment`, `cohesion` and the weighted `flock`. A **steps** vector is a
small flock flying: `boids`, one `max_speed` and `max_force` for all, and at
each sampled step every boid's `positions` and `velocities`. Every boid is
handed the whole flock, itself included, which each rule must skip, and
every force is worked out from one snapshot before any boid moves. Of the
three skips, this pins alignment's: a boid counting its own heading would
fly a different line. Separation's and cohesion's skips change nothing
here: a boid at no distance from itself has no direction to push, and
counting itself moves the centre towards it but not the direction to that
centre. So `flock_test.gd`'s self-only flock pins those two.

| file | what it pins |
|---|---|
| `two-neighbours-by-hand` | the case worked on `docs/concepts/steering.md`: half-strength separation, two headings adding to a diagonal, a centre, and a sum clamped to 20 |
| `two-close-on-one-side-are-clamped` | two pushes of 0.75 adding past the limit, and two headings that cancel, so alignment asks for nothing |
| `nobody-in-sight` | no neighbour: every rule, and the flock, asks for nothing |
| `far-neighbours-only-pull` | weights 0, 2, 0 and a `time_to_target` of 0.5: only alignment counts, twice |
| `four-boids-flying` | four boids from four headings fly one way by step 240, at about half their top speed -- the default second's time constant, which the demo shortens to a frame |

`make test-steering-vectors` runs both folders on the GDScript side, the
flock's through `scripts/godot_checked.py`; `python/tests/test_steering_flock.py`
reads the flock's on the Python side.
