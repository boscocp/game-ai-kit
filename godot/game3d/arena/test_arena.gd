## The 3D tier's test arena: the size T51's bot match needs, and no AI yet.
##
## Sixteen bots, eight a side, walk a ring round a blocky arena under one
## light with shadows. Each step, every bot is asked which enemies it can see,
## by a ray from its eyes to theirs that the cover may block -- the sight line
## every shooter bot after this one reasons with. The lines it found are drawn
## between the bots, and the counts are the overlay.
##
## What it is for: T50 measures on it (headless physics and rays, the frame
## rate, a scene that loads with its models missing). It is not an example a
## person plays, and it decides nothing a game would keep.
extends Node3D

const BOTS_A_SIDE: int = 8
const BOT_HEIGHT: float = 1.8
## Where a bot looks from, above its feet.
const EYES: float = 1.5
const ARENA_SIZE: float = 32.0
const RING_RADIUS: float = 11.0
## How far round the ring a bot walks in one decision, in radians.
const STRIDE: float = 0.06
const BLUE: Color = Color(0.25, 0.45, 0.95)
const RED: Color = Color(0.9, 0.25, 0.2)
const SIGHT: Color = Color(1.0, 0.9, 0.2)
## Cover blocks: where, and how big. Laid out by hand so lines of sight open
## and close as the ring turns.
const COVER: Array[Array] = [
	[Vector3(0, 0, 0), Vector3(4, 2.5, 4)],
	[Vector3(6, 0, 2), Vector3(1, 2, 3)],
	[Vector3(-6, 0, -2), Vector3(1, 2, 3)],
	[Vector3(2, 0, -7), Vector3(3, 2, 1)],
	[Vector3(-2, 0, 7), Vector3(3, 2, 1)],
	[Vector3(8, 0, -8), Vector3(2, 1.2, 2)],
	[Vector3(-8, 0, 8), Vector3(2, 1.2, 2)],
]

## Which shelf the models come from; a test sets one that has nothing on it.
var shelf: AssetShelf = AssetShelf.new()
var _bots: Array[StaticBody3D] = []
var _turn: int = 0
var _seen: Dictionary = {}
var _lines := ImmediateMesh.new()


func _ready() -> void:
	_build_ground_and_light()
	for spot: Array in COVER:
		_add_cover(spot[0], spot[1])
	for index: int in range(BOTS_A_SIDE * 2):
		_add_bot(index)
	var drawn := MeshInstance3D.new()
	drawn.name = "SightLines"
	drawn.mesh = _lines
	add_child(drawn)
	($Interface/Legend as Legend).set_entries([
		[BLUE, "a blue bot"], [RED, "a red bot"],
		[SIGHT, "a sight line: this bot sees that enemy, past the cover"],
	])
	_place_bots()


## Walk the ring one stride, then ask every bot whom it sees.
func step_decision() -> void:
	_turn += 1
	_place_bots()
	_seen = _sight_lines()
	_draw_lines()


## What the bots reasoned with: each bot's visible enemies, and the count.
func decision_overlay() -> Dictionary:
	var total: int = 0
	for names: Array in _seen.values():
		total += names.size()
	return {"turn": _turn, "sight_lines": total, "seen_by": _seen.duplicate(true)}


## Take every cover block away, as a test's planted case does: with nothing
## to block a ray, every bot sees every enemy.
func remove_cover() -> void:
	for child: Node in get_children():
		if child.name.begins_with("Cover"):
			child.free()


## The bots, for a test that wants to know what was built.
func bots() -> Array[StaticBody3D]:
	return _bots


func _build_ground_and_light() -> void:
	var ground := _solid("Ground", Vector3(ARENA_SIZE, 1, ARENA_SIZE), Color(0.55, 0.58, 0.5))
	ground.position = Vector3(0, -1, 0)
	var light := DirectionalLight3D.new()
	light.shadow_enabled = true
	light.rotation = Vector3(-0.9, 0.6, 0)
	add_child(light)


