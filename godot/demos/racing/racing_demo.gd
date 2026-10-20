## Three drivers, one car: the racing demo, and three difficulties that do
## not cheat.
##
## T23's demo. Easy, normal and hard race the same car on the same track,
## through each other as ghosts. One of them is followed, and what it is
## deciding is drawn: the point it steers at down the line, the line
## coloured by the speed it allows itself, and a bar across the track where
## it must already be braking. 1-3 follow another level, A shows the
## followed car alone, space pauses, the full stop steps one sixtieth of a
## second, R starts the race again.
##
## What to watch is where the hard car brakes and how early it turns in: its
## bar sits closer to each corner than easy's, and its line is greener
## through it. It is never faster down a straight -- the same top speed is
## the same for everybody -- and if it ever is, the cheat check has a hole.
class_name RacingDemo
extends Node2D

## Pixels a metre, and where the track's corner sits on the screen.
const SCALE: float = 2.0
const ORIGIN := Vector2(24.0, 56.0)
const COLOURS: Array[Color] = [Color(0.6, 0.5, 1.0), Color(1.0, 0.85, 0.2), Color(1.0, 0.45, 0.8)]
const AIM_COLOUR := Color(1.0, 1.0, 1.0)
const BRAKING_COLOUR := Color(0.3, 0.95, 1.0)
## Cars are drawn larger than a car, in metres, so they can be seen at all.
const CAR_LENGTH: float = 6.0
const CAR_WIDTH: float = 3.6
## Each car's wander follows the same seed, so a restart races the same race.
const SEED: int = 23

@onready var _status: Label = $Interface/Status
@onready var _legend: Legend = $Interface/Legend

var levels: Array[RacingLevel] = RacingLevel.ladder()
var race: RacingRace
var track_view: RacingTrackView
## The car whose decisions are drawn, and whether it is drawn alone.
var followed: int = 2
var alone: bool = false
var paused: bool = false


func _ready() -> void:
	restart()
	_legend.set_entries([
		[COLOURS[0], "easy"], [COLOURS[1], "normal"], [COLOURS[2], "hard"],
		[AIM_COLOUR, "the point it steers at"],
		[BRAKING_COLOUR, "bar: where it must be braking"],
		[RacingTrackView.SLOW, "line: slow here, for this driver"],
		[RacingTrackView.FAST, "line: top speed is the only limit"],
	] as Array[Array])


func _physics_process(_delta: float) -> void:
	if not paused:
		step_decision()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.is_pressed() or key.echo:
		return
	match key.keycode:
		KEY_1, KEY_2, KEY_3:
			followed = key.keycode - KEY_1
			track_view.show_level(levels[followed])
		KEY_A:
			alone = not alone
		KEY_SPACE:
			paused = not paused
		KEY_PERIOD:
			paused = true
			step_decision()
		KEY_R:
			restart()
	_refresh()


## Every driver decides once, and every car moves one sixtieth of a second.
func step_decision() -> void:
	race.step()
	queue_redraw()
	if race.steps % 10 == 0:
		_refresh()


## What each driver is deciding with, for `test/menu/demo_overlays.gd`: the
## point it steers at, the speed it chose and the one it is doing, how far
## ahead it must be braking, and the knobs it used.
func decision_overlay() -> Dictionary:
	var shown: Array[Dictionary] = []
	for number: int in range(race.cars.size()):
		var driver: RacingDriver = race.drivers[number]
		shown.append({"level": driver.level.title, "aim": [driver.aim.x, driver.aim.y],
			"target_speed": driver.target_speed, "speed": race.cars[number].speed,
			"braking_in": _braking_distance(number), "lap": race.laps(number), "used": driver.used})
	return {"step": race.steps, "followed": levels[followed].title, "cars": shown}


## The race from its start: the three cars at rest on the line.
func restart() -> void:
	race = RacingRace.new(RacingPhysics.new())
	for level: RacingLevel in levels:
		race.enter(RacingDriver.new(level, SEED))
	if track_view != null:
		track_view.queue_free()
	track_view = RacingTrackView.new(race, levels[followed])
	track_view.position = ORIGIN
	track_view.scale = Vector2(SCALE, SCALE)
	track_view.show_behind_parent = true
	add_child(track_view)
	queue_redraw()
	if is_node_ready():
		_refresh()


func _draw() -> void:
	draw_set_transform(ORIGIN, 0.0, Vector2(SCALE, SCALE))
	_draw_decision(followed)
	for number: int in range(race.cars.size()):
		if number == followed or not alone:
			_draw_car(number)
	draw_arc(race.cars[followed].position, CAR_LENGTH, 0.0, TAU, 24, COLOURS[followed], 0.6)


# What the followed driver reasons with: a bar across the track where it must
# be braking, and a line from the car to the point it steers at.
func _draw_decision(number: int) -> void:
	var driver: RacingDriver = race.drivers[number]
	var car: RacingCar = race.cars[number]
	if driver.braking_point >= 0:
		var across: Vector2 = race.track.direction_at(driver.braking_point).rotated(PI / 2.0) * 5.0
		var at: Vector2 = race.track.line[driver.braking_point]
		draw_line(at - across, at + across, BRAKING_COLOUR, 2.0)
	draw_line(car.position, driver.aim, AIM_COLOUR, 0.6)
	draw_circle(driver.aim, 1.5, AIM_COLOUR)


func _draw_car(number: int) -> void:
	var car: RacingCar = race.cars[number]
	var ahead: Vector2 = Vector2.from_angle(car.heading)
	var side := Vector2(-ahead.y, ahead.x)
	var nose: Vector2 = car.position + ahead * CAR_LENGTH * 0.6
	var tail: Vector2 = car.position - ahead * CAR_LENGTH * 0.4
	draw_colored_polygon(PackedVector2Array([nose, tail + side * CAR_WIDTH / 2.0, tail - side * CAR_WIDTH / 2.0]),
		COLOURS[number])


# Metres along the line to where car `number` must already be braking; the
# whole reach when nothing ahead is slower than it is.
func _braking_distance(number: int) -> float:
	var driver: RacingDriver = race.drivers[number]
	if driver.braking_point < 0:
		return RacingDriver.BRAKING_REACH * RacingTrack.SPACING
	var samples: int = posmod(driver.braking_point - driver.decided_at, race.track.line.size())
	return samples * RacingTrack.SPACING


func _refresh() -> void:
	var lines: Array[String] = ["%.1f s%s  ·  1-3 follow  ·  A alone  ·  space pause  ·  . one step  ·  R again" % [
		race.time, "  (paused)" if paused else ""]]
	for number: int in range(race.cars.size()):
		lines.append(_car_line(number))
	lines.append("\nThe cars drive through each other: one physics, three drivers.")
	_status.text = "\n".join(lines)


func _car_line(number: int) -> String:
	var driver: RacingDriver = race.drivers[number]
	var car: RacingCar = race.cars[number]
	var last: String = "%.2f s" % race.lap_time(number, race.laps(number) - 1) if race.laps(number) > 0 else "--"
	var braking: float = _braking_distance(number)
	return "%s%s: lap %d, last %s\n  %.0f m/s, wants %.0f, %s" % [
		"> " if number == followed else "", driver.level.title, race.laps(number) + 1, last, car.speed,
		driver.target_speed, "braking" if braking == 0.0 else "brakes in %.0f m" % braking]
