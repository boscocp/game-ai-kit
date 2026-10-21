## What a person sees of a track: the tarmac, the grass, the racing line
## and the things beside the road.
##
## The road and the grass are `RaceGround3D`'s, the same bodies the wheels
## stand on. The racing line is drawn as a thin strip just above the road,
## because the line is what every driver here reasons with and invariant 13
## puts the reasoning on screen. Beside the road go trees and a grandstand
## from Kenney's Racing Kit when `make assets-3d` has fetched it, and plain
## shapes when it has not (ADR 0018): nothing a driver decides by is here.
##
## When not to use it: in a check that only races. The checks build the
## ground alone (`RaceGround3D.road`, undrawn), with nothing to look at.
class_name RaceScenery3D
extends RefCounted

const LINE_COLOUR: Color = Color(1.0, 0.85, 0.2)
const LINE_WIDTH: float = 0.35
## Trees stand at least this far from the edge of the tarmac, in metres,
## one every TREE_EVERY metres of track, alternating sides.
const TREE_CLEARANCE: float = 12.0
const TREE_EVERY: float = 45.0
const TREE_HEIGHT: float = 9.0
const STAND_HEIGHT: float = 6.0


## The track's ground, its racing line and its scenery, under `parent`.
static func build(track: RaceTrack3D, shelf: AssetShelf, parent: Node3D) -> void:
	parent.add_child(RaceGround3D.grass(true))
	parent.add_child(RaceGround3D.road(track, true))
	parent.add_child(racing_line(track))
	_add_trees(track, shelf, parent)
	_add_stand(track, shelf, parent)


## The racing line as a strip on the road, two centimetres up.
static func racing_line(track: RaceTrack3D) -> MeshInstance3D:
	var faces := PackedVector3Array()
	for index: int in range(track.line.size()):
		var next: int = track.wrapped(index + 1)
		var here: Vector2 = track.line[index]
		var there: Vector2 = track.line[next]
		var across: Vector2 = RaceTrack3D.left_of(here.direction_to(there)) * LINE_WIDTH / 2.0
		faces.append_array([_up(here + across), _up(here - across), _up(there - across),
			_up(here + across), _up(there - across), _up(there + across)])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = faces
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var drawn := MeshInstance3D.new()
	drawn.name = "RacingLine"
	drawn.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = LINE_COLOUR
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	drawn.material_override = material
	return drawn


static func _up(at: Vector2) -> Vector3:
	return Vector3(at.x, 0.02, at.y)


# A tree every TREE_EVERY metres, on alternating sides, kept off any part of
# the track that comes close.
static func _add_trees(track: RaceTrack3D, shelf: AssetShelf, parent: Node3D) -> void:
	var every: int = roundi(TREE_EVERY / RaceTrack3D.SPACING)
	for index: int in range(0, track.centre.size(), every):
		var side: float = 1.0 if (index / every) % 2 == 0 else -1.0
		var at: Vector2 = track.centre[index] + track.left[index] * side * (track.half_width + TREE_CLEARANCE)
		if _clear_of_road(track, at, TREE_CLEARANCE * 0.8):
			var tree: Node3D = shelf.model("trackside_tree", TREE_HEIGHT, Color(0.2, 0.45, 0.2))
			tree.position = Vector3(at.x, 0.0, at.y)
			parent.add_child(tree)


# A grandstand beside the start line, on the outside.
static func _add_stand(track: RaceTrack3D, shelf: AssetShelf, parent: Node3D) -> void:
	var at: Vector2 = track.centre[0] - track.left[0] * (track.half_width + 10.0)
	var stand: Node3D = shelf.model("trackside_grandstand", STAND_HEIGHT, Color(0.6, 0.6, 0.65))
	stand.position = Vector3(at.x, 0.0, at.y)
	var along: Vector2 = track.centre[0].direction_to(track.centre[1])
	stand.rotation.y = atan2(-along.x, -along.y)
	parent.add_child(stand)


# Whether `at` is at least `clearance` metres from the tarmac everywhere.
static func _clear_of_road(track: RaceTrack3D, at: Vector2, clearance: float) -> bool:
	var index: int = track.nearest_anywhere(at)
	return at.distance_to(track.centre[index]) >= track.half_width + clearance
