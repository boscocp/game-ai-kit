## What the wheels stand on: tarmac, grass, and a test pad of tarmac.
##
## Every surface is a `StaticBody3D` on `RaceCar3D.GROUND_LAYER`, and says
## what it is through two metadata values a tyre reads where its ray lands:
## `grip`, multiplying the tyre's own, and `rolling`, the drag of the
## surface as a fraction of the load. Nothing else about the ground is known
## to a car, and nothing about it at all to a driver: grass is slower because
## the tyres hold less on it, not because a rule says so.
##
## The road is one triangle strip along the track, at y = 0, and the grass a
## box whose top is `GRASS_DROP` below it, so a wheel's ray finds the road
## where there is road and the grass everywhere else. The drop is a
## centimetre: a wheel leaving the road does not feel a step.
##
## When not to use it: a road that climbs. This one is flat, and so is every
## speed limit computed on it.
class_name RaceGround3D
extends RefCounted

const TARMAC_GRIP: float = 1.0
const TARMAC_ROLLING: float = 0.015
const GRASS_GRIP: float = 0.6
const GRASS_ROLLING: float = 0.12
const GRASS_DROP: float = 0.01
## The grass, in metres a side: room for every track and the test pad.
const GRASS_SIZE: float = 8000.0
const ROAD_COLOUR: Color = Color(0.22, 0.22, 0.24)
const GRASS_COLOUR: Color = Color(0.28, 0.5, 0.22)
const KERB_COLOUR: Color = Color(0.85, 0.85, 0.85)


## The grass under everything, drawn when `drawn`.
static func grass(drawn: bool) -> StaticBody3D:
	var body: StaticBody3D = _surface("Grass", GRASS_GRIP, GRASS_ROLLING)
	var size := Vector3(GRASS_SIZE, 1.0, GRASS_SIZE)
	_add_box(body, size, Vector3(0, -0.5 - GRASS_DROP, 0), GRASS_COLOUR if drawn else Color.TRANSPARENT)
	return body


## A flat square of tarmac `size` metres a side, its top at y = 0, centred
## on `centre` on the map: where a driver measures its car before a race.
static func pad(size: float, centre: Vector2, drawn: bool) -> StaticBody3D:
	var body: StaticBody3D = _surface("TestPad", TARMAC_GRIP, TARMAC_ROLLING)
	var box := Vector3(size, 1.0, size)
	# Drawn fifteen centimetres up, the collider where it is: from a camera
	# a hundred metres away, a few centimetres over the grass flicker into it.
	_add_box(body, box, Vector3(centre.x, -0.5, centre.y), ROAD_COLOUR if drawn else Color.TRANSPARENT, 0.15)
	return body


## The track's tarmac: one quad from each centre sample to the next, the
## half width either side. Drawn with white edges when `drawn`.
static func road(track: RaceTrack3D, drawn: bool) -> StaticBody3D:
	var body: StaticBody3D = _surface("Road", TARMAC_GRIP, TARMAC_ROLLING)
	var faces := PackedVector3Array()
	for index: int in range(track.centre.size()):
		var next: int = track.wrapped(index + 1)
		_quad(faces, _edge(track, index, 1.0), _edge(track, index, -1.0),
			_edge(track, next, 1.0), _edge(track, next, -1.0))
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var holder := CollisionShape3D.new()
	holder.shape = shape
	body.add_child(holder)
	if drawn:
		body.add_child(_mesh_of(faces, ROAD_COLOUR))
		body.add_child(_kerbs(track))
	return body


static func _surface(title: String, grip: float, rolling: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = title
	body.collision_layer = RaceCar3D.GROUND_LAYER
	body.collision_mask = 0
	body.set_meta("grip", grip)
	body.set_meta("rolling", rolling)
	return body


static func _add_box(body: StaticBody3D, size: Vector3, at: Vector3, colour: Color, lift: float = 0.0) -> void:
	var holder := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	holder.shape = box
	holder.position = at
	body.add_child(holder)
	if colour.a > 0.0:
		var drawn := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = size
		drawn.mesh = mesh
		drawn.position = at + Vector3(0.0, lift, 0.0)
		drawn.material_override = _material(colour)
		body.add_child(drawn)


# The point `side` half widths left of the centre at sample `index` (1 the
# left edge, -1 the right), at `height` above the road.
static func _edge(track: RaceTrack3D, index: int, side: float, height: float = 0.0) -> Vector3:
	var at: Vector2 = track.centre[index] + track.left[index] * track.half_width * side
	return Vector3(at.x, height, at.y)


# Two triangles, wound so their faces look up.
static func _quad(faces: PackedVector3Array, left_here: Vector3, right_here: Vector3,
		left_next: Vector3, right_next: Vector3) -> void:
	faces.append_array([left_here, right_here, right_next, left_here, right_next, left_next])


# A white strip half a metre wide along each edge, a centimetre up.
static func _kerbs(track: RaceTrack3D) -> MeshInstance3D:
	var faces := PackedVector3Array()
	var inner: float = 1.0 - 0.5 / track.half_width
	for index: int in range(track.centre.size()):
		var next: int = track.wrapped(index + 1)
		_quad(faces, _edge(track, index, 1.0, 0.01), _edge(track, index, inner, 0.01),
			_edge(track, next, 1.0, 0.01), _edge(track, next, inner, 0.01))
		_quad(faces, _edge(track, index, -inner, 0.01), _edge(track, index, -1.0, 0.01),
			_edge(track, next, -inner, 0.01), _edge(track, next, -1.0, 0.01))
	return _mesh_of(faces, KERB_COLOUR)


static func _mesh_of(faces: PackedVector3Array, colour: Color) -> MeshInstance3D:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = faces
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var drawn := MeshInstance3D.new()
	drawn.mesh = mesh
	drawn.material_override = _material(colour)
	return drawn


static func _material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
