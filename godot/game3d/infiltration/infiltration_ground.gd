## The infiltration level's ground as a person sees it: floor tiles as
## bright as the light on them, the boxes, the hiding places, the exit --
## and the tiles a guard's belief is drawn on.
##
## The floor is one tile a cell, darker where the light is low, so a player
## reads the guards' rule for light off the ground itself [Leonard 2003].
## Tiles are a `MultiMesh`, one draw for the whole floor. The boxes are the
## bot match's primitives, low cover lighter than the high.
##
## When not to use it: as a lit scene. The light here is the rule's, drawn;
## the engine's lamps are not what a guard reads.
class_name InfiltrationGround
extends RefCounted

const DARK: Color = Color(0.08, 0.09, 0.12)
const LIT: Color = Color(0.85, 0.8, 0.6)


## Build the floor, boxes, hiding places and exit of `level` under `parent`.
static func build(parent: Node3D, level: InfiltrationLevel) -> void:
	var ground: Node3D = AssetShelf.primitive("box", 1.0, DARK)
	ground.scale = Vector3(level.arena.width, 0.1, level.arena.depth)
	ground.position = Vector3(level.arena.width / 2.0, -0.11, level.arena.depth / 2.0)
	parent.add_child(ground)
	var floor_tiles: MultiMeshInstance3D = tiles(parent, level, 0.01)
	for index: int in range(level.cells.size()):
		var lit: float = level.light.at(level.cells[index])
		var colour: Color = DARK.lerp(LIT, lit)
		if level.hidden.has(level.cells[index]):
			colour = colour.lerp(InfiltrationDrawing.HIDING, 0.6)
		floor_tiles.multimesh.set_instance_color(index, colour)
	for box: AABB in level.arena.boxes:
		var low: bool = box.size.y < BotArena.HIGH
		var look: Node3D = AssetShelf.primitive("box", 1.0, InfiltrationDrawing.LOW_BOX if low else InfiltrationDrawing.HIGH_BOX)
		look.scale = box.size
		look.position = Vector3(box.get_center().x, 0.0, box.get_center().z)
		parent.add_child(look)
	var exit_marker: Node3D = AssetShelf.primitive("box", 1.0, InfiltrationDrawing.EXIT)
	exit_marker.scale = Vector3(1.0, 0.1, 1.0)
	exit_marker.position = level.arena.above(level.exit_place, 0.0)
	parent.add_child(exit_marker)


## One flat tile a walk cell, `height` above its floor, each its own colour.
static func tiles(parent: Node3D, level: InfiltrationLevel, height: float) -> MultiMeshInstance3D:
	var quad := PlaneMesh.new()
	quad.size = Vector2(0.96, 0.96)
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.use_colors = true
	many.mesh = quad
	many.instance_count = level.cells.size()
	for index: int in range(level.cells.size()):
		var place: Vector3 = level.arena.above(BotArena.centre_of(level.cells[index]), height)
		many.set_instance_transform(index, Transform3D(Basis(), place))
	var shown := MultiMeshInstance3D.new()
	shown.multimesh = many
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shown.material_override = material
	parent.add_child(shown)
	return shown


## The tiles a belief is drawn on, just above the floor.
static func belief_tiles(parent: Node3D, level: InfiltrationLevel) -> MultiMeshInstance3D:
	return tiles(parent, level, 0.04)


## Colour `shown`'s tiles by a belief's `shares`: clear where it is no more
## than an even share -- a guard that knows nothing believes nothing in
## particular -- orange and opaque where it is most.
static func colour_belief(shown: MultiMeshInstance3D, level: InfiltrationLevel, shares: PackedFloat64Array) -> void:
	var strength: PackedFloat64Array = strengths(shares)
	for index: int in range(level.cells.size()):
		shown.multimesh.set_instance_color(index, Color(InfiltrationDrawing.BELIEF, 0.75 * strength[index]))


## How strongly each cell stands out in a belief's `shares`: 0 at or below
## an even share, 1 at the most believed cell; all 0 when it is even
## everywhere.
static func strengths(shares: PackedFloat64Array) -> PackedFloat64Array:
	var even: float = 1.0 / maxf(shares.size(), 1.0)
	var most: float = 0.0
	for share: float in shares:
		most = maxf(most, share)
	var found := PackedFloat64Array()
	found.resize(shares.size())
	if most <= even * 1.01:
		return found
	for index: int in range(shares.size()):
		found[index] = clampf((shares[index] - even) / (most - even), 0.0, 1.0)
	return found


## The particles' dots, one a walk cell, just above the belief's tiles:
## a flat disc whose size `size_dots` sets from the cloud (T91).
static func particle_dots(parent: Node3D, level: InfiltrationLevel) -> MultiMeshInstance3D:
	var disc := CylinderMesh.new()
	disc.top_radius = 0.4
	disc.bottom_radius = 0.4
	disc.height = 0.02
	disc.radial_segments = 12
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.mesh = disc
	many.instance_count = level.cells.size()
	var shown := MultiMeshInstance3D.new()
	shown.multimesh = many
	var material := StandardMaterial3D.new()
	material.albedo_color = InfiltrationDrawing.PARTICLE
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shown.material_override = material
	parent.add_child(shown)
	return shown


## Size each cell's dot by the share of the cloud on it: its area grows
## with the share, the fullest cell's dot fills its tile, and a cell with
## no particle has none.
static func size_dots(shown: MultiMeshInstance3D, level: InfiltrationLevel, shares: PackedFloat64Array) -> void:
	var most: float = 0.0
	for share: float in shares:
		most = maxf(most, share)
	for index: int in range(level.cells.size()):
		var size: float = sqrt(shares[index] / most) if most > 0.0 else 0.0
		var place: Vector3 = level.arena.above(BotArena.centre_of(level.cells[index]), 0.06)
		shown.multimesh.set_instance_transform(index, Transform3D(Basis().scaled(Vector3(size, 1.0, size)), place))
