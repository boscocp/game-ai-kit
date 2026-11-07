## The infiltration level's doors in 3D (T115): a panel on each box face
## the level names, shut flat against it, or swung out a quarter turn and
## lit orange while it stands open -- the sign a guard may find.
##
## A door is hinged at one edge, so opening it is a turn of its hinge. It
## stands where `InfiltrationLevel.doors` says: half a cell from the walk
## cell's centre, against the box it faces out of. The hinge's local x
## points out of the box and its local z along the face, so the panel lies
## flat at a turn of `-faces` and swings out at a quarter turn more.
##
## When not to use it: as the door's state. That is `InfiltrationWorld`'s
## `doors_open`; this only shows it.
class_name DoorDrawing
extends Node3D

const SHUT: Color = Color(0.45, 0.3, 0.2)
const OPEN: Color = Color(1.0, 0.55, 0.15)
const WIDTH: float = 0.9
const HEIGHT: float = 2.1
const THICKNESS: float = 0.08
## How far the door's face stands from its walk cell's centre: the cell's half.
const FROM_CENTRE: float = 0.5

var _hinges: Array[Node3D] = []
var _panels: Array[MeshInstance3D] = []


## A hinge and a panel for each of `level`'s doors, all shut.
func build(level: InfiltrationLevel) -> void:
	for door: Dictionary in level.doors:
		var faces: float = float(door["faces"])
		var outward := Vector2.from_angle(faces)
		var face: Vector2 = Vector2(door["place"]) - outward * FROM_CENTRE
		var hinge := Node3D.new()
		hinge.position = level.arena.above(face + outward.orthogonal() * (WIDTH / 2.0), 0.0)
		hinge.rotation.y = -faces
		var panel := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(THICKNESS, HEIGHT, WIDTH)
		panel.mesh = mesh
		panel.position = Vector3(THICKNESS, HEIGHT / 2.0, WIDTH / 2.0)
		panel.material_override = StandardMaterial3D.new()
		hinge.add_child(panel)
		add_child(hinge)
		_hinges.append(hinge)
		_panels.append(panel)


## Each door shut or swung open, as `world` has it.
func refresh(world: InfiltrationWorld) -> void:
	for index: int in range(_hinges.size()):
		var open: bool = world.doors_open[index]
		_hinges[index].rotation.y = -float(world.level.doors[index]["faces"]) + (PI / 2.0 if open else 0.0)
		(_panels[index].material_override as StandardMaterial3D).albedo_color = OPEN if open else SHUT
