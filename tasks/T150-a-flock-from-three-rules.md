# T150 — A flock from three rules

Size: M · Prereqs: T112 · Files: `godot/addons/ai_steering/`, `godot/test/ai_steering/`, `python/gameaikit/steering/`, `python/tests/`, `spec/vectors/steering/`, `godot/demos/flocking/`, `modules/`, `godot/menu/catalogue.json`, `docs/techniques/`, `docs/concepts/steering.md`, `Makefile`

## Goal

The owner asked on 2026-11-06 whether the racing game had flocking. It
does not: the kit steers one vehicle at a time (seek, arrive, pursue,
avoid, a PID and a heat line). Its only group rule is the RTS core's
separation (`ai_rts_core/rts_world.gd`, `_keep_apart`), which is written there
because an addon may not depend on another.

Reynolds' boids (1987) make a flock from three rules that each boid
applies to the neighbours it can see:

- separation: steer away from neighbours that are too close;
- alignment: steer towards the neighbours' average heading;
- cohesion: steer towards the neighbours' centre.

No boid knows about the flock, and the flock still appears. That is the
lesson, and it needs a demo where each rule can be switched off to see
what it was doing.

## Decisions written down first

_The owner asked for this task on 2026-11-06. The decisions below are this session's proposal; the wave that takes the task confirms them, or brings them back to the owner._

- **In `ai_steering`, beside the single-vehicle behaviours.** There are three
  `SteeringBehaviour`s: `SeparationBehaviour`, `AlignmentBehaviour` and
  `CohesionBehaviour`. Each one reads a neighbour list that it is given,
  and none of them finds the neighbours itself. A small `Flock` sums them
  with weights, each force no longer than `max_force`, like the existing
  behaviours.
- **The neighbour query is the caller's.** The demo uses a uniform grid,
  so the cost is not n². The addon header states that a naive neighbour
  search is O(n²) and says when not to use flocking: a group that must
  arrive in order, or that needs a formation.
- **A new demo, `make demo-flocking`**, with about a hundred boids in 2D:
  - 1, 2 and 3 switch separation, alignment and cohesion;
  - the watched boid's neighbour radius and its three forces are drawn, one
    colour each;
  - a click places an obstacle that `avoid` already knows how to dodge.

  Shown, as invariant 13 requires: the three forces of the watched boid and
  which neighbours it counted.
- **Twins and vectors:** a Python twin of the three rules. The vectors are
  hand-worked cases: a boid with two neighbours gives three forces whose
  values are written out on the page. They are `derive.py`'s, with no
  import from the repository.
- **Deterministic:** a seed places the boids, and neighbours are taken in
  id order, so two runs agree, as the RTS core does.

## Acceptance

```bash
make test-steering-vectors
make test-python
make test-godot-some SUITES="test/ai_steering"
python3 scripts/check_addon_deps.py
make lint-modules
make test-demo-overlays
make lint-demos
```

## Manual check

Run `make demo-flocking`:

1. Turn off cohesion. Does the flock spread out, without the boids
   bumping into each other?
2. Turn off separation. Do they pile into one point?
3. Turn off alignment. Do they mill around without a common heading?
4. With all three on, does a flock appear and turn as one around an
   obstacle?
