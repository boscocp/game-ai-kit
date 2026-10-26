# The racing driver — a point ahead, a speed profile, no rubber band

<!-- doc-meta
half_life: practice
verified_on: 2026-10-26
tier: 2
source: https://www.gameaipro.com/ ; https://www.ri.cmu.edu/pub_files/pub3/coulter_r_craig_1992_1/coulter_r_craig_1992_1.pdf
invalidated_if: RacingDriver, RacingLevel or RacingTrack change what they decide, or demo-racing is renamed
teaches: racing-ai
-->

> Português: [racing_driver.pt-BR.md](racing_driver.pt-BR.md). The words
> that stay in English are in the [glossary](glossary.pt-BR.md).

## What it decides {#what}

Two things every step, the two every AI driver makes. **Where to steer**:
at a point a fixed distance ahead on the racing line -- pure pursuit's one
idea -- asked of `ai_steering`'s seek, and turned into a turn rate.
**How fast**: no faster than the track's speed profile allows here. The
profile is worked out once: each corner's limit from its curvature and the
car's grip, then carried backwards along the line at the car's braking, so
following it is braking on time. Difficulty is three knobs fixed for the
whole race -- how far ahead it looks, how much of its grip it dares use,
how far it wanders off the line -- and never a rubber band that speeds a
car up because it is behind. The sources: the racing chapters of *Game AI
Pro*, and Coulter's pure pursuit (1992).

## When not to use it {#when-not}

Racing wheel to wheel: this driver passes the car ahead of it, but does
not defend, block or pick a moment -- the 3D racer's heat line is how
shipped games choose where to pass. A car whose turning is a full tyre
model: the profile assumes a grip limit, and a car that slides needs its
controller (`make demo-racing3d` steers a PID). And a track that changes
during the race: the profile is computed from the line once.

## Where to watch it {#watch}

- `make demo-racing` -- race an AI in the same car. **1-3** pick its level,
  **Tab** watches the three AIs; the overlay draws the point each driver
  aims at and the braking point it must already be slowing for.
- Which demo uses which technique, both ways: the catalogue (T76, coming).

## In this kit {#in-this-kit}

`godot/demos/racing/racing_driver.gd` decides; `racing_track.gd` builds the
racing line and its speed profile from fixed nodes; `racing_level.gd` is a
difficulty, the three knobs and nothing else; `racing_car.gd` is the car
both you and the AI drive. `godot/test/demo_racing/racing_does_not_cheat.gd`
holds that no knob moves during a race. The knobs that matter:

| knob | where | what it changes |
|---|---|---|
| lookahead | `RacingLevel.lookahead` | metres down the line it aims; longer turns in earlier and smoother, shorter weaves |
| grip margin | `RacingLevel.grip_margin` | the share of grip and brakes it dares use; less brakes earlier and corners slower |
| wander | `RacingLevel.wander` | metres the aimed-at point drifts off the line; the driver not quite on it |

## In your own project {#your-project}

### What to copy {#copy}

Nothing on the Python side: this driver is not trained, and has no Python
half -- `python/gameaikit/racing/` is the 3D racer's driver, a different
one. In Godot, `godot/addons/ai_steering/` for the vehicle and seek. **A
finding:** `RacingDriver` cannot be wired into another game in a few
lines: it reads `RacingTrack`, whose line is built from the demo's own
fixed nodes, and drives `RacingCar`. The example below is the two ideas on
their own, over any line you give it.

### A minimal example {#example}

A car of yours that drives round a racing line you give it -- a baked
`Path2D`, say: it aims a few points ahead and is never faster than the
line's speed profile allows. Placed off the line, it finds it. This file is
run by `racing_line_example_test.gd`, and the gate holds the page equal to
it.

