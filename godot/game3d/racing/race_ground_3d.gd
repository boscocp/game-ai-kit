## What the wheels stand on: tarmac, grass, and a test pad of tarmac.
##
## Every surface is a `StaticBody3D` on `RaceCar3D.GROUND_LAYER`, and says
## what it is through two metadata values a tyre reads where its ray lands:
## `grip`, multiplying the tyre's own, and `rolling`, the drag of the
## surface as a fraction of the load. Nothing else about the ground is known
## to a car, and nothing about it at all to a driver: grass is slower because
## the tyres hold less on it, not because a rule says so.
##
## The grass is a box whose top is `GRASS_DROP` below the tarmac, so a
## wheel's ray finds the tarmac where there is tarmac and the grass
## everywhere else. The drop is a centimetre: a wheel leaving the road does
## not feel a step.
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
	_add_box(body, box, Vector3(centre.x, -0.5, centre.y), ROAD_COLOUR if drawn else Color.TRANSPARENT)
	return body


static func _surface(title: String, grip: float, rolling: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = title
	body.collision_layer = RaceCar3D.GROUND_LAYER
	body.collision_mask = 0
	body.set_meta("grip", grip)
	body.set_meta("rolling", rolling)
	return body


static func _add_box(body: StaticBody3D, size: Vector3, at: Vector3, colour: Color) -> void:
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
		drawn.position = at
		drawn.material_override = _material(colour)
		body.add_child(drawn)


static func _material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
