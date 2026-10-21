## The race from above, in a corner: the track and every car on it.
##
## ADR 0018 asks every 3D example for a 2D map of the same match, the view a
## person reads at once. The racing line is drawn in, each car is a dot of
## its colour, and the watched car is ringed.
class_name RaceMap3D
extends Control

const ROAD: Color = Color(0.35, 0.35, 0.38)
const LINE: Color = Color(1.0, 0.85, 0.2)
const BACKING: Color = Color(0.08, 0.09, 0.1, 0.85)

var race: Race3D = null
var colours: Array[Color] = []
var watched: int = -1


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKING)
	if race == null or race.track.centre.is_empty():
		return
	var box: Rect2 = _bounds(race.track)
	var scale_by: float = minf((size.x - 16.0) / box.size.x, (size.y - 16.0) / box.size.y)
	var centre: Vector2 = size / 2.0
	var mapped := func(at: Vector2) -> Vector2: return centre + (at - box.get_center()) * scale_by
	var road := PackedVector2Array()
	var line := PackedVector2Array()
	for index: int in range(race.track.centre.size() + 1):
		road.append(mapped.call(race.track.centre[race.track.wrapped(index)]))
		line.append(mapped.call(race.track.line[race.track.wrapped(index)]))
	draw_polyline(road, ROAD, maxf(2.0, race.track.half_width * 2.0 * scale_by))
	draw_polyline(line, LINE, 1.0)
	for number: int in range(race.cars.size()):
		var at: Vector2 = mapped.call(RaceSenses3D.on_map(race.cars[number]))
		draw_circle(at, 4.0, colours[number] if number < colours.size() else Color.WHITE)
		if number == watched:
			draw_arc(at, 7.0, 0.0, TAU, 16, Color.WHITE, 1.5)


static func _bounds(track: RaceTrack3D) -> Rect2:
	var box := Rect2(track.centre[0], Vector2.ZERO)
	for at: Vector2 in track.centre:
		box = box.expand(at)
	return box.grow(track.half_width)
