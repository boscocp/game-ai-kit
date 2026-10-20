## The whole track in a corner, and a dot for every car on it.
##
## The camera follows your car close enough to see the AI's decisions, which
## leaves most of the track off screen. This is the rest of it: the centre
## line, the start, and each car as a dot in its own colour, ringed in white
## so the black car shows too. Redrawn every step; the track is scaled to
## fit the control, whatever its size.
class_name RacingMinimap
extends Control

const ROAD := Color(0.85, 0.88, 0.9)
const BACKGROUND := Color(0.1, 0.14, 0.1, 0.85)

var race: RacingRace
## The colour of each car's dot, by car number.
var colours: Array[Color] = []


## Show `shown_race`, each car in its colour of `car_colours`.
func show_race(shown_race: RacingRace, car_colours: Array[Color]) -> void:
	race = shown_race
	colours = car_colours
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	if race == null:
		return
	var points := PackedVector2Array()
	for point: Vector2 in race.track.centre:
		points.append(_on_map(point))
	points.append(points[0])
	draw_polyline(points, ROAD, 3.0)
	draw_circle(points[0], 3.0, Color.WHITE)
	for number: int in range(race.cars.size()):
		draw_circle(_on_map(race.cars[number].position), 5.5, Color.WHITE)
		draw_circle(_on_map(race.cars[number].position), 4.0, colours[number])


# Where a point of the track, in metres, falls on the map.
func _on_map(point: Vector2) -> Vector2:
	var area := Rect2(Vector2(10, 0), Vector2(450, 320)).grow(RacingTrack.HALF_WIDTH)
	var fit: float = minf(size.x / area.size.x, size.y / area.size.y)
	return (point - area.position) * fit + (size - area.size * fit) / 2.0
