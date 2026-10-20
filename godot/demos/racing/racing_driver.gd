## The driver: a point to steer at, and a speed to be going. Every step.
##
## The two decisions every AI driver in the survey makes, and the two a
## person can watch (`docs/concepts/racing-ai.md`):
##
##   1. **Where to steer.** Find the point `lookahead` metres down the racing
##      line, drifted `wander` metres sideways, and ask `ai_steering`'s seek
##      which way to go for it. That is pure pursuit's idea -- chase a point
##      ahead on the path -- with T22's behaviour choosing the direction, and
##      pure pursuit's formula turning the angle into a turn rate.
##   2. **How fast.** The track's speed limit at this sample, scaled by the
##      grip margin the driver dares. The limit was already carried back from
##      every corner at the braking the driver dares, so following it is
##      braking on time: the car brakes where, braking that hard, it would
##      otherwise no longer make the next corner.
##
## The knobs are read once a step, through the three `*_now` functions, and
## what was read is kept in `used` -- recorded from inside the controller, so
## a knob changed where it is used cannot hide. Constant time a step, but
## for the braking point drawn on screen, which looks `BRAKING_REACH` ahead.
##
## When not to use it: racing in traffic. This driver sees no other car.
class_name RacingDriver
extends RefCounted

## How far ahead, in samples, the braking point is looked for (400 metres).
const BRAKING_REACH: int = 200

var level: RacingLevel
## The phases of the two slow waves the wander follows, drawn from the seed
## once: the same seed drifts the same way every race.
var drift_phases := PackedFloat64Array()

## What the last step decided, for the overlay and the tests.
var aim: Vector2 = Vector2.ZERO
var target_speed: float = 0.0
var wanted_turn: float = 0.0
## The first sample ahead that is slower than the car is now: where it must
## already be braking. -1 when none is within reach.
var braking_point: int = -1
## The three knobs as this step used them.
var used: Dictionary = {}
## The line sample this step decided at.
var decided_at: int = 0


func _init(driving_level: RacingLevel, seed_value: int) -> void:
	level = driving_level
	var dice := RandomNumberGenerator.new()
	dice.seed = seed_value
	drift_phases = PackedFloat64Array([dice.randf_range(0.0, TAU), dice.randf_range(0.0, TAU)])


## Decide this step's speed and turn for `car`, at sample `index` of
## `track`, `time` seconds into the race.
func decide(car: RacingCar, track: RacingTrack, index: int, time: float) -> void:
	decided_at = index
	used = {"lookahead": lookahead_now(), "grip_margin": grip_margin_now(), "wander": wander_now()}
	aim = track.point_ahead(index, used["lookahead"], used["wander"] * _drift(time))
	wanted_turn = pursuit_turn(car, aim)
	target_speed = speed_limit(track, index, car.physics, used["grip_margin"])
	braking_point = _braking_point(car, track, index, used["grip_margin"])


## The lookahead this step steers with. The level's, always.
func lookahead_now() -> float:
	return level.lookahead


## The grip margin this step brakes and corners with. The level's, always.
func grip_margin_now() -> float:
	return level.grip_margin


## The wander this step drifts with. The level's, always.
func wander_now() -> float:
	return level.wander


## The fastest this driver will be at sample `index`: the track's full-grip
## limit times sqrt(margin), and never above the car's top speed.
static func speed_limit(track: RacingTrack, index: int, physics: RacingPhysics, margin: float) -> float:
	return minf(physics.top_speed, track.full_grip_limit[index] * sqrt(margin))


## The turn rate that takes `car` towards `point`. Seek is asked one thing
## here, the velocity it wants -- full speed straight at the point -- and
## its force is how far that is from the car's velocity, so velocity plus
## force is that wish. (Its force limit is set to twice the top speed so the
## clamp never shortens it.) The car cannot simply take that velocity, it can
## only turn; pure pursuit says how hard: curvature 2 sin(angle) / distance,
## times speed for a turn rate. Static, so a driver written to cheat in
## the cheat check can steer with it as an honest one does.
static func pursuit_turn(car: RacingCar, point: Vector2) -> float:
	var mirror := SteeringVehicle.new(car.position, car.velocity(), car.physics.top_speed,
		2.0 * car.physics.top_speed)
	var desired: Vector2 = mirror.velocity + SeekBehaviour.new(point).force(mirror)
	var angle: float = Vector2.from_angle(car.heading).angle_to(desired)
	var distance: float = maxf(car.position.distance_to(point), 1.0)
	return car.speed * 2.0 * sin(angle) / distance


# Where along the line, from `index`, this driver's limit first falls below
# the car's speed. Kept at that speed the car would be too fast there, so it
# must be braking by then: that is the braking point a person can watch move.
func _braking_point(car: RacingCar, track: RacingTrack, index: int, margin: float) -> int:
	for ahead: int in range(BRAKING_REACH):
		var sample: int = track.wrapped(index + ahead)
		if speed_limit(track, sample, car.physics, margin) < car.speed:
			return sample
	return -1


# Between -1 and 1, slowly: two sine waves at unrelated rates, so the drift
# does not repeat on every lap.
func _drift(time: float) -> float:
	return (sin(0.43 * time + drift_phases[0]) + sin(1.13 * time + drift_phases[1])) / 2.0
