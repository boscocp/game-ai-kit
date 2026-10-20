## A race: one track, one physics, and a car for each driver, stepped together.
##
## Every car is built here from the same `RacingPhysics` instance, at rest on
## a grid -- two abreast, the front row on the start line, each next row
## `GRID_GAP` metres behind --
## so the one thing that can differ between two of them is who drives.
##
## A step asks every driver to decide, then moves every car, then keeps them
## apart. Two cars closer than `CAR_RADIUS` twice over have collided: they
## are pushed apart along the line between their centres, and -- equal
## masses -- trade the part of their velocity along that line, less a share
## `RESTITUTION` leaves out. So a car run into from behind is pushed faster
## and the one that hit it slowed, a glancing touch costs both a little, and
## each is turned a little towards where the blow sent it. Crude on purpose,
## like the car, and the same for everybody: nothing here reads a driver's
## level. Every collision is kept in `bumps` for a moment, to be drawn.
## Before deciding, each driver is told how fast the nearest car ahead of
## it on its path is going and where it is, so it can follow it, and pass.
##
## Laps are counted by distance covered along the line: a car that cuts a
## corner across the grass is credited the line's metres, not the shorter
## ones it drove. The grass, which holds it to `off_track_speed`, makes that
## cost more than it gains for a corner; a long cut across the infield can
## still pay a little -- 145 metres of grass bought 0.4 s in a review's
## probe. A car pushed along the line by a bump is that much further round.
## Quadratic in the number of cars, at most four here.
##
## When not to use it: a race where cars must plan round each other. A car
## here sidesteps the one ahead; choosing where to pass is T54's heat line.
class_name RacingRace
extends RefCounted

const DT: float = 1.0 / 60.0
## Two cars closer than twice this, centre to centre, are touching. A car
## drawn five metres long is about this wide.
const CAR_RADIUS: float = 2.4
## Pushing one pair apart can push a car into a third; this many passes
## over the pairs settle three or four cars. Speed is traded on the first
## pass only: after it, a pair is left touching by rounding, not by moving.
const SEPARATIONS: int = 4
## How bouncy a collision is: 0 the two cars leave it at one speed along
## the line between them, 1 they swap their speeds along it whole.
const RESTITUTION: float = 0.4
## The share of the turn towards its new velocity a car takes in a
## collision: a nudge, not a spin.
const KNOCK: float = 0.3
## Seconds a collision stays in `bumps`, to be drawn.
const BUMP_SECONDS: float = 0.4
## Metres between two rows of the grid, and either side of the line.
const GRID_GAP: float = 10.0
const GRID_SIDE: float = 5.0
## How far ahead, and how far to either side of its path, a driver looks
## for a car to follow: at least as far as it needs to brake to the other's
## speed, plus this; as wide as two cars touch, so a car it would hit is
## always one it saw.
const FOLLOW_DISTANCE: float = 20.0
const FOLLOW_WIDTH: float = 2.0 * CAR_RADIUS + 0.5

var track: RacingTrack
var physics: RacingPhysics
var cars: Array[RacingCar] = []
var drivers: Array[RacingDriver] = []
## For each car: the line sample and the centre sample it was last nearest.
var line_index := PackedInt64Array()
var centre_index := PackedInt64Array()
## For each car: metres covered along the line since the start line. A car
## that starts behind the line starts below zero.
var covered := PackedFloat64Array()
## For each car: the time each finished lap ended, in seconds since the start.
var lap_ends: Array[PackedFloat64Array] = []
var time: float = 0.0
var steps: int = 0
## Each recent collision: [where, when]. Older than `BUMP_SECONDS` are let go.
var bumps: Array[Array] = []


func _init(race_physics: RacingPhysics) -> void:
	physics = race_physics
	track = RacingTrack.new(physics)


## Put a car for `driver` on the next place of the grid, and return its
## number. The first two share the front row, left and right of the line.
func enter(driver: RacingDriver) -> int:
	var behind: int = roundi(cars.size() / 2 * GRID_GAP / RacingTrack.SPACING)
	var sample: int = track.wrapped(-behind)
	var side: float = GRID_SIDE if cars.size() % 2 == 0 else -GRID_SIDE
	var at: Vector2 = track.line[sample] + track.direction_at(sample).rotated(-PI / 2.0) * side
	cars.append(RacingCar.new(physics, at, track.direction_at(sample).angle()))
	drivers.append(driver)
	line_index.append(sample)
	centre_index.append(track.nearest_centre(at, roundi(float(sample) * track.centre.size() / track.line.size())))
	covered.append(-behind * RacingTrack.SPACING)
	lap_ends.append(PackedFloat64Array())
	return cars.size() - 1


## Every driver decides, then every car moves `DT` seconds, then no two
## overlap.
func step() -> void:
	plan()
	for number: int in range(cars.size()):
		cars[number].step(drivers[number].target_speed, drivers[number].wanted_turn, on_track(number), DT)
		_locate(number)
	_keep_apart()
	time += DT
	steps += 1


