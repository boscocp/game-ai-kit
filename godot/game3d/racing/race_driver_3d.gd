## The driver: from what it sees, a steering angle and two pedals.
##
## An agent in AIMA's sense, and nothing about it is a track: it perceives
## a `RaceView3D` -- the road ahead in its own frame, its speed, the cars
## it can see -- and acts on the car it drives. Put on another track it sees
## another road and drives it the same way; `racing3d_portable.gd` holds
## that on a track it was never tried on. Each decision, in order:
##
##   1. **How fast the road ahead allows** (T23's speed profile, made from
##      what it sees): at each point, the speed at which the bend there asks
##      the grip margin's share of the grip, carried back towards the car at
##      that share of the braking. The grip and the braking are what the
##      driver *measured* its car to have (`GripTest3D`), not numbers off its
##      sheet -- the tyres decide them now. Following the profile is braking
##      on time: the car brakes where, braking that hard, it would otherwise
##      no longer make the bend ahead.
##   2. **Where to steer** (T23's pure pursuit): at the point `lookahead`
##      metres down the line, drifted `wander` metres sideways, with the
##      bicycle model's angle for the arc that reaches it.
##   3. **The pedals**: proportional to how far the car is from the speed
##      it wants. A car ahead in its lane caps that speed at the other's.
##
## The knobs are read once a decision, through the three `*_now`
## functions, and what was read is kept in `used`, recorded from inside the
## controller: a knob changed where it is used cannot hide. Linear in the
## points it sees, sixty of them.
##
## When not to use it: a car whose sheet it has not measured. Steps 1 and 3
## trust that the grip and braking it holds are the car's.
class_name RaceDriver3D
extends RefCounted

## Points either side of a point the bend there is measured over: six
## metres, so it is the road's bend and not the rounding between points.
const BEND_REACH: int = 2
## How wide a car is taken to be when asking whether one is in the way.
const CAR_WIDTH: float = 2.2
## Metres beyond its braking distance a car ahead is followed from.
const FOLLOW_MARGIN: float = 15.0
## Pedal per metre a second the car is off the speed it wants: two metres a
## second slow is full throttle.
const PEDAL_GAIN: float = 0.5
## Radians of steering added per metre the car is off the line it wants.
## Pure pursuit steers for the arc; a car whose tyres slip needs more than
## the arc, and this is what gives it.
const STEER_GAIN: float = 0.04
## The nearest the aimed-at point comes, in metres, however slow the car.
const MIN_AIM: float = 8.0
## Metres of tarmac the aimed-at point keeps from either edge.
const AIM_MARGIN: float = 1.0

var level: RaceLevel3D
## What the driver knows of its car: off its sheet, the top speed, the
## wheelbase and how far the wheels turn; and, as it measured them, the
## sideways grip and the braking in metres a second squared, and how much
## more than the arc the wheels are worth turning, in radians.
var top_speed: float
var wheelbase: float
var max_steer: float
var grip: float
var braking: float
var slip_steer: float
## The phases of the two slow waves the wander follows.
var drift_phases := PackedFloat64Array([0.0, 0.0])

## What the last decision chose, for the car, the overlay and the tests.
var steer: float = 0.0
var throttle: float = 0.0
var brake: float = 0.0
var target_speed: float = 0.0
## Metres ahead to the first point slower than the car is now: where it
## must already be braking. -1 when none is in sight.
var braking_in: float = -1.0
## The point aimed at, in the car's frame.
var aim_forward: float = 0.0
var aim_left: float = 0.0
## The speed limit at each point it saw.
var limits := PackedFloat64Array()
## The three knobs as this decision used them.
var used: Dictionary = {}


## A driver for `driving_level`. `known` holds the car as the driver knows
## it: `top_speed`, `wheelbase`, `max_steer`, `grip`, `braking` and
## `slip_steer`.
func _init(driving_level: RaceLevel3D, known: Dictionary) -> void:
	level = driving_level
	top_speed = float(known["top_speed"])
	wheelbase = float(known["wheelbase"])
	max_steer = float(known["max_steer"])
	grip = float(known["grip"])
	braking = float(known["braking"])
	slip_steer = float(known["slip_steer"])


## Draw the wander's two phases from `seed_value`: the same seed drifts the
## same way every race.
func drift_from(seed_value: int) -> void:
	var dice := RandomNumberGenerator.new()
	dice.seed = seed_value
	drift_phases = PackedFloat64Array([dice.randf_range(0.0, TAU), dice.randf_range(0.0, TAU)])


## Decide this frame's steering and pedals from `view`.
func decide(view: RaceView3D) -> void:
	used = {"lookahead": lookahead_now(), "grip_margin": grip_margin_now(), "wander": wander_now()}
	limits = speed_limits(view, used["grip_margin"])
	target_speed = minf(limits[_first_ahead(view)], _traffic_limit(view))
	braking_in = _braking_in(view)
	_aim(view, maxf(MIN_AIM, used["lookahead"] * view.speed), used["wander"] * drift(view.time))
	var wanted_left: float = used["wander"] * drift(view.time)
	var correction: float = STEER_GAIN * (wanted_left - view.cross_track)
	var most: float = steer_limit(view.speed)
	steer = clampf(pursuit_steer(aim_forward, aim_left, wheelbase) + correction, -most, most)
	var pedal: float = PEDAL_GAIN * (target_speed - view.speed)
	throttle = clampf(pedal, 0.0, 1.0)
	brake = clampf(-pedal, 0.0, 1.0)


## The lookahead this decision steers with. The level's, always.
func lookahead_now() -> float:
	return level.lookahead


## The grip margin this decision brakes and corners with. The level's, always.
func grip_margin_now() -> float:
	return level.grip_margin


