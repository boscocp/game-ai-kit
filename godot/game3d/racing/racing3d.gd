## The 3D racer (T54): you and the three levels, in the same car, on a road
## whose line the drivers find for themselves.
##
## Before the start every car is measured on the test pad -- the camera
## watches yours, the red one -- and each driver keeps what its own car
## did. Then the grid, and only then do the keys drive: for about twenty
## seconds they do nothing, and the status panel says so.
## The overlay (`RaceOverlay3D`) puts every decision on the road, the map
## shows the race from above, and the trace under it is the watched car's
## distance off where it wants to be.
##
## Keys: arrows or WASD drive; 1 the PID (full, or proportional only), 2
## the heat line (or one rival at a time), 3 the grip (measured, or off the
## sheet); Tab watches the next car, C the camera, T the other track, R
## starts again, Space pauses.
##
## When not to use it: as a check. Every claim about the race is held by a
## headless script in `test/racing3d/`; this is where a person watches.
extends Node3D

const TRACKS: Array[String] = [
	"res://game3d/racing/tracks/the_loop.json",
	"res://game3d/racing/tracks/the_kidney.json",
]
## The model and the colour of each car: the three levels, then you.
const MODELS: Array[String] = ["racer_green", "racer_orange", "racer_white", "racer_red"]
const COLOURS: Array[Color] = [Color(0.3, 0.8, 0.35), Color(1.0, 0.6, 0.15), Color(0.9, 0.9, 0.95), Color(0.9, 0.2, 0.2)]
const MODEL_HEIGHT: float = 1.25
const CHASE_BEHIND: float = 10.0
const CHASE_ABOVE: float = 3.5

var race: Race3D = null
var human: RaceHumanDriver3D = null
var watched: int = 0
var track_index: int = 0
var chase: bool = true
var full_pid: bool = true
var heat_vision: bool = true
var measured_grip: bool = true
## Which shelf the models come from; a test sets one with nothing on it.
var shelf: AssetShelf = AssetShelf.new()
var _overlay := RaceOverlay3D.new()

@onready var _legend: Legend = $Interface/Legend
@onready var _status: Label = $Interface/Status
@onready var _map: RaceMap3D = $Interface/Map
@onready var _trace: RaceTrace3D = $Interface/Trace
@onready var _camera: Camera3D = $Camera


func _ready() -> void:
	_legend.set_entries([
		[RaceScenery3D.LINE_COLOUR, "the racing line each driver found"],
		[RaceOverlay3D.AIM_COLOUR, "white post: its aim; white bar: its braking point"],
		[RaceOverlay3D.GRIP_SPARE, "tyre with grip to spare"],
		[RaceOverlay3D.GRIP_NEAR, "tyre near its grip"],
		[RaceOverlay3D.SLIDING, "tyre past its peak slip: sliding"],
		[RaceOverlay3D.COOL, "heat line, cool to hot, of the watched car"],
		[RaceOverlay3D.BALL_COLOUR, "the ball: where that car means to be"],
	])
	add_child(_overlay)
	restart()


## A new race on the current track: measuring first, then the grid.
func restart() -> void:
	if race != null:
		race.queue_free()
	race = Race3D.new(RaceTrack3D.from_file(TRACKS[track_index]), CarPhysics3D.new(), false, shelf)
	race.measured_grip = measured_grip
	# This scene keeps listening while paused; the race must not.
	race.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(race)
	for level: RaceLevel3D in RaceLevel3D.ladder():
		var driver := RaceDriver3D.new(level, Race3D.sheet_of(race.physics))
		driver.drift_from(race.cars.size() + 1)
		_enter(driver)
	human = RaceHumanDriver3D.new(Race3D.sheet_of(race.physics))
	_enter(human)
	_apply_switches()
	_map.race = race
	_map.colours = COLOURS
	# Your car, not the first AI's: watching another car while the keys
	# drive yours reads as keys that do nothing (the owner, 2026-10-22).
	watched = race.drivers.find(human)


## One decision: every driver shown what it sees now, nothing moved.
func step_decision() -> void:
	race.decide_now()
	_refresh()


