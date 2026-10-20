## The cars, what they are doing, and what one AI driver is deciding, drawn
## above the track.
##
## Each car is a Kenney Racing Pack car (CC0), drawn `CAR_LENGTH` metres long
## and turned to its heading, its brake lights lit while it asks for less
## speed than it has. Tyre marks are left where a car brakes hard or turns
## at its grip's limit, and fade; a collision flashes where it happened. The
## followed AI's decision is drawn on top, each mark outlined so it reads on
## tarmac and grass alike: a white dot where it steers, a line to it, and a
## white bar where it must already be braking. Your own braking point is a
## yellow bar. In metres, redrawn every step.
class_name RacingRaceView
extends Node2D

## Metres long a car is drawn. Its picture is 71 by 131 pixels, nose up.
const CAR_LENGTH: float = 5.2
const MARK := Color(1.0, 1.0, 1.0)
const YOURS := Color(1.0, 0.85, 0.1)
const OUTLINE := Color(0.05, 0.05, 0.08)
const BRAKE_LIGHT := Color(1.0, 0.1, 0.05)
const TYRE_MARK := Color(0.15, 0.15, 0.17, 0.55)
const FLASH := Color(1.0, 0.95, 0.6)
## How many tyre marks are kept, all cars together; the oldest go first.
const MARKS_KEPT: int = 600
## A car asking for this many metres a second less than it has is braking
## hard and marks the road; a turn this close to the grip's limit does too.
const HARD_BRAKING: float = 3.0
const AT_THE_LIMIT: float = 0.95

var race: RacingRace
## The picture each car is drawn with, by car number.
var pictures: Array[String] = []
## The AI car whose decision is drawn, and your car; -1 for none.
var followed: int = -1
var you: int = -1
## The cars drawn; the others are left out (T23's "alone").
var shown: Array[bool] = []
## Each tyre mark: where its two ends are.
var marks: Array[PackedVector2Array] = []


func _init(shown_race: RacingRace, car_pictures: Array[String]) -> void:
	race = shown_race
	pictures = car_pictures
	for _car: RacingCar in race.cars:
		shown.append(true)


## Lay tyre marks for every car that is braking hard or at its grip's limit
## on the step just taken. Called once a step, by the demo.
func remember_marks() -> void:
	for number: int in range(race.cars.size()):
		var car: RacingCar = race.cars[number]
		var hard: bool = race.drivers[number].target_speed < car.speed - HARD_BRAKING
		if hard or car.sideways_acceleration() > AT_THE_LIMIT * car.physics.grip:
			var back: Vector2 = car.position - Vector2.from_angle(car.heading) * CAR_LENGTH * 0.35
			var across: Vector2 = Vector2.from_angle(car.heading).rotated(PI / 2.0) * 1.0
			marks.append(PackedVector2Array([back - across, back + across]))
	if marks.size() > MARKS_KEPT:
		marks = marks.slice(marks.size() - MARKS_KEPT)


## True while car `number`'s driver asks for less speed than it has: its
## brake lights are on.
func braking(number: int) -> bool:
	return race.drivers[number].target_speed < race.cars[number].speed - 0.5


func _draw() -> void:
	for mark: PackedVector2Array in marks:
		draw_circle(mark[0], 0.35, TYRE_MARK)
		draw_circle(mark[1], 0.35, TYRE_MARK)
	if you >= 0:
		_draw_bar(race.drivers[you].braking_point, YOURS)
	if followed >= 0:
		_draw_decision(race.drivers[followed], race.cars[followed])
	for number: int in range(race.cars.size()):
		if shown[number]:
			_draw_car(race.cars[number], pictures[number], braking(number))
	for bump: Array in race.bumps:
		var age: float = (race.time - bump[1]) / RacingRace.BUMP_SECONDS
		draw_arc(bump[0], 2.0 + 6.0 * age, 0.0, TAU, 24, Color(FLASH, 1.0 - age), 0.8)


# Where the driver steers and where it must be braking, outlined.
func _draw_decision(driver: RacingDriver, car: RacingCar) -> void:
	_draw_bar(driver.braking_point, MARK)
	draw_line(car.position, driver.aim, OUTLINE, 0.9)
	draw_line(car.position, driver.aim, MARK, 0.4)
	draw_circle(driver.aim, 1.6, OUTLINE)
	draw_circle(driver.aim, 1.1, MARK)


# A bar across the track at line sample `sample`, outlined; none for -1.
func _draw_bar(sample: int, colour: Color) -> void:
	if sample < 0:
		return
	var at: Vector2 = race.track.line[sample]
	var across: Vector2 = race.track.direction_at(sample).rotated(PI / 2.0) * 7.0
	draw_line(at - across, at + across, OUTLINE, 2.4)
	draw_line(at - across, at + across, colour, 1.2)


func _draw_car(car: RacingCar, path: String, lights: bool) -> void:
	var picture: Texture2D = Art.texture(path)
	var size := Vector2(CAR_LENGTH * picture.get_size().x / picture.get_size().y, CAR_LENGTH)
	draw_set_transform(car.position, car.heading + PI / 2.0, Vector2.ONE)
	draw_texture_rect(picture, Rect2(-size / 2.0, size), false)
	if lights:
		for side: float in [-1.0, 1.0]:
			draw_circle(Vector2(side * size.x * 0.32, size.y * 0.47), 0.45, BRAKE_LIGHT)
	draw_set_transform(Vector2.ZERO)
