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
## One rule more, the same at every level and no knob: passing. The race
## tells the driver how fast the car close ahead on its path is going, and
## how far to the side of it that car is (`traffic_speed`, `traffic_left`).
## A driver held below the speed it wants starts a pass: it picks a side
## once -- away from the other car, unless that side has no room -- aims
## `PASS_OFFSET` metres that way, and may go `PASS_GAIN` faster than the car
## it passes, so it draws level. It keeps that side until the way has been
## clear for `CLEAR_STEPS`, so it does not swerve back into the car it just
## passed. A manoeuvre, not a plan: T54's heat line is how shipped games
## choose where to pass.
##
## The knobs are read once a step, through the three `*_now` functions, and
## what was read is kept in `used` -- recorded from inside the controller, so
## a knob changed where it is used cannot hide. Constant time a step, but
## for the braking point drawn on screen, which looks `BRAKING_REACH` ahead.
##
## When not to use it: racing wheel to wheel. This driver passes the car
## ahead of it; it does not defend, block, or pick a moment.
##
## Unlike the knobs, a pass is state kept from step to step. It is the same
## at every level; `racing_does_not_cheat.gd`'s twin keeps it the same way.
class_name RacingDriver
extends RefCounted

## How far ahead, in samples, the braking point is looked for (400 metres).
const BRAKING_REACH: int = 200
## Metres to the side of the line a driver aims while passing: more than a
## car's width, so it clears the one it passes.
const PASS_OFFSET: float = 6.0
## Metres from the edge of the tarmac a passing driver keeps.
const PASS_MARGIN: float = 2.5
## Metres a second faster than the car it passes a passing driver may go:
## matched to it, it would sit beside it for ever.
const PASS_GAIN: float = 5.0
## Steps the way must be clear before a pass is over (a second and a half).
const CLEAR_STEPS: int = 90
## The slowest a car is taken to be when working out its turn: at a crawl
## its wheels still turn, and a car stopped nose to tail must be able to
## steer out.
const CRAWL: float = 4.0

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
## The speed of the car close ahead on this driver's path, and how far to
## the left of this one it is (negative: right), set by the race before
## each decision; infinity and zero when the way is clear.
var traffic_speed: float = INF
var traffic_left: float = 0.0
## The side of a pass under way: 1 left, -1 right, 0 none; and the steps the
## way has been clear since.
var passing_side: int = 0
var clear_steps: int = 0
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
	var wish: float = speed_limit(track, index, car.physics, used["grip_margin"])
	_keep_passing(wish, track, index)
	var ahead_index: int = track.wrapped(index + roundi(used["lookahead"] / RacingTrack.SPACING))
	var wandered: float = used["wander"] * _drift(time)
	aim = track.point_ahead(index, used["lookahead"], wandered + _passing_offset(track, ahead_index, wandered))
	wanted_turn = pursuit_turn(car, aim)
	target_speed = minf(wish, _traffic_limit())
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
	return maxf(car.speed, CRAWL) * 2.0 * sin(angle) / distance


# A pass starts when the car ahead holds this one below `wish`, and ends
# once the way has been clear for `CLEAR_STEPS`. Its side is chosen once.
func _keep_passing(wish: float, track: RacingTrack, index: int) -> void:
	if traffic_speed < wish:
		clear_steps = 0
		if passing_side == 0:
			passing_side = _pass_side(track, index)
		return
	clear_steps += 1
	if clear_steps >= CLEAR_STEPS:
		passing_side = 0


# Away from the car ahead; to the roomier side of the track when it is dead
# ahead, or when the side away from it has less than a car's width of
# tarmac beside the line.
func _pass_side(track: RacingTrack, index: int) -> int:
	var room_left: float = RacingTrack.HALF_WIDTH - track.line_sideways[index] - PASS_MARGIN
	var room_right: float = RacingTrack.HALF_WIDTH + track.line_sideways[index] - PASS_MARGIN
	var roomier: int = 1 if room_left >= room_right else -1
	if absf(traffic_left) < 0.5:
		return roomier
	var away: int = -1 if traffic_left > 0.0 else 1
	return away if (room_left if away == 1 else room_right) >= 2.0 * RacingRace.CAR_RADIUS else -away


# Metres to the side of the line to aim during a pass, held on the tarmac
# at the point aimed at: `wandered` is already added to it.
func _passing_offset(track: RacingTrack, ahead_index: int, wandered: float) -> float:
	if passing_side == 0:
		return 0.0
	var edge: float = RacingTrack.HALF_WIDTH - PASS_MARGIN
	var at: float = track.line_sideways[ahead_index] + wandered
	return clampf(at + passing_side * PASS_OFFSET, -edge, edge) - at


# The fastest the traffic lets this driver go: the car ahead's speed, or a
# little more while passing it.
func _traffic_limit() -> float:
	if traffic_speed == INF:
		return INF
	return traffic_speed + (PASS_GAIN if passing_side != 0 else 0.0)


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
