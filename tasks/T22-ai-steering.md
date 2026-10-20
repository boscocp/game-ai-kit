# T22 — `ai_steering`: the first thing in this kit that is not on a grid

Size: M · Prereqs: T21 · Files: `godot/addons/ai_steering/`, `python/gameaikit/steering/`

## Goal

Everything in this kit so far decides on a grid and in turns: a cell, a move, a
plan, a yes-or-no about a fight. A car has none of that. It has a heading, a
speed and a steering angle, and the question is not *which cell* but *how hard
to turn, right now*.

So this is a new family rather than a new algorithm: steering behaviours, in
the form everybody has used since Reynolds — seek, arrive, pursue, and avoid —
each one a function from *where I am and where that is* to a force, and all of
them added together.

The lesson is the one people get wrong first: **arrive is not seek.** A car
that seeks its target drives at full speed into it and oscillates forever; a
car that arrives slows inside a braking radius and stops. The two differ by
four lines, and the difference is the whole of why a steering AI looks
competent or drunk.

## Steps

1. `Steering`: the force each behaviour returns, and the one place they are
   summed and clamped to what the vehicle can actually do. A behaviour that
   returns a force larger than the vehicle's limit is a behaviour that lies.
2. Seek, arrive, pursue and avoid, one small file each, each with its own
   *when not to use it*.
3. A vehicle model crude on purpose: position, velocity, a maximum force and a
   maximum speed. No suspension, no tyre model, no drift. T23 says out loud
   that this is not a driving simulator.
4. The same maths in `python/gameaikit/steering/`, standard library only, so
   the lesson is reachable at tier 1 — invariant 5 — and so the two sides can
   be held to one answer.
5. Conformance vectors in `spec/vectors/steering/`, run from both languages,
   pinning the trajectory a behaviour produces from a stated start over a
   stated number of steps.

## Acceptance

```bash
make test-godot
make test-python
make test-vectors
python3 scripts/check_addon_deps.py
python3 scripts/check_readability.py
```

```bash
./scripts/godot --headless --path godot -s res://test/ai_steering/steering_properties.gd
```

Three properties over seeded starts, because one trajectory that happens to
end in the right place proves nothing:

- a vehicle running **arrive** comes to rest inside its braking radius and
  stays there, rather than orbiting;
- a vehicle running **seek** at a stationary target never comes to rest, which
  is the defect arrive exists to fix and is asserted here so the difference is
  a measurement rather than a claim;
- no behaviour ever returns a force above the vehicle's maximum, on any input,
  including a target on top of the vehicle and a target at infinity.

## Manual check

Open the demo and watch one vehicle under each behaviour, with the force drawn
as an arrow. Per T21: you should be able to say what it is about to do, and
why, before it does it. An arrow pointing somewhere the vehicle does not go is
the finding worth having.
