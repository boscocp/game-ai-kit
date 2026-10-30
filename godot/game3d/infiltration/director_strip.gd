## The director's strip on the infiltration HUD (T90): the player's
## intensity over the last minute, the peak threshold and the fade's as
## lines, the phase by name, and each order as a mark where it was given --
## the decision and the number it was taken on (invariant 13).
##
## Drawn only with the director on and the reasoning shown (H). The map's
## line to where a sent patrol starts is the radar's.
##
## When not to use it: to read why a guard acts. That is the panel's.
class_name DirectorStrip
extends Control

const BACK: Color = Color(0, 0, 0, 0.6)
const CURVE: Color = Color(1.0, 0.55, 0.2)
const PEAK: Color = Color(1.0, 0.3, 0.3, 0.8)
const FADE: Color = Color(0.5, 0.8, 1.0, 0.6)
const SENT: Color = Color(1.0, 0.85, 0.2)
const RECALLED: Color = Color(0.6, 0.6, 0.6)

var world: InfiltrationWorld
var thinking: bool = true


func _draw() -> void:
	if world == null or world.director == null or not thinking:
		return
	var orders: DirectorOrders = world.director
	var spec: Dictionary = orders.pacing.spec
	draw_rect(Rect2(Vector2.ZERO, size), BACK)
	_level_line(float(spec["peak"]), PEAK)
	_level_line(float(spec["fade_below"]), FADE)
	_draw_curve(orders.history)
	_draw_marks(orders)
	var counted: Vector2i = orders.on_patrol(world)
	var label: String = tr("director: {phase}, intensity {intensity}, {out} of {reserve} on patrol").format({
		phase = InfiltrationWords.word(orders.pacing.phase), intensity = "%.2f" % orders.pacing.intensity,
		out = counted.x, reserve = counted.y})
	draw_string(ThemeDB.fallback_font, Vector2(6, 14), label, HORIZONTAL_ALIGNMENT_LEFT, size.x - 12, 12, Color.WHITE)


## The height on the strip of an intensity `value`, 0 at the bottom.
func height_of(value: float) -> float:
	return size.y - value * (size.y - 20.0)


func _level_line(value: float, colour: Color) -> void:
	draw_line(Vector2(0, height_of(value)), Vector2(size.x, height_of(value)), colour, 1.0)


func _draw_curve(history: PackedFloat64Array) -> void:
	if history.size() < 2:
		return
	var points := PackedVector2Array()
	var kept: float = DirectorOrders.REMEMBERED / world.rules.step_seconds
	for index: int in range(history.size()):
		var across: float = size.x - (history.size() - 1 - index) / kept * size.x
		points.append(Vector2(across, height_of(history[index])))
	draw_polyline(points, CURVE, 2.0)


# Each order of the last minute, a mark at its time: yellow sent, grey
# called back.
func _draw_marks(orders: DirectorOrders) -> void:
	for order: Dictionary in orders.orders:
		var ago: float = world.time - float(order["time"])
		if ago <= DirectorOrders.REMEMBERED:
			var across: float = size.x - ago / DirectorOrders.REMEMBERED * size.x
			var colour: Color = SENT if order["order"] == "send" else RECALLED
			draw_line(Vector2(across, 18), Vector2(across, size.y), colour, 2.0)