<!-- example: godot/test/demo_racing/racing_line_example.gd -->
```gdscript
# The minimal example on docs/techniques/racing_driver.md, run by
# racing_line_example_test.gd. A car of your own that drives round a racing
# line: it steers at a point ahead on the line, and is never faster than the
# line's speed profile says it can be and still take what is coming.
extends Node2D

## The racing line: a closed loop of points a few units apart, in the same
## space as `position` -- a baked Path2D, say. Set it before the node enters
## the tree.
var line := PackedVector2Array()
## How many points ahead it steers at. More cuts corners and steadies the
## car; fewer follows the line tightly and weaves.
var lookahead: int = 8
## The difficulty: the share of the grip it dares to use. 1 is on the limit;
## below it brakes earlier and corners slower. No rubber band.
var grip_margin: float = 1.0

## How hard it can turn and brake, units a second squared: a corner of
## radius r is taken at most at sqrt(GRIP * r).
const GRIP: float = 300.0
const BRAKING: float = 400.0
## How quickly it closes on the velocity it wants: a tenth of a second.
const RESPONSE: float = 10.0

## Top speed 400 a second; it may change its velocity by 600 a second.
var vehicle := SteeringVehicle.new(Vector2.ZERO, Vector2.ZERO, 400.0, 600.0)
## The fastest it will be at each point of the line.
var speed_limits := PackedFloat64Array()

var _at: int = 0


func _ready() -> void:
	vehicle.position = position
	speed_limits = speed_profile(line, GRIP * grip_margin, BRAKING * grip_margin, vehicle.max_speed)
	_at = _nearest(0, line.size())


func _physics_process(delta: float) -> void:
	_at = _nearest(_at, 2 * lookahead)
	var aim: Vector2 = line[(_at + lookahead) % line.size()]
	# Seek, with the profile's speed in place of top speed: the force is
	# the velocity it wants minus the one it has, closed at RESPONSE.
	var wanted: Vector2 = vehicle.position.direction_to(aim) * speed_limits[_at]
	vehicle.step((wanted - vehicle.velocity) * RESPONSE, delta)
	position = vehicle.position


## Each point's speed limit: the corner there, sqrt(grip / curvature), then
## carried backwards, so the car is slow enough to brake for every corner
## ahead in time. Twice round the loop, so the last corner reaches the first.
static func speed_profile(points: PackedVector2Array, grip: float, braking: float, top: float) -> PackedFloat64Array:
	var count: int = points.size()
	var limits := PackedFloat64Array()
	for index: int in range(count):
		var bend: float = _curvature(points[index - 1], points[index], points[(index + 1) % count])
		limits.append(top if bend == 0.0 else minf(top, sqrt(grip / bend)))
	for step: int in range(2 * count, 0, -1):
		var here: int = (step - 1) % count
		var next: int = step % count
		var room: float = points[here].distance_to(points[next])
		limits[here] = minf(limits[here], sqrt(limits[next] * limits[next] + 2.0 * braking * room))
	return limits


# The point of the line nearest the car among the `span` from `from` on.
func _nearest(from: int, span: int) -> int:
	var best: int = from
	for ahead: int in range(span):
		var index: int = (from + ahead) % line.size()
		if vehicle.position.distance_to(line[index]) < vehicle.position.distance_to(line[best]):
			best = index
	return best


# One over the radius of the circle through three points; 0 on a straight.
static func _curvature(before: Vector2, here: Vector2, after: Vector2) -> float:
	var twice_area: float = absf((here - before).cross(after - before))
	var sides: float = before.distance_to(here) * here.distance_to(after) * after.distance_to(before)
	return 0.0 if sides == 0.0 else 2.0 * twice_area / sides
```

### What you implement {#implement}

The line: a closed loop of evenly spaced points -- draw a `Path2D`, and
`curve.get_baked_points()` gives them. The car: the example stands a
`SteeringVehicle` in for it; a `CharacterBody2D` of yours copies the
vehicle's velocity into `velocity` before `move_and_slide()`, and a car
that can only turn takes the angle to the aim point as its steering, as
`RacingDriver.pursuit_turn` does. And the levels: give each a lookahead and
a grip margin -- and if you add a wander, drift the aim point sideways --
fixed for the whole race.

## Deeper {#deeper}

- How racing AI is made, and where each knob comes from:
  [concepts/racing-ai.md](../concepts/racing-ai.md).
- Steering, the force underneath: [ai_steering](ai_steering.md).
