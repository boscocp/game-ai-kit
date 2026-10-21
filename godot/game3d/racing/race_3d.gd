## A race: one track, one physics, and a car for each driver.
##
## Every car is built here from the same `CarPhysics3D` instance, so the
## one thing that can differ between two of them is who drives. A race has
## two parts:
##
##   1. **Measuring.** Every car is driven through `GripTest3D` on a test pad
##      of the same tarmac, far from the track, all from one spot and
##      through each other. Each driver keeps what its own car measured -- or, with
##      `measured_grip` off, the numbers off the car's sheet instead, which
##      is the toggle that shows why it measures.
##   2. **Racing.** The cars are put on the grid at rest, and on every
##      physics frame each driver is shown its `RaceView3D` and sets its
##      car's controls; the physics step then moves every car.
##
## Laps are counted by distance along the track's samples, as T23 does, so
## a car that cuts across the grass is credited the track's metres, not the
## shorter ones it drove. A race of `ghosts` puts every car in the same
## place on the grid and lets them drive through each other: the ladder's
## cars each race alone, together. Linear in the cars a frame, but for the
## views, which see every other car: quadratic, and there are a handful.
##
## When not to use it: a race that must replay on another machine. Jolt
## replays a run only on the same binary (T50).
class_name Race3D
extends Node3D

## The test pad: where on the map and how big. Every car starts its test
## on the same spot, through the others: measured, cars tested 200 m apart
## measured grips that differed by about 2e-6 m/s^2 (single-precision
## positions further from the origin), and a test should not depend on
## which car was entered first.
const PAD_CENTRE: Vector2 = Vector2(-2500.0, 0.0)
const PAD_SIZE: float = 1000.0
## Metres between two rows of the grid, and either side of the line.
const GRID_GAP: float = 10.0
const GRID_SIDE: float = 2.5
const GRAVITY: float = 9.8

var track: RaceTrack3D
var physics: CarPhysics3D
var ghosts: bool = false
## Whether drivers race on what they measured, or on their car's sheet.
var measured_grip: bool = true
var cars: Array[RaceCar3D] = []
var drivers: Array[RaceDriver3D] = []
var tests: Array[GripTest3D] = []
## For each car: the track sample it was last nearest, the metres it has
## covered along the track since the start line (below zero behind it),
## when each of its laps ended, and the last view its driver was shown.
var samples := PackedInt64Array()
var covered := PackedFloat64Array()
var lap_ends: Array[PackedFloat64Array] = []
var views: Array[RaceView3D] = []
## Seconds and physics frames since the start; zero while measuring.
var time: float = 0.0
var frames: int = 0
var racing: bool = false
var _drawn: bool = false
var _shelf: AssetShelf = null


## A race on `race_track` for cars of `race_physics`. `drawn_with` is the
## shelf the scenery comes from, or null for a race nobody watches.
func _init(race_track: RaceTrack3D, race_physics: CarPhysics3D, as_ghosts: bool, drawn_with: AssetShelf = null) -> void:
	track = race_track
	physics = race_physics
	ghosts = as_ghosts
	_shelf = drawn_with
	_drawn = drawn_with != null
	name = "Race"


func _ready() -> void:
	if _drawn:
		RaceScenery3D.build(track, _shelf, self)
	else:
		add_child(RaceGround3D.grass(false))
		add_child(RaceGround3D.road(track, false))
	add_child(RaceGround3D.pad(PAD_SIZE, PAD_CENTRE, _drawn))


## What a driver of this race knows of its car before measuring it: the
## sheet's top speed, wheelbase and steering, and the grip, braking and
## steering past the arc the sheet promises -- the tyres' grip times
## gravity, the brakes' force over the mass, the tyres' peak slip.
static func sheet_of(car_physics: CarPhysics3D) -> Dictionary:
	return {
		"top_speed": car_physics.top_speed, "wheelbase": car_physics.wheelbase,
		"max_steer": car_physics.max_steer, "grip": car_physics.tyre_grip * GRAVITY,
		"braking": car_physics.brake_force / car_physics.mass, "slip_steer": car_physics.peak_slip,
	}


## A car for `driver`, on the test pad. Returns its number.
func enter(driver: RaceDriver3D) -> int:
	var number: int = cars.size()
	var car := RaceCar3D.new(physics, true)
	car.name = "Car%d" % number
	car.position = Vector3(PAD_CENTRE.x, car.ride_height(), PAD_CENTRE.y + PAD_SIZE * 0.4)
	add_child(car)
	cars.append(car)
	drivers.append(driver)
	tests.append(GripTest3D.new())
	samples.append(0)
	covered.append(0.0)
	lap_ends.append(PackedFloat64Array())
	views.append(null)
	return number


