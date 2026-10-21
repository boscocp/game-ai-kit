## The bot match in 3D: the arena, the bots, the points, and what one bot is
## deciding drawn in the world where it is deciding it.
##
## The decision is the point (invariant 13). For the bot being watched, every
## candidate spot it weighed is a disc on the floor: green and taller the
## higher it scored, purple where a teammate's claim closed it, red where it
## was exposed, grey where too far or outside the squad's area, white for the
## one chosen. Its score floats above it. Every bot's claim is a line to the
## spot it holds, and the watched bot's sight lines are yellow.
class_name BotMatchDrawing
extends Node3D

const BLUE: Color = Color(0.25, 0.45, 0.95)
const RED: Color = Color(0.9, 0.25, 0.2)
const NOBODY: Color = Color(0.75, 0.75, 0.7)
const LOW_BOX: Color = Color(0.62, 0.6, 0.66)
const HIGH_BOX: Color = Color(0.45, 0.44, 0.5)
const KEPT: Color = Color(0.35, 0.85, 0.35)
const CHOSEN: Color = Color(1, 1, 1)
const CLAIMED: Color = Color(0.7, 0.35, 0.85)
const EXPOSED: Color = Color(0.9, 0.3, 0.25)
const DROPPED: Color = Color(0.5, 0.5, 0.5)
const SIGHT: Color = Color(1.0, 0.9, 0.2)
const BOT_HEIGHT: float = 1.8

var shelf: AssetShelf = AssetShelf.new()
var _bots: Array[Node3D] = []
var _points: Array[MeshInstance3D] = []
var _lines := ImmediateMesh.new()
var _markers: Node3D


## Build the arena and the bots once, for `world`.
func build(world: BotMatch) -> void:
	var floor_look: Node3D = AssetShelf.primitive("box", 1.0, Color(0.55, 0.58, 0.5))
	floor_look.scale = Vector3(world.arena.width, 0.1, world.arena.depth)
	floor_look.position = Vector3(world.arena.width / 2.0, -0.1, world.arena.depth / 2.0)
	add_child(floor_look)
	for box: AABB in world.arena.boxes:
		var look: Node3D = AssetShelf.primitive("box", 1.0, LOW_BOX if box.size.y < BotArena.HIGH else HIGH_BOX)
		look.scale = box.size
		look.position = Vector3(box.get_center().x, 0.0, box.get_center().z)
		add_child(look)
	for place: Vector2 in world.arena.point_places:
		_points.append(_point_disc(place, world.rules.capture_radius))
	for bot: MatchBot in world.bots:
		var blue: bool = bot.team == BotMatch.BLUE
		var model: Node3D = shelf.model("bot_blue" if blue else "bot_red", BOT_HEIGHT, BLUE if blue else RED)
		add_child(model)
		_bots.append(model)
	var drawn := MeshInstance3D.new()
	drawn.mesh = _lines
	add_child(drawn)
	_markers = Node3D.new()
	add_child(_markers)


## Move everything to where `world` has it, and draw `watched`'s decision.
func refresh(world: BotMatch, watched: int) -> void:
	for bot: MatchBot in world.bots:
		var model: Node3D = _bots[bot.id]
		model.visible = bot.alive()
		model.position = Vector3(bot.position.x, 0.0, bot.position.y)
		model.rotation = Vector3(0, -bot.facing + PI / 2.0, 0)
		model.scale = Vector3(1, 0.6 if bot.crouched else 1.0, 1)
	for index: int in range(_points.size()):
		var owner: int = world.point_owner[index]
		var colour: Color = NOBODY if owner == -1 else (BLUE if owner == BotMatch.BLUE else RED)
		(_points[index].material_override as StandardMaterial3D).albedo_color = colour
	_draw_lines(world, watched)
	_draw_candidates(world, watched)


func _point_disc(place: Vector2, radius: float) -> MeshInstance3D:
	var disc := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.05
	disc.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = NOBODY
	disc.material_override = material
	disc.position = Vector3(place.x, 0.02, place.y)
	add_child(disc)
	return disc


# Every claim as a line from its bot to its spot, and the watched bot's sight.
func _draw_lines(world: BotMatch, watched: int) -> void:
	_lines.clear_surfaces()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	_lines.surface_begin(Mesh.PRIMITIVE_LINES, material)
	# Two points that are always there, so a surface is never empty.
	_line(Vector2.ZERO, Vector2.ZERO, 0.0, NOBODY)
	for bot: MatchBot in world.bots:
		if bot.alive() and bot.spot != -1:
			_line(bot.position, world.place_position(bot.spot), 0.1, BLUE if bot.team == BotMatch.BLUE else RED)
	if watched >= 0:
		for enemy: int in world.sight.get(watched, []):
			_line(world.bots[watched].position, world.bots[enemy].position, world.rules.eye_height, SIGHT)
	_lines.surface_end()


func _line(from: Vector2, to: Vector2, height: float, colour: Color) -> void:
	_lines.surface_set_color(colour)
	_lines.surface_add_vertex(Vector3(from.x, height, from.y))
	_lines.surface_set_color(colour)
	_lines.surface_add_vertex(Vector3(to.x, height, to.y))


# The watched bot's last position query, one disc and one number a candidate.
func _draw_candidates(world: BotMatch, watched: int) -> void:
	for child: Node in _markers.get_children():
		child.free()
	if watched < 0:
		return
	var team: MatchTeam = world.teams[world.bots[watched].team]
	if not team.last_choice.has(watched):
		return
	var choice: TacticalPositions.Choice = team.last_choice[watched][0]
	var places: Array = team.last_choice[watched][1]
	for index: int in range(places.size()):
		var at: Vector2 = world.place_position(places[index])
		_markers.add_child(_marker(at, choice.statuses[index], choice.scores[index], index == choice.chosen))


func _marker(place: Vector2, status: String, score: float, chosen: bool) -> Node3D:
	var holder := Node3D.new()
	holder.position = Vector3(place.x, 0.0, place.y)
	var height: float = 0.05 + (score / 100.0 if status == TacticalPositions.KEPT else 0.0)
	var disc: Node3D = AssetShelf.primitive("box", 1.0, CHOSEN if chosen else _status_colour(status))
	disc.scale = Vector3(0.4, height, 0.4)
	holder.add_child(disc)
	if status == TacticalPositions.KEPT:
		var label := Label3D.new()
		label.text = "%.0f" % score
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(0, height + 0.4, 0)
		holder.add_child(label)
	return holder


static func _status_colour(status: String) -> Color:
	match status:
		TacticalPositions.KEPT:
			return KEPT
		TacticalPositions.CLAIMED:
			return CLAIMED
		TacticalPositions.EXPOSED:
			return EXPOSED
	return DROPPED
