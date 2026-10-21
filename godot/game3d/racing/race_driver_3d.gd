## The driver: from what it sees, a steering angle and two pedals.
##
## An agent in AIMA's sense, and nothing about it is a track: it perceives
## a `RaceView3D` -- the road ahead in its own frame, its speed, the cars
## it can see -- and acts on the car it drives. Put on another track it sees
## another road and drives it the same way; `racing3d_ladder.gd` holds that
## on a track it was never tuned on, and `racing3d_portable_test.gd` that
## its code names only an allow-list of classes and no track (a reading,
## blind to a number tuned to one track). Each decision, in order:
##
##   1. **How fast the road ahead allows** (T23's speed profile, made from
##      what it sees): at each point, the speed at which the bend there asks
##      the grip margin's share of the grip, carried back towards the car at
##      that share of the braking. The grip and the braking are what the
##      driver *measured* its car to have (`GripTest3D`), not numbers off its
##      sheet -- the tyres decide them now. Following the profile is braking
##      on time: the car brakes where, braking that hard, it would otherwise
##      no longer make the bend ahead.
##   2. **Where across the road** (`RaceTraffic3D`): on the line, or where
##      the heat line's ball rests with other cars about; plus the wander.
##   3. **Where to steer** (T23's pure pursuit): at the point `lookahead`
##      seconds of travel down the line, moved across by step 2, with the
##      bicycle model's angle for the arc that reaches it -- and a **PID**
##      on how far the car is from where step 2 wants it (Melder &
##      Tomlinson), because a car whose tyres slip needs more than the arc.
##      Never past the angle the measured slip makes worth turning.
##   4. **The pedals**: a PI controller on how far the car is from the
##      speed it wants. A car ahead where it means to be caps that speed.
##
## Three techniques can be switched off, which is what the player does:
## `full_pid` (off: proportional only -- measured, this car swings wider
## each time until it leaves the road), the traffic's `heat_vision` (off: one rival at a time),
## and the measured grip, which the race decides (`Race3D.measured_grip`).
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
## The steering PID on metres off the line, in radians: Melder & Tomlinson's
## rule of thumb, Ki and Kd about half of Kp. The integral may add at most
## a tenth of a radian.
const LINE_GAINS: Array[float] = [0.04, 0.02, 0.02, 0.1]
## The pedal's PI on metres a second off the speed wanted: two metres a
## second slow is full throttle. No derivative: the speed wanted jumps where
## the road changes, and the rate of a jump is a kick on the pedal.
const SPEED_GAINS: Array[float] = [0.5, 0.25, 0.0, 0.3]
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
## Where across the road this decision wanted the car, and how far off
## that the car was: the error the steering PID worked on.
var wanted_left: float = 0.0
var line_error: float = 0.0
## The techniques a player may switch off.
var full_pid: bool = true
var line_pid := PidController.new(LINE_GAINS[0], LINE_GAINS[1], LINE_GAINS[2], LINE_GAINS[3])
var speed_pid := PidController.new(SPEED_GAINS[0], SPEED_GAINS[1], SPEED_GAINS[2], SPEED_GAINS[3])
var traffic := RaceTraffic3D.new()


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
	var reach: float = maxf(MIN_AIM, used["lookahead"] * view.speed)
	var ahead: int = _point_at(view, reach)
	var side: float = traffic.plan(view.rivals, view.room_left[ahead] - AIM_MARGIN,
		view.room_right[ahead] - AIM_MARGIN, view.speed, view.step)
	wanted_left = side + used["wander"] * drift(view.time)
	target_speed = minf(limits[_first_ahead(view)], _traffic_limit(view))
	braking_in = _braking_in(view)
	_aim(view, reach, wanted_left)
	line_pid.proportional_only = not full_pid
	speed_pid.proportional_only = not full_pid
	line_error = wanted_left - view.cross_track
	var most: float = steer_limit(view.speed)
	var pursuit: float = pursuit_steer(aim_forward, aim_left, wheelbase)
	steer = clampf(pursuit + line_pid.update(line_error, view.step), -most, most)
	var pedal: float = speed_pid.update(target_speed - view.speed, view.step)
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
## that has both). A view too short to measure over has no bend.
static func bend_at(view: RaceView3D, index: int) -> float:
	if view.line_forward.size() < 2 * BEND_REACH + 1:
		return 0.0
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


# The slowest car close ahead where this one is or means to be -- near
# enough that braking to its speed must start now -- caps the speed;
# infinity when none is. Where it is, too: a car that has only decided to
# pull out is still behind the other.
func _traffic_limit(view: RaceView3D) -> float:
	var capped: float = INF
	for rival: PackedFloat64Array in view.rivals:
		var reach: float = _stopping(view.speed, rival[2]) + FOLLOW_MARGIN
		var in_the_way: bool = absf(rival[1] - wanted_left) < CAR_WIDTH or absf(rival[1] - view.cross_track) < CAR_WIDTH
		if rival[0] > 0.0 and rival[0] < reach and in_the_way:
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


# The first point at least `distance` metres along the line, or the last.
func _point_at(view: RaceView3D, distance: float) -> int:
	var walked: float = 0.0
	for index: int in range(view.line_forward.size() - 1):
		if walked >= distance:
			return index
		walked += _distance(view, index, index + 1)
	return view.line_forward.size() - 1


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
