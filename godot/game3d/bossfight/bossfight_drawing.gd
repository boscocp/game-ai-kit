## The boss fight in 3D, and what the group is deciding drawn on the floor
## where it decides it (invariant 13).
##
## The arena: a floor, four pillars. The bodies: Kenney's mini characters for
## you and the minions and the survivor, three metres tall, for the boss --
## or primitives when nothing was downloaded (`AssetShelf`). The decisions:
## the three rings round you and every point on them, a line from each
## minion to the point it claimed, a ring at the feet of each token holder
## (yellow melee, cyan ranged) and its place in the queue over each one
## waiting; the boss's reach as a circle on the floor, filling orange through
## its telegraph and red while the blow lands; a ranged minion's aim as a
## line to you; the bolts; and your lock-on.
##
## When not to use it: as the HUD. The panels are 2D.
class_name BossfightDrawing
extends Node3D

const PLAYER: Color = Color(0.3, 0.55, 0.95)
const BOSS: Color = Color(0.55, 0.25, 0.2)
const MELEE: Color = Color(0.85, 0.3, 0.25)
const RANGED: Color = Color(0.75, 0.35, 0.8)
const FLOOR: Color = Color(0.32, 0.3, 0.28)
const PILLAR: Color = Color(0.45, 0.42, 0.4)
const MELEE_TOKEN: Color = Color(1.0, 0.85, 0.2)
const RANGED_TOKEN: Color = Color(0.3, 0.9, 1.0)
const RING: Color = Color(0.7, 0.7, 0.7, 0.6)
const CLAIM: Color = Color(0.4, 0.95, 0.45)
const TELEGRAPH: Color = Color(1.0, 0.6, 0.15)
const ACTIVE: Color = Color(1.0, 0.15, 0.1)
const BOLT: Color = Color(1.0, 0.95, 0.6)
const LOCK: Color = Color(1.0, 1.0, 1.0)
## Lines are drawn this far above the floor, so it does not hide them.
const LIFT: float = 0.05

var shelf: AssetShelf = AssetShelf.new()
var _player: Node3D
var _boss: Node3D
var _boss_label: Label3D
var _minions: Array[Node3D] = []
var _labels: Array[Label3D] = []
var _lines := ImmediateMesh.new()


## Build the arena and the bodies once, for `fight`.
func build(fight: BossFight) -> void:
	for child: Node in get_children():
		child.free()
	_minions.clear()
	_labels.clear()
	_build_arena(fight)
	_player = shelf.model("bot_blue", 1.6, PLAYER)
	add_child(_player)
	_boss = shelf.model("soldier", 3.2, BOSS)
	add_child(_boss)
	_boss_label = _label()
	var lines := MeshInstance3D.new()
	lines.mesh = _lines
	lines.material_override = _line_material()
	add_child(lines)


## Move the bodies to where `fight` has them, and draw the decisions when
## `thinking` is on.
func refresh(fight: BossFight, thinking: bool) -> void:
	while _minions.size() < fight.minions.size():
		var minion: BossMinion = fight.minions[_minions.size()]
		_minions.append(shelf.model("bot_red", 1.5, MELEE if minion.kind == BossMinion.MELEE else RANGED))
		add_child(_minions[-1])
		_labels.append(_label())
	_place(_player, fight.player.position, fight.player.facing)
	_place(_boss, fight.boss_body.position, fight.boss_facing)
	_boss.visible = fight.boss.state != BossBrain.DEFEATED
	for index: int in range(fight.minions.size()):
		var minion: BossMinion = fight.minions[index]
		_minions[index].visible = minion.alive()
		_place(_minions[index], minion.body.position, (fight.player.position - minion.body.position).normalized())
		_labels[index].visible = thinking and minion.alive()
		_labels[index].position = _ground(minion.body.position, 2.0)
		_labels[index].text = BossfightText.over_minion(fight, minion)
	_boss_label.visible = thinking
	_boss_label.position = _ground(fight.boss_body.position, 3.7)
	_boss_label.text = BossfightText.over_boss(fight)
	_draw_lines(fight, thinking)


func _draw_lines(fight: BossFight, thinking: bool) -> void:
	_lines.clear_surfaces()
	_lines.surface_begin(Mesh.PRIMITIVE_LINES)
	_draw_bolts(fight)
	_draw_lock(fight)
	if thinking:
		_draw_rings(fight)
		_draw_tokens(fight)
		_draw_telegraph(fight)
		_draw_aims(fight)
	_lines.surface_end()


