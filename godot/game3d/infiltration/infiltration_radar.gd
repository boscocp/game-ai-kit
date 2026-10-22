## The radar: the whole level from above, small, in a corner -- Metal Gear
## Solid's map of the guards and where they look [Wikipedia, MGS 1998] --
## with what the guards know drawn on it.
##
## Boxes grey, the exit yellow, the player blue, each guard a dot in its
## phase's colour with its nearest vision zone as a fan; the watched guard's
## belief as orange cells and its last known position as a white ring;
## every sound as a blue circle where it was made.
##
## When not to use it: to read the scores. The panel says those.
class_name InfiltrationRadar
extends Control

const BACK: Color = Color(0, 0, 0, 0.6)
const BOX: Color = Color(0.6, 0.6, 0.65)

var world: InfiltrationWorld
var watched: int = 0


func _draw() -> void:
	if world == null:
		return
	var scale_by: float = minf(size.x / world.level.arena.width, size.y / world.level.arena.depth)
	draw_rect(Rect2(Vector2.ZERO, size), BACK)
	_draw_belief(scale_by)
	for box: AABB in world.level.arena.boxes:
		draw_rect(Rect2(Vector2(box.position.x, box.position.z) * scale_by, Vector2(box.size.x, box.size.z) * scale_by), BOX)
	draw_circle(world.level.exit_place * scale_by, 4.0, InfiltrationDrawing.EXIT)
	for sound: Dictionary in world.sounds.recent:
		draw_arc(Vector2(sound["place"]) * scale_by, 6.0, 0.0, TAU, 16, InfiltrationDrawing.SOUND, 1.0)
	for guard: InfiltrationGuard in world.guards:
		_draw_guard(guard, scale_by)
	draw_circle(world.player.position * scale_by, 3.5, InfiltrationDrawing.PLAYER)


func _draw_guard(guard: InfiltrationGuard, scale_by: float) -> void:
	if not guard.alive():
		draw_circle(guard.position * scale_by, 2.0, Color(0.4, 0.4, 0.4))
		return
	var colour: Color = InfiltrationDrawing.PHASES[mini(guard.mind.phase(), InfiltrationDrawing.PHASES.size() - 1)]
	var zone: Dictionary = guard.type.vision.zones[1] if guard.type.vision.zones.size() > 1 else guard.type.vision.zones[0]
	var half: float = deg_to_rad(float(zone["half_angle"]))
	var fan: PackedVector2Array = [guard.position * scale_by]
	for step: int in range(7):
		fan.append((guard.position + Vector2.from_angle(guard.facing - half + half * step / 3.0) * float(zone["far"])) * scale_by)
	draw_colored_polygon(fan, Color(colour, 0.25))
	draw_circle(guard.position * scale_by, 3.5, colour)
	if guard.id == watched and guard.mind.memory.known:
		draw_arc(guard.mind.memory.place * scale_by, 5.0, 0.0, TAU, 16, Color.WHITE, 1.5)


func _draw_belief(scale_by: float) -> void:
	if not world.rules.use_belief or world.guards.is_empty():
		return
	var strength: PackedFloat64Array = InfiltrationGround.strengths(world.guard(watched).belief)
	for index: int in range(strength.size()):
		if strength[index] > 0.0:
			var cell: Vector2 = Vector2(world.level.cells[index])
			draw_rect(Rect2(cell * scale_by, Vector2.ONE * scale_by), Color(InfiltrationDrawing.BELIEF, 0.8 * strength[index]))
