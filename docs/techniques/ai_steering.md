# ai_steering — which way to push, and how hard

<!-- doc-meta
half_life: practice
verified_on: 2026-10-26
tier: 2
source: https://www.red3d.com/cwr/steer/gdc99/ ; book:Ian Millington, "AI for Games", 3rd edition, CRC Press, 2019 -- chapter 3 on movement
invalidated_if: the kit's SteeringVehicle, SteeringBehaviour or Steering.combined signatures change, or the demos that use them are renamed
teaches: steering
-->

> Português: [ai_steering.pt-BR.md](ai_steering.pt-BR.md). The words that
> stay in English are in the [glossary](glossary.pt-BR.md).

## What it decides {#what}

Not where to go -- that is a search or a decision above it -- but how to get
there in continuous space, one frame at a time: the force to apply now.
Seek, arrive, pursue and avoid each turn "where I am, and where that is"
into a force no larger than the vehicle can apply, and `Steering.combined`
adds several with weights. The racing demos add a PID controller and Melder's
heat line. The book: Reynolds, *Steering Behaviors for Autonomous
Characters* (GDC 1999); Millington, *AI for Games*, chapter 3.

## When not to use it {#when-not}

A real car model, whose turning depends on speed and grip: then the
behaviours still say where to go and the car model says how. Walls,
corridors and crowds of obstacles: avoid knows only circles, and two of them
pushing opposite ways leave the vehicle stuck -- a flow field or a navigation
mesh is the answer there.

## Where to watch it {#watch}

- `make demo-steering` -- four arenas: seek, arrive, pursue, seek with avoid.
  The **orange** arrow is what the behaviour asks for, the **blue** one where
  the vehicle is going: when they disagree it is about to turn. **Click**
  moves a target, **space** pauses, **.** steps one frame.
- `make demo-racing` -- the driver seeks a point ahead on the racing line;
  **1-3** pick the AI, **Tab** watches the three. `make demo-racing3d` steers
  with the PID controller (**1**) and the heat line (**2**).
- Which demo uses which technique, both ways: the catalogue (T76, coming).

## In this kit {#in-this-kit}

`godot/demos/steering/steering_lane.gd` builds one `SteeringVehicle` per arena
and asks its behaviour for a force every physics frame. The knobs that
matter:

| knob | where | what it changes |
|---|---|---|
| top speed | `SteeringVehicle.max_speed` | the fastest it goes |
| strength | `SteeringVehicle.max_force` | how hard it can turn and brake; every force is clamped to it |
| braking radius | `ArriveBehaviour.new(target, radius)` | where arrive starts slowing; too small and it overshoots |
| look-ahead | `PursueBehaviour` `max_prediction`, `AvoidBehaviour` `look_ahead` | how far ahead it guesses, or looks for obstacles |
| weights | `Steering.combined(vehicle, forces, weights)` | how much each behaviour counts when several speak |

## In your own project {#your-project}

### What to copy {#copy}

One folder: `godot/addons/ai_steering/`. It needs nothing else, not even
`ai_core`. Open the project once, or run `godot --headless --import`, so
Godot registers its classes.

### A minimal example {#example}

A `Node2D` of yours that drives itself to `target` and stops there. Set
`target` from a click or a waypoint. This file is run by
`arrive_example_test.gd`, and the gate holds the page equal to it.

<!-- example: godot/test/ai_steering/arrive_example.gd -->
```gdscript
# The minimal example on docs/techniques/ai_steering.md, run by
# arrive_example_test.gd. A node of your own that drives itself to a point
# and stops there.
extends Node2D

## Where it is going. Set it from anything: a click, a waypoint, a path.
var target: Vector2 = Vector2(300, 200)

## The point the forces move: top speed 120 a second, and it may change its
## velocity by at most 240 a second.
var vehicle := SteeringVehicle.new(Vector2.ZERO, Vector2.ZERO, 120.0, 240.0)


func _ready() -> void:
	# Start where the node was placed, or it would jump to the origin.
	vehicle.position = position


func _physics_process(delta: float) -> void:
	# Brake from 100 units out. Seek here instead, and it overshoots forever.
	var arrive := ArriveBehaviour.new(target, 100.0)
	vehicle.step(arrive.force(vehicle), delta)
	position = vehicle.position
```

### What you implement {#implement}

A new behaviour is one class: extend `SteeringBehaviour` and return a force
from `force(vehicle)`, clamped with `Steering.clamped`. If your node has its
own physics -- a `CharacterBody2D` -- keep the vehicle as the point the
behaviours reason about, and copy its velocity into `velocity` before
`move_and_slide()`.

## Deeper {#deeper}

- Why seek never stops and arrive does: [concepts/steering.md](../concepts/steering.md).
- Steering a car round a track: [concepts/racing-ai.md](../concepts/racing-ai.md).
