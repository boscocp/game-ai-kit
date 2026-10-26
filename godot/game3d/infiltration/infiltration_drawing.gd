## The infiltration level in 3D, and what the guards are deciding drawn on
## the floor where they decide it (invariant 13).
##
## The level: the floor tinted by its light, cell by cell -- the player's
## own measure of safety [Leonard 2003] -- the boxes, the hiding places in
## green, and the exit. The bodies: Kenney's survivor or the primitive
## humanoid (`BotBody`), the player blue and the guards red, a downed guard
## lying flat. The decisions: each guard's vision zones as outlines on the
## floor, in its phase's colour; for a guard looking at the player, a line
## to each body point, green where clear and red where a box hid it; the
## watched guard's belief as a heat map, its last known position as a grey
## silhouette, the spots it was given and the spots searched, and its way
## out; every sound's flood as a ring of cells at its edge.
##
## When not to use it: as the HUD. The bars, scores and radar are 2D.
class_name InfiltrationDrawing
extends Node3D

const PLAYER: Color = Color(0.3, 0.5, 0.95)
const GUARD: Color = Color(0.85, 0.25, 0.2)
const LOW_BOX: Color = Color(0.55, 0.52, 0.5)
const HIGH_BOX: Color = Color(0.38, 0.36, 0.42)
const HIDING: Color = Color(0.2, 0.5, 0.25, 0.7)
const EXIT: Color = Color(0.95, 0.85, 0.2)
const CLEAR: Color = Color(0.3, 0.95, 0.4)
const BLOCKED: Color = Color(0.95, 0.25, 0.2)
const BELIEF: Color = Color(1.0, 0.45, 0.1)
const SEARCHED: Color = Color(0.6, 0.6, 0.6)
const SPOT: Color = Color(0.7, 0.35, 0.9)
const SOUND: Color = Color(0.4, 0.85, 1.0)
const GHOST: Color = Color(0.85, 0.85, 0.85, 0.35)
## A phase's colour: calm, suspicious, searching, alert.
const PHASES: Array[Color] = [Color(0.5, 0.8, 0.5), Color(0.95, 0.85, 0.3), Color(1.0, 0.55, 0.15), Color(0.95, 0.15, 0.15)]

var shelf: AssetShelf = AssetShelf.new()
var _player: BotBody
var _guards: Array[BotBody] = []
var _lines := ImmediateMesh.new()
var _ghost: Node3D
var _belief: MultiMeshInstance3D
var _drawn_at: float = 0.0


## Build the level and the bodies once, for `world`.
func build(world: InfiltrationWorld) -> void:
	for child: Node in get_children():
		child.free()
	_guards.clear()
	InfiltrationGround.build(self, world.level)
	_player = BotBody.new(shelf, PLAYER)
	add_child(_player)
	for guard: InfiltrationGuard in world.guards:
		var body := BotBody.new(shelf, GUARD)
		add_child(body)
		_guards.append(body)
	_ghost = AssetShelf.primitive("humanoid", BotBody.HEIGHT, GHOST)
	add_child(_ghost)
	_belief = InfiltrationGround.belief_tiles(self, world.level)
	var drawn := MeshInstance3D.new()
	drawn.mesh = _lines
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	drawn.material_override = material
	add_child(drawn)


## Move the bodies and draw the decisions of `world`, the guard `watched`
## in full; `thinking` false draws only what a player would see.
func refresh(world: InfiltrationWorld, watched: int, thinking: bool) -> void:
	var delta: float = world.time - _drawn_at
	_drawn_at = world.time
	var crouched: bool = world.player.stance != "standing"  # not shown: an identifier
	_player.stand(world.level.arena.above(world.player.position, 0.0), world.player.facing, crouched, delta)
	_player.scale.y = 0.25 if world.player.stance == "prone" else _player.scale.y  # not shown: an identifier
	for guard: InfiltrationGuard in world.guards:
		var body: BotBody = _guards[guard.id]
		body.stand(world.level.arena.above(guard.position, 0.0), guard.facing, false, delta)
		body.rotation.z = 0.0 if guard.alive() else PI / 2.0
	_lines.clear_surfaces()
	_ghost.visible = false
	_belief.visible = thinking and world.rules.use_belief
	if not thinking:
		return
	_lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for guard: InfiltrationGuard in world.guards:
		if guard.alive():
			_draw_zones(world, guard)
			_draw_points_seen(world, guard)
	_draw_sounds(world)
	_draw_watched(world, world.guard(watched))
	_lines.surface_end()


