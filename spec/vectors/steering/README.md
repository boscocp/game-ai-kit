# Conformance vectors: steering

<!-- doc-meta
half_life: structure
verified_on: 2026-10-19
tier: 1
source: https://github.com/boscocp/game-ai-kit
invalidated_if: a behaviour's formula changes, the vehicle stops being explicit Euler, or Vector2 becomes double precision
teaches: none
-->

> Six trajectories, two languages, and the files that say they drove the
> same way.

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
repository.

    python3 spec/vectors/steering/derive.py spec/vectors/steering

## The tolerance

1e-3 in the vector's own units, on every coordinate. Godot's `Vector2` holds
32-bit floats and the file 64-bit answers
([`docs/godot/vector2-is-single-precision.md`](../../../docs/godot/vector2-is-single-precision.md)).
Measured on 4.7.2, the largest difference on the GDScript side was 8.1e-5,
in `seek-and-avoid-go-round`; Python lands far closer. A sample moved by ten
times the tolerance fails both sides' tests.

## The six

| file | what it pins |
|---|---|
| `seek-turns-and-overshoots` | seek reaches the target at speed near step 225 and is past it by 260 |
| `arrive-slows-and-stops` | arrive brakes inside its radius and is still on the target by step 300 |
| `pursue-a-crossing-quarry` | pursue aims ahead of a quarry crossing in front, which moves on after every step |
| `avoid-swerves-alone` | avoid slows and turns while the obstacle is ahead, then asks for nothing |
| `seek-and-avoid-go-round` | the two, weighted 1 and 2, go round an obstacle a little off the line |
| `seek-and-avoid-tie-on-the-line` | the obstacle on the line: the weighted sum stalls in front of it, for good |

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

A behaviour is `seek` (`target`), `arrive` (`target`, `braking_radius`,
optional `time_to_target`), `pursue` (`quarry` with `position` and
`velocity`, optional `max_prediction`; the quarry moves on by its velocity
after every step) or `avoid` (`centres`, `radii`, `look_ahead`). A field a
kind does not know is refused on both sides.