## Every driver decides what it would do now, told how fast the car close
## ahead of it is going; nothing moves. A step begins with this, and a race
## not yet started can call it so its first decisions can be drawn.
func plan() -> void:
	for number: int in range(cars.size()):
		var ahead: int = car_ahead(number)
		drivers[number].traffic_speed = cars[ahead].speed if ahead >= 0 else INF
		drivers[number].traffic_left = _left_of(number, ahead) if ahead >= 0 else 0.0
		drivers[number].decide(cars[number], track, line_index[number], time)


## The slowest car close ahead of car `number` on its path -- near enough
## that, braking, it must start now -- or -1 when the way is clear.
func car_ahead(number: int) -> int:
	var car: RacingCar = cars[number]
	var forward: Vector2 = Vector2.from_angle(car.heading)
	var slowest: int = -1
	for other: int in range(cars.size()):
		var offset: Vector2 = cars[other].position - car.position
		var along: float = offset.dot(forward)
		var reach: float = _braking_distance(car.speed, cars[other].speed) + FOLLOW_DISTANCE
		var in_path: bool = along > 0.0 and along < reach and absf(offset.cross(forward)) < FOLLOW_WIDTH
		if other != number and in_path and (slowest < 0 or cars[other].speed < cars[slowest].speed):
			slowest = other
	return slowest


## Laps car `number` has finished.
func laps(number: int) -> int:
	return lap_ends[number].size()


## How long car `number`'s lap `lap` took, in seconds (the first counts from
## the standing start).
func lap_time(number: int, lap: int) -> float:
	var started: float = 0.0 if lap == 0 else lap_ends[number][lap - 1]
	return lap_ends[number][lap] - started


## True when car `number` is on the tarmac.
func on_track(number: int) -> bool:
	return track.on_track(cars[number].position, centre_index[number])


# Where car `number` is on the line now, how far along it that took it, and
# whether that finished a lap.
func _locate(number: int) -> void:
	var before: int = line_index[number]
	var after: int = track.nearest(cars[number].position, before)
	centre_index[number] = track.nearest_centre(cars[number].position, centre_index[number])
	line_index[number] = after
	var half: int = track.line.size() / 2
	covered[number] += (posmod(after - before + half, track.line.size()) - half) * RacingTrack.SPACING
	if covered[number] >= (laps(number) + 1) * track.length:
		lap_ends[number].append(time + DT)


# Every pair of cars that overlaps, pushed apart, a few times over.
func _keep_apart() -> void:
	bumps = bumps.filter(func(bump: Array) -> bool: return time - bump[1] < BUMP_SECONDS)
	for separation: int in range(SEPARATIONS):
		for first: int in range(cars.size()):
			_bump_those_after(first, separation == 0)


func _bump_those_after(first: int, collide: bool) -> void:
	for second: int in range(first + 1, cars.size()):
		_bump(first, second, collide)


# Two cars that overlap, pushed apart: half the overlap each, along the line
# between their centres. On the first pass they also collide.
func _bump(first: int, second: int, collide: bool) -> void:
	var offset: Vector2 = cars[second].position - cars[first].position
	var overlap: float = 2.0 * CAR_RADIUS - offset.length()
	if overlap <= 0.0:
		return
	var apart: Vector2 = offset.normalized() if offset != Vector2.ZERO else Vector2.from_angle(cars[first].heading + PI / 2.0)
	cars[first].position -= apart * overlap / 2.0
	cars[second].position += apart * overlap / 2.0
	if collide:
		_collide(cars[first], cars[second], apart)
	_locate(first)
	_locate(second)


# Equal masses: the velocity each has along `apart` (from `first` to
# `second`) is traded, less what restitution keeps out, when they are
# closing. Each car then goes the way its new velocity points, as far as a
# car can: its speed becomes the new velocity along its heading, and its
# heading turns `KNOCK` of the way towards it.
func _collide(first: RacingCar, second: RacingCar, apart: Vector2) -> void:
	var closing: float = first.velocity().dot(apart) - second.velocity().dot(apart)
	if closing <= 0.0:
		return
	var blow: Vector2 = apart * closing * (1.0 + RESTITUTION) / 2.0
	_knock(first, first.velocity() - blow)
	_knock(second, second.velocity() + blow)
	bumps.append([(first.position + second.position) / 2.0, time])


func _knock(car: RacingCar, velocity: Vector2) -> void:
	if velocity.length() > 0.01:
		car.heading += Vector2.from_angle(car.heading).angle_to(velocity) * KNOCK
	car.speed = clampf(velocity.dot(Vector2.from_angle(car.heading)), 0.0, car.physics.top_speed)


# How far a car at `speed` needs to brake down to `other_speed`.
func _braking_distance(speed: float, other_speed: float) -> float:
	if speed <= other_speed:
		return 0.0
	return (speed * speed - other_speed * other_speed) / (2.0 * physics.braking)


# How far to the left of car `number`'s path car `other` is, in metres.
func _left_of(number: int, other: int) -> float:
	var forward: Vector2 = Vector2.from_angle(cars[number].heading)
	return (cars[other].position - cars[number].position).dot(forward.rotated(-PI / 2.0))
