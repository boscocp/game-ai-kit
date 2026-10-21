## The watched car's distance off where it wants to be, over the last few
## seconds: the PID's error, drawn as a trace (T54 step 4).
##
## With the full PID the trace comes back to the middle after a bend; with
## the proportional term alone it sits off it through a long bend -- the
## steady-state offset Melder & Tomlinson's chapter names -- or swings.
## The lines above and below the middle are a metre each way.
class_name RaceTrace3D
extends Control

## Frames of history kept: six seconds.
const KEPT: int = 360
const METRES_SHOWN: float = 4.0
const TRACE: Color = Color(0.3, 0.9, 1.0)
const GRID: Color = Color(1.0, 1.0, 1.0, 0.25)
const BACKING: Color = Color(0.08, 0.09, 0.1, 0.85)

var errors := PackedFloat64Array()


## Keep one more frame's error, in metres.
func push(error: float) -> void:
	errors.append(error)
	if errors.size() > KEPT:
		errors = errors.slice(errors.size() - KEPT)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKING)
	var middle: float = size.y / 2.0
	var per_metre: float = size.y / 2.0 / METRES_SHOWN
	for metres: float in [-1.0, 0.0, 1.0]:
		draw_line(Vector2(0, middle - metres * per_metre), Vector2(size.x, middle - metres * per_metre), GRID)
	var points := PackedVector2Array()
	for index: int in range(errors.size()):
		var height: float = clampf(errors[index], -METRES_SHOWN, METRES_SHOWN) * per_metre
		points.append(Vector2(size.x * index / KEPT, middle - height))
	if points.size() >= 2:
		draw_polyline(points, TRACE, 1.5)