func _add_cover(place: Vector3, size: Vector3) -> void:
	var block := _solid("Cover", size, Color(0.62, 0.6, 0.66))
	block.position = place


# A box that is seen and that a ray hits; its origin sits on the floor.
func _solid(label: String, size: Vector3, colour: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector3(0, size.y * 0.5, 0)
	body.add_child(shape)
	var look: Node3D = AssetShelf.primitive("box", 1.0, colour)
	look.scale = size
	body.add_child(look)
	add_child(body, true)
	return body


func _add_bot(index: int) -> void:
	var blue: bool = index < BOTS_A_SIDE
	var body := StaticBody3D.new()
	body.name = "%s%d" % ["Blue" if blue else "Red", index % BOTS_A_SIDE]
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = BOT_HEIGHT
	capsule.radius = BOT_HEIGHT * 0.25
	shape.shape = capsule
	shape.position = Vector3(0, BOT_HEIGHT * 0.5, 0)
	body.add_child(shape)
	body.add_child(shelf.model("bot_blue" if blue else "bot_red", BOT_HEIGHT, BLUE if blue else RED))
	body.set_meta("blue", blue)
	add_child(body)
	_bots.append(body)


# Blue on one half of the ring and red on the other, all walking the same way.
# Each move is also handed to the physics server at once: measured on 4.7.2,
# a body moved through its node is in the space only from the next physics
# frame, so the rays of this same decision would see where it was.
func _place_bots() -> void:
	for index: int in range(_bots.size()):
		var angle: float = TAU * index / _bots.size() + _turn * STRIDE
		var body: StaticBody3D = _bots[index]
		body.position = Vector3(cos(angle), 0, sin(angle)) * RING_RADIUS
		body.rotation = Vector3(0, -angle, 0)
		if body.is_inside_tree():
			_tell_the_space(body)


func _tell_the_space(body: StaticBody3D) -> void:
	var state: int = PhysicsServer3D.BODY_STATE_TRANSFORM
	PhysicsServer3D.body_set_state(body.get_rid(), state, body.global_transform)


# Every bot's enemies it has a clear ray to, eyes to eyes. The ray passes
# through every bot but the target, so only the cover can block it: a bot
# standing in the way is not cover, and the count says what the blocks do.
func _sight_lines() -> Dictionary:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var seen: Dictionary = {}
	for looker: StaticBody3D in _bots:
		seen[str(looker.name)] = _enemies_seen_by(space, looker)
	return seen


func _enemies_seen_by(space: PhysicsDirectSpaceState3D, looker: StaticBody3D) -> Array[String]:
	var visible: Array[String] = []
	for target: StaticBody3D in _bots:
		if target.get_meta("blue") != looker.get_meta("blue") and _sees(space, looker, target):
			visible.append(str(target.name))
	return visible


func _sees(space: PhysicsDirectSpaceState3D, looker: StaticBody3D, target: StaticBody3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(
			looker.position + Vector3.UP * EYES, target.position + Vector3.UP * EYES)
	var others: Array[RID] = []
	for body: StaticBody3D in _bots:
		if body != target:
			others.append(body.get_rid())
	query.exclude = others
	var hit: Dictionary = space.intersect_ray(query)
	return not hit.is_empty() and hit["collider"] == target


func _draw_lines() -> void:
	_lines.clear_surfaces()
	if decision_overlay()["sight_lines"] == 0:
		return  # an ImmediateMesh surface with no vertices is an engine error
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = SIGHT
	_lines.surface_begin(Mesh.PRIMITIVE_LINES, material)
	var by_name: Dictionary = {}
	for body: StaticBody3D in _bots:
		by_name[str(body.name)] = body
	for looker: String in _seen:
		for target: String in _seen[looker]:
			_lines.surface_add_vertex((by_name[looker] as Node3D).position + Vector3.UP * EYES)
			_lines.surface_add_vertex((by_name[target] as Node3D).position + Vector3.UP * EYES)
	_lines.surface_end()