## Laps car `number` has finished.
func laps(number: int) -> int:
	return lap_ends[number].size()


## How long car `number`'s lap `lap` took, in seconds; the first counts
## from the standing start.
func lap_time(number: int, lap: int) -> float:
	var started: float = 0.0 if lap == 0 else lap_ends[number][lap - 1]
	return lap_ends[number][lap] - started


func _physics_process(delta: float) -> void:
	if not racing:
		_measure(delta)
		return
	for number: int in range(cars.size()):
		_locate(number)
	decide_now(delta)
	for number: int in range(cars.size()):
		_drive(cars[number], drivers[number])
	time += delta
	frames += 1


## Every driver is shown what it sees now and decides, for a decision
## `step` seconds long; nothing moves. A frame of the race begins with this,
## and a scene can call it to show a decision while the race is paused or
## still measuring.
func decide_now(step: float = 1.0 / 60.0) -> void:
	for number: int in range(cars.size()):
		views[number] = RaceSenses3D.view_of(track, cars, samples, number, time, step, not ghosts)
		drivers[number].decide(views[number])


## Every driver takes the grip and braking again: what its car measured,
## or its sheet's when `measured_grip` is off. The toggle a player presses.
func keep_measurements() -> void:
	for number: int in range(cars.size()):
		if tests[number].done():
			_keep_measurement(number)


# One frame of every car's test; once all are done, the drivers keep what
# they measured and the cars go to the grid.
func _measure(delta: float) -> void:
	var all_done: bool = true
	for number: int in range(cars.size()):
		tests[number].step(cars[number], delta)
		all_done = all_done and tests[number].done()
	if all_done and not cars.is_empty():
		for number: int in range(cars.size()):
			_keep_measurement(number)
			_to_grid(number)
		racing = true


func _keep_measurement(number: int) -> void:
	var sheet: Dictionary = sheet_of(physics)
	drivers[number].grip = tests[number].grip if measured_grip else float(sheet["grip"])
	drivers[number].braking = tests[number].braking if measured_grip else float(sheet["braking"])
	drivers[number].slip_steer = tests[number].slip_steer if measured_grip else float(sheet["slip_steer"])


# A car at rest on its place on the grid, told to the physics server
# directly: a body moved through its node is in the physics space a frame
# late (T50).
func _to_grid(number: int) -> void:
	var row: int = 0 if ghosts else number / 2
	var side: float = 0.0 if ghosts else (GRID_SIDE if number % 2 == 0 else -GRID_SIDE)
	var sample: int = track.wrapped(-roundi(row * GRID_GAP / RaceTrack3D.SPACING) - 1)
	var along: Vector2 = track.centre[sample].direction_to(track.centre[track.wrapped(sample + 1)])
	var at: Vector2 = track.line[sample] + track.left[sample] * side
	var basis := Basis(Vector3.UP, atan2(-along.x, -along.y))
	var place := Transform3D(basis, Vector3(at.x, cars[number].ride_height(), at.y))
	var body: RID = cars[number].get_rid()
	PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_TRANSFORM, place)
	PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
	PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
	cars[number].global_transform = place
	cars[number].collision_mask = RaceCar3D.GROUND_LAYER if ghosts else RaceCar3D.GROUND_LAYER | RaceCar3D.CAR_LAYER
	_drive(cars[number], null)
	samples[number] = sample
	covered[number] = -(track.centre.size() - sample) * RaceTrack3D.SPACING


func _drive(car: RaceCar3D, driver: RaceDriver3D) -> void:
	car.steer_wanted = driver.steer if driver != null else 0.0
	car.throttle = driver.throttle if driver != null else 0.0
	car.brake = driver.brake if driver != null else 0.0


# Where car `number` is along the track now, how far that took it, and
# whether it finished a lap.
func _locate(number: int) -> void:
	var before: int = samples[number]
	var after: int = track.nearest(RaceSenses3D.on_map(cars[number]), before)
	samples[number] = after
	var half: int = track.centre.size() / 2
	covered[number] += (posmod(after - before + half, track.centre.size()) - half) * RaceTrack3D.SPACING
	if covered[number] >= (laps(number) + 1) * track.length:
		lap_ends[number].append(time)