func _draw_zones(world: InfiltrationWorld, guard: InfiltrationGuard) -> void:
	var colour: Color = PHASES[mini(guard.mind.phase(), PHASES.size() - 1)]
	var floor_height: float = world.level.arena.floor_at(guard.position) + 0.05
	for zone: Dictionary in guard.type.vision.zones:
		var half: float = deg_to_rad(float(zone["half_angle"]))
		var outline: PackedVector2Array = []
		for step: int in range(9):
			outline.append(guard.position + Vector2.from_angle(guard.facing - half + half * step / 4.0) * float(zone["far"]))
		for step: int in range(8, -1, -1):
			outline.append(guard.position + Vector2.from_angle(guard.facing - half + half * step / 4.0) * maxf(float(zone["near"]), 0.3))
		for index: int in range(outline.size()):
			_line(_lift(outline[index], floor_height), _lift(outline[(index + 1) % outline.size()], floor_height), colour)


# For a guard looking at the player: a line to each body point, green where
# clear, red where a box hid it.
func _draw_points_seen(world: InfiltrationWorld, guard: InfiltrationGuard) -> void:
	var offset: Vector2 = world.player.position - guard.position
	if guard.type.vision.zone_at(offset.length(), GuardEyes.angle_off(guard.facing, offset)) == -1:
		return
	var eye: Vector3 = guard.eye(world.level.arena, world.rules)
	for height: float in world.rules.points_of(world.player.stance):
		var point: Vector3 = world.level.arena.above(world.player.position, height)
		_line(eye, point, CLEAR if world.level.arena.clear_line(eye, point) else BLOCKED)


func _draw_sounds(world: InfiltrationWorld) -> void:
	for sound: Dictionary in world.sounds.recent:
		_draw_ring(world, sound)


# A mark on every cell at the edge of a sound's flood: how far it reached.
func _draw_ring(world: InfiltrationWorld, sound: Dictionary) -> void:
	var kind: String = str(sound["kind"])
	var radius: int = floori(world.sounds.table.radius(kind)) if world.sounds.table.has(kind) else 0
	var reached: Dictionary = sound["reached"]
	for cell: Vector2i in reached:
		var middle: Vector3 = world.level.arena.above(BotArena.centre_of(cell), 0.08)
		if int(reached[cell]) >= radius - 1:
			_line(middle - Vector3(0.3, 0, 0), middle + Vector3(0.3, 0, 0), SOUND)


func _draw_watched(world: InfiltrationWorld, guard: InfiltrationGuard) -> void:
	InfiltrationGround.colour_belief(_belief, world.level, guard.belief)
	if guard.mind.memory.known:
		_ghost.visible = true
		_ghost.position = world.level.arena.above(guard.mind.memory.place, 0.0)
	var searching: bool = guard.mind.at_least(str(world.rules.decision["search_from"]))
	for index: int in range(world.team.spots.size()):
		var spot: Dictionary = world.team.spots[index]
		if searching and (guard.searched.has(index) or index == guard.spot):
			var place: Vector3 = world.level.arena.above(spot["place"], 0.1)
			var colour: Color = SPOT if index == guard.spot else SEARCHED
			_line(place + Vector3(-0.3, 0, -0.3), place + Vector3(0.3, 0, 0.3), colour)
			_line(place + Vector3(-0.3, 0, 0.3), place + Vector3(0.3, 0, -0.3), colour)
	if guard.way_out != Vector2.INF:
		_line(world.level.arena.above(guard.way_out, 0.0), world.level.arena.above(guard.way_out, 2.5), SPOT)
	if guard.goal != Vector2.INF and is_finite(guard.goal.x):
		_line(guard.eye(world.level.arena, world.rules), world.level.arena.above(guard.goal, 0.1), Color(1, 1, 1, 0.6))


func _line(from: Vector3, to: Vector3, colour: Color) -> void:
	_lines.surface_set_color(colour)
	_lines.surface_add_vertex(from)
	_lines.surface_set_color(colour)
	_lines.surface_add_vertex(to)


static func _lift(place: Vector2, height: float) -> Vector3:
	return Vector3(place.x, height, place.y)
