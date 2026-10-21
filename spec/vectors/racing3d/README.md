# Conformance vectors: the 3D driver

<!-- doc-meta
half_life: structure
verified_on: 2026-10-21
tier: 1
source: https://github.com/boscocp/game-ai-kit
invalidated_if: a step of RaceDriver3D's decision changes -- the profile, the aim, the steering limit, the pedals, the traffic rule -- or the view gains a field the decision reads
teaches: none
-->

> One decision, two languages, and the files that say they decided the
> same from the same snapshot.

`RaceDriver3D` (GDScript, `godot/game3d/racing/`) and `gameaikit.racing`
(Python) make the same decision on every physics frame of T54's race: how
fast the road ahead allows, where to steer, and the two pedals. Each vector
is one `.json` file: a driver -- its level's three knobs, what it knows of
its car, its wander's two phases -- and the snapshots (`RaceView3D`) it is
shown one after another, each with what it must decide. Both sides decide
them and check every number against the file, never against each other:
`make test-vectors` on the GDScript side, `make test-python` on the Python
side.

ADR 0018's invariant 5 rule is why: the 3D race needs the engine, the
decision does not. A snapshot is in the car's own frame, so a vector is a
road written as straights and arcs, never a track.

## Where the numbers came from

From neither implementation: `derive.py`, beside the vectors, builds each
snapshot from its stated road and decides it with a third copy of the rules
in plain lists, importing nothing from this repository. Independent of the
code, not of its author: it makes the same choices, so it catches a slip in
transcribing them, not a choice that is wrong.

    python3 spec/vectors/racing3d/derive.py spec/vectors/racing3d

## The tolerance

1e-9 on every number. Both sides compute in 64-bit floats -- the view's
arrays are `PackedFloat64Array`, and the decision never touches a
`Vector2` -- and measured on 4.7.2 they agree to the last digit printed.
A gain moved from 0.04 to 0.041 fails the GDScript side; the braking
carried back at 1.9 instead of 2 fails three vectors on the Python side.

## The shape

```json
{
  "name": "a-straight-at-speed",
  "why": "what this vector is for",
  "driver": {"level": {"title": "probe", "lookahead": 0.7, "grip_margin": 0.9, "wander": 0.0},
             "known": {"top_speed": 50, "wheelbase": 2.6, "max_steer": 0.5, "grip": 9.4, "braking": 8.4, "slip_steer": 0.03},
             "drift_phases": [0, 0]},
  "frames": [{"view": {"time": 0, "step": 0.0167, "speed": 30, "cross_track": 0,
                       "line_forward": [], "line_left": [], "room_left": [], "room_right": [], "rivals": []},
              "expect": {"steer": 0, "throttle": 1, "brake": 0, "target_speed": 50,
                         "braking_in": -1, "aim_forward": 21, "aim_left": 0}}]
}
```

A rival is `[metres ahead along the track, metres left of the line, metres
a second]`. Each file's `why` says what it pins.