## The wander this decision drifts with. The level's, always.
func wander_now() -> float:
	return level.wander


## The fastest the driver will be at each point it sees: the bend's limit at
## `margin` of its grip, then carried back from the far end at `margin` of
## its braking, never above the top speed.
func speed_limits(view: RaceView3D, margin: float) -> PackedFloat64Array:
	var count: int = view.line_forward.size()
	var allowed := PackedFloat64Array()
	for index: int in range(count):
		var bend: float = absf(bend_at(view, index))
		allowed.append(sqrt(margin * grip / bend) if bend > 0.0 else INF)
	for index: int in range(count - 2, -1, -1):
		var gap: float = _distance(view, index, index + 1)
		var reachable: float = sqrt(allowed[index + 1] * allowed[index + 1] + 2.0 * margin * braking * gap)
		allowed[index] = minf(allowed[index], reachable)
	for index: int in range(count):
		allowed[index] = minf(allowed[index], top_speed)
	return allowed


## How sharply the line bends at point `index` of the view, in 1 / metres,
## positive to the left: one over the radius of the circle through it and
## the points `BEND_REACH` either side (nearer the ends, the nearest point
## that has both).
static func bend_at(view: RaceView3D, index: int) -> float:
	var middle: int = clampi(index, BEND_REACH, view.line_forward.size() - 1 - BEND_REACH)
	var before: int = middle - BEND_REACH
	var after: int = middle + BEND_REACH
	var turned: float = (view.line_forward[middle] - view.line_forward[before]) * (view.line_left[after] - view.line_left[middle]) \
		- (view.line_left[middle] - view.line_left[before]) * (view.line_forward[after] - view.line_forward[middle])
	var sides: float = _distance(view, before, middle) * _distance(view, middle, after) * _distance(view, before, after)
	return 2.0 * turned / sides if sides > 0.0 else 0.0


## The most the wheels are worth turning at `speed`: the arc the grip
## allows at that speed, plus the steering the tyres' slip asks at the
## peak. Past it the front slides and the car turns less, not more.
func steer_limit(speed: float) -> float:
	var arc: float = atan(wheelbase * grip / maxf(speed * speed, 1e-6))
	return minf(max_steer, arc + slip_steer)


## The front wheels' angle for the arc from the car through the point
## (`forward`, `left`) in its frame: pure pursuit's curvature, 2 sin(angle)
## over the distance, turned into a wheel angle by the bicycle model.
static func pursuit_steer(forward: float, left: float, axles: float) -> float:
	var distance: float = sqrt(forward * forward + left * left)
	if distance <= 0.0:
		return 0.0
	return atan(axles * 2.0 * sin(atan2(left, forward)) / distance)


## Between -1 and 1, slowly: two sine waves at unrelated rates, so the drift
## does not repeat on every lap.
func drift(time: float) -> float:
	return (sin(0.43 * time + drift_phases[0]) + sin(1.13 * time + drift_phases[1])) / 2.0


# The first point the car has not yet passed.
func _first_ahead(view: RaceView3D) -> int:
	for index: int in range(view.line_forward.size()):
		if view.line_forward[index] >= 0.0:
			return index
	return 0


# The slowest car close ahead in the car's lane -- near enough that braking
# to its speed must start now -- caps the speed; infinity when none is.
func _traffic_limit(view: RaceView3D) -> float:
	var capped: float = INF
	for rival: PackedFloat64Array in view.rivals:
		var reach: float = _stopping(view.speed, rival[2]) + FOLLOW_MARGIN
		var in_lane: bool = absf(rival[1] - view.cross_track) < CAR_WIDTH
		if rival[0] > 0.0 and rival[0] < reach and in_lane:
			capped = minf(capped, rival[2])
	return capped


# Metres to brake from `speed` down to `other`, at the margin's braking.
func _stopping(speed: float, other: float) -> float:
	if speed <= other:
		return 0.0
	return (speed * speed - other * other) / (2.0 * used["grip_margin"] * braking)


# Metres ahead to the first point whose limit is under the car's speed.
func _braking_in(view: RaceView3D) -> float:
	for index: int in range(_first_ahead(view), limits.size()):
		if limits[index] < view.speed:
			return view.line_forward[index]
	return -1.0


# The point `distance` metres along the line from its first point, pushed
# `sideways` metres to the line's left and kept on the tarmac.
func _aim(view: RaceView3D, distance: float, sideways: float) -> void:
	var walked: float = 0.0
	var last: int = view.line_forward.size() - 1
	var index: int = 0
	while index < last - 1 and walked + _distance(view, index, index + 1) < distance:
		walked += _distance(view, index, index + 1)
		index += 1
	var piece: float = _distance(view, index, index + 1)
	var share: float = clampf((distance - walked) / piece, 0.0, 1.0) if piece > 0.0 else 0.0
	var along_forward: float = (view.line_forward[index + 1] - view.line_forward[index]) / maxf(piece, 1e-9)
	var along_left: float = (view.line_left[index + 1] - view.line_left[index]) / maxf(piece, 1e-9)
	var room_left: float = lerpf(view.room_left[index], view.room_left[index + 1], share) - AIM_MARGIN
	var room_right: float = lerpf(view.room_right[index], view.room_right[index + 1], share) - AIM_MARGIN
	var pushed: float = clampf(sideways, -room_right, room_left)
	aim_forward = lerpf(view.line_forward[index], view.line_forward[index + 1], share) - along_left * pushed
	aim_left = lerpf(view.line_left[index], view.line_left[index + 1], share) + along_forward * pushed


static func _distance(view: RaceView3D, first: int, second: int) -> float:
	var forward: float = view.line_forward[second] - view.line_forward[first]
	var left: float = view.line_left[second] - view.line_left[first]
	return sqrt(forward * forward + left * left)