func _draw_rings(fight: BossFight) -> void:
	for ring: EngagementRings.Ring in fight.rings.config.rings:
		_circle(fight.rings.target, ring.radius, RING)
	for point: EngagementRings.Point in fight.rings.points:
		var colour: Color = CLAIM if point.claimed_by != -1 else RING
		_circle(point.position, 0.15, colour if point.line_of_sight else Color(colour, 0.25))
	for minion: BossMinion in fight.minions:
		if minion.alive() and minion.point >= 0:
			_segment(minion.body.position, fight.rings.points[minion.point].position, CLAIM)


func _draw_tokens(fight: BossFight) -> void:
	for kind: String in [BossMinion.MELEE, BossMinion.RANGED]:
		var colour: Color = MELEE_TOKEN if kind == BossMinion.MELEE else RANGED_TOKEN
		for who: String in fight.tokens.holders(kind):
			var radius: float = 1.3 if who == BossBrain.ID else 0.6
			_circle(fight.position_of(who), radius, colour)
			_circle(fight.position_of(who), radius + 0.08, colour)


# The boss's reach on the floor: filling through the telegraph, solid red
# while the blow lands.
func _draw_telegraph(fight: BossFight) -> void:
	if fight.boss.state not in BossBrain.WINDOW_STATES or fight.boss.attack == "":
		return
	var reach: float = BossFight.BOSS_REACH.get(fight.boss.attack, 2.0)
	var centre: Vector2 = fight.boss_body.position
	if fight.boss.state == BossBrain.ACTIVE:
		for step: int in range(1, 6):
			_circle(centre, reach * step / 5.0, ACTIVE)
		return
	_circle(centre, reach, TELEGRAPH)
	var progress: float = fight.boss.telegraph_progress(fight.time)
	for step: int in range(1, int(progress * 5.0) + 1):
		_circle(centre, reach * step / 5.0, Color(TELEGRAPH, 0.6))


func _draw_aims(fight: BossFight) -> void:
	for minion: BossMinion in fight.minions:
		if minion.state == BossMinion.AIMING:
			var share: float = 1.0 - minion.window_left() / BossMinion.AIM_SECONDS
			var end: Vector2 = minion.body.position.lerp(fight.player.position, share)
			_segment(minion.body.position, end, RANGED_TOKEN, 1.2)


func _draw_bolts(fight: BossFight) -> void:
	for bolt: Dictionary in fight.bolts:
		var at: Vector2 = bolt["position"]
		_segment(at - bolt["velocity"].normalized() * 0.6, at, BOLT, 1.2)
		_circle(at, 0.2, BOLT, 1.2)


func _draw_lock(fight: BossFight) -> void:
	if fight.player.locked == "":
		return
	var at: Vector2 = fight.position_of(fight.player.locked)
	var high: float = 3.9 if fight.player.locked == BossBrain.ID else 2.4
	_segment(at + Vector2(-0.3, 0), at + Vector2(0.3, 0), LOCK, high)
	_segment(at + Vector2(0, -0.3), at + Vector2(0, 0.3), LOCK, high)


func _circle(centre: Vector2, radius: float, colour: Color, height: float = LIFT) -> void:
	var sides: int = clampi(int(radius * 12.0), 8, 64)
	for side: int in range(sides):
		var from: Vector2 = centre + Vector2.from_angle(TAU * side / sides) * radius
		var to: Vector2 = centre + Vector2.from_angle(TAU * (side + 1) / sides) * radius
		_segment(from, to, colour, height)


func _segment(from: Vector2, to: Vector2, colour: Color, height: float = LIFT) -> void:
	_lines.surface_set_color(colour)
	_lines.surface_add_vertex(_ground(from, height))
	_lines.surface_set_color(colour)
	_lines.surface_add_vertex(_ground(to, height))


func _build_arena(fight: BossFight) -> void:
	var size: float = fight.rules.arena_half * 2.0
	var floor_box: Node3D = AssetShelf.primitive("box", 0.1, FLOOR)
	floor_box.scale = Vector3(size / 0.1, 1.0, size / 0.1)
	floor_box.position.y = -0.1
	add_child(floor_box)
	for pillar: Vector2i in fight.rules.pillars:
		var block: Node3D = AssetShelf.primitive("box", 3.0, PILLAR)
		block.scale = Vector3(2.0 / 3.0, 1.0, 2.0 / 3.0)
		block.position = _ground(Vector2(pillar) + Vector2.ONE, 0.0)
		add_child(block)


func _label() -> Label3D:
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.pixel_size = 0.005
	label.outline_size = 8
	label.no_depth_test = true
	add_child(label)
	return label


func _line_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	return material


# A body stands at `at` on the floor, facing `facing`; a model faces -z.
func _place(body: Node3D, at: Vector2, facing: Vector2) -> void:
	body.position = _ground(at, 0.0)
	if facing != Vector2.ZERO:
		body.rotation.y = atan2(-facing.x, -facing.y)


func _ground(at: Vector2, height: float) -> Vector3:
	return Vector3(at.x, height, at.y)