## What each AI driver is deciding with, for `test/menu/demo_overlays.gd`:
## its speed and the one it wants, how far ahead it must brake, where it
## means to be across the road and where the heat line's ball is, the
## PID's three terms, its tyres' slip, and what it measured of its car.
func decision_overlay() -> Dictionary:
	var shown: Array[Dictionary] = []
	for number: int in range(race.cars.size()):
		if race.drivers[number] != human:
			shown.append(_driver_overlay(number))
	return {"time": race.time, "measuring": not race.racing, "cars": shown,
		"switches": {"full_pid": full_pid, "heat_vision": heat_vision, "measured_grip": measured_grip}}


func _driver_overlay(number: int) -> Dictionary:
	var driver: RaceDriver3D = race.drivers[number]
	var car: RaceCar3D = race.cars[number]
	return {
		"level": driver.level.title, "speed": car.forward_speed(), "target_speed": driver.target_speed,
		"braking_in": driver.braking_in, "wanted_left": driver.wanted_left, "heat_ball": driver.traffic.heat.ball,
		"pid": [driver.line_pid.proportional_term, driver.line_pid.integral_term, driver.line_pid.derivative_term],
		"slip": Array(car.wheel_slip), "grip": driver.grip, "braking": driver.braking,
		"measured": [race.tests[number].grip, race.tests[number].braking],
	}


func _enter(driver: RaceDriver3D) -> void:
	var number: int = race.enter(driver)
	var model: Node3D = shelf.model(MODELS[number], MODEL_HEIGHT, COLOURS[number])
	var holder := Node3D.new()
	holder.add_child(model)
	var bounds: AABB = AssetShelf.bounds_of(model)
	model.position = -Vector3(bounds.get_center().x, 0.0, bounds.get_center().z)
	# Kenney's cars face +z, Godot's -z; a primitive is the same either way.
	holder.rotation.y = PI if shelf.has_model(MODELS[number]) else 0.0
	holder.position.y = -race.cars[number].ride_height()
	race.cars[number].add_child(holder)


func _apply_switches() -> void:
	race.measured_grip = measured_grip
	race.keep_measurements()
	for driver: RaceDriver3D in race.drivers:
		driver.full_pid = full_pid
		driver.traffic.heat_vision = heat_vision


func _physics_process(_delta: float) -> void:
	if human == null:
		return
	var right: bool = Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)
	var left: bool = Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A)
	human.held_steer = (1.0 if left else 0.0) - (1.0 if right else 0.0)
	human.held_throttle = Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W)
	human.held_brake = Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S)


func _process(_delta: float) -> void:
	_refresh()
	_follow_with_camera()


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1:
			full_pid = not full_pid
		KEY_2:
			heat_vision = not heat_vision
		KEY_3:
			measured_grip = not measured_grip
		KEY_TAB:
			watched = (watched + 1) % race.cars.size()
		KEY_C:
			chase = not chase
		KEY_T:
			track_index = (track_index + 1) % TRACKS.size()
			restart()
		KEY_R:
			restart()
		KEY_SPACE:
			get_tree().paused = not get_tree().paused
	_apply_switches()


func _refresh() -> void:
	_overlay.draw(race, watched)
	_map.watched = watched
	_map.queue_redraw()
	if race.racing:
		_trace.push(race.drivers[watched].line_error)
	_status.text = Racing3DText.status(race, watched, human, [full_pid, heat_vision, measured_grip])


# Behind the watched car, looking past it -- on the pad too, while it is
# measured -- or high over the car, looking down.
func _follow_with_camera() -> void:
	var car: RaceCar3D = race.cars[watched]
	var ahead: Vector3 = -car.global_transform.basis.z * Vector3(1, 0, 1)
	var wanted: Vector3 = car.global_position - ahead.normalized() * CHASE_BEHIND + Vector3.UP * CHASE_ABOVE
	if not chase:
		wanted = car.global_position + Vector3(0.0, 60.0, 0.1)
	var target: Vector3 = car.global_position + ahead * 6.0
	_camera.global_position = _camera.global_position.lerp(wanted, 0.15)
	if not _camera.global_position.is_equal_approx(target):
		_camera.look_at(target, Vector3.UP)

