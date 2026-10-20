## The cars, and what one AI driver is deciding, drawn above the track.
##
## Each car is a Kenney Racing Pack car (CC0), drawn `CAR_LENGTH` metres long
## and turned to its heading. The followed driver's decision is drawn on top,
## each mark with a dark outline so it reads on tarmac and grass alike: a
## white dot where it steers, a line from the car to it, and a white bar
## across the track where it must already be braking. In metres, redrawn
## every step.
class_name RacingRaceView
extends Node2D

## Metres long a car is drawn. Its picture is 71 by 131 pixels, nose up.
const CAR_LENGTH: float = 5.2
const MARK := Color(1.0, 1.0, 1.0)
const OUTLINE := Color(0.05, 0.05, 0.08)

var race: RacingRace
## The picture each car is drawn with, by car number.
var pictures: Array[String] = []
## The car whose driver's decision is drawn; -1 for none.
var followed: int = -1
## The cars drawn; the others are left out (T23's "alone").
var shown: Array[bool] = []


func _init(shown_race: RacingRace, car_pictures: Array[String]) -> void:
	race = shown_race
	pictures = car_pictures
	for _car: RacingCar in race.cars:
		shown.append(true)


func _draw() -> void:
	if followed >= 0:
		_draw_decision(race.drivers[followed], race.cars[followed])
	for number: int in range(race.cars.size()):
		if shown[number]:
			_draw_car(race.cars[number], pictures[number])


# Where the driver steers and where it must be braking, outlined.
func _draw_decision(driver: RacingDriver, car: RacingCar) -> void:
	if driver.braking_point >= 0:
		var at: Vector2 = race.track.line[driver.braking_point]
		var across: Vector2 = race.track.direction_at(driver.braking_point).rotated(PI / 2.0) * 7.0
		draw_line(at - across, at + across, OUTLINE, 2.4)
		draw_line(at - across, at + across, MARK, 1.2)
	draw_line(car.position, driver.aim, OUTLINE, 0.9)
	draw_line(car.position, driver.aim, MARK, 0.4)
	draw_circle(driver.aim, 1.6, OUTLINE)
	draw_circle(driver.aim, 1.1, MARK)


func _draw_car(car: RacingCar, path: String) -> void:
	var picture: Texture2D = Art.texture(path)
	var size := Vector2(CAR_LENGTH * picture.get_size().x / picture.get_size().y, CAR_LENGTH)
	draw_set_transform(car.position, car.heading + PI / 2.0, Vector2.ONE)
	draw_texture_rect(picture, Rect2(-size / 2.0, size), false)
	draw_set_transform(Vector2.ZERO)
