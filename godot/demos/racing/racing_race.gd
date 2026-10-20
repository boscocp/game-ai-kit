## A race: one track, one physics, and a car for each driver, stepped together.
##
## Every car is built here from the same `RacingPhysics` instance, at the same
## start, at rest -- so the one thing that can differ between two of them is
## who drives. The cars do not touch: each one drives through the others, as
## a ghost. Collisions and overtaking are a different lesson (T54's heat line).
##
## A step asks every driver to decide, then moves every car. Laps are counted
## by distance covered along the line: a car that cuts a corner across the
## grass is credited the line's metres, not the shorter ones it drove, and
## what keeps that from paying is the grass, which holds it to
## `off_track_speed`. Linear in the number of cars.
##
## When not to use it: a race where cars must react to each other.
class_name RacingRace
extends RefCounted

const DT: float = 1.0 / 60.0

var track: RacingTrack
var physics: RacingPhysics
var cars: Array[RacingCar] = []
var drivers: Array[RacingDriver] = []
## For each car: the line sample and the centre sample it was last nearest.
var line_index := PackedInt64Array()
var centre_index := PackedInt64Array()
## For each car: metres covered along the line since the start.
var covered := PackedFloat64Array()
## For each car: the time each finished lap ended, in seconds since the start.
var lap_ends: Array[PackedFloat64Array] = []
var time: float = 0.0
var steps: int = 0


func _init(race_physics: RacingPhysics) -> void:
	physics = race_physics
	track = RacingTrack.new(physics)


## Put a car on the start line for `driver`, and return its number.
func enter(driver: RacingDriver) -> int:
	var facing: float = track.direction_at(0).angle()
	cars.append(RacingCar.new(physics, track.line[0], facing))
	drivers.append(driver)
	line_index.append(0)
	centre_index.append(track.nearest_centre(track.line[0], 0))
	covered.append(0.0)
	lap_ends.append(PackedFloat64Array())
	return cars.size() - 1


## Every driver decides, then every car moves, `DT` seconds.
func step() -> void:
	for number: int in range(cars.size()):
		drivers[number].decide(cars[number], track, line_index[number], time)
	for number: int in range(cars.size()):
		_move(number)
	time += DT
	steps += 1


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


# One car's move, and the bookkeeping after it: where on the line it now is,
# how far along it that took it, and whether that finished a lap.
func _move(number: int) -> void:
	var car: RacingCar = cars[number]
	var driver: RacingDriver = drivers[number]
	car.step(driver.target_speed, driver.wanted_turn, on_track(number), DT)
	var before: int = line_index[number]
	var after: int = track.nearest(car.position, before)
	centre_index[number] = track.nearest_centre(car.position, centre_index[number])
	line_index[number] = after
	var moved: int = posmod(after - before + track.line.size() / 2, track.line.size()) - track.line.size() / 2
	covered[number] += moved * RacingTrack.SPACING
	if covered[number] >= (laps(number) + 1) * track.length:
		lap_ends[number].append(time + DT)
