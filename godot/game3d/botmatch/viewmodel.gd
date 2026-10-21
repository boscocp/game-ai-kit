## The rifle a person sees in their own hands while playing a bot: plain
## boxes at the bottom right of the view, as every first-person shooter has
## one, kicking back a little with each shot and settling again, and lowered
## and tipped while it reloads or the person sprints, so a rifle that cannot
## fire looks it. Seen only; the shot itself leaves from the eyes.
class_name Viewmodel
extends Node3D

## Where it rests, in the camera's space: right, down and ahead.
const REST: Vector3 = Vector3(0.22, -0.2, -0.45)
## How far a shot kicks it back, and how fast it settles, per second.
const KICK: float = 0.05
const SETTLE: float = 12.0
## Lowered all the way: this much down, and tipped this far.
const LOWER: Vector3 = Vector3(-0.05, -0.18, 0.05)
const TIP: float = deg_to_rad(35.0)
## How fast it goes down or comes back up, a share a second.
const LOWERING: float = 6.0
const BODY: Color = Color(0.18, 0.18, 0.2)
const METAL: Color = Color(0.35, 0.35, 0.38)

var _kicked: float = 0.0
## How far lowered it is now, 0 to 1, and how far it is going.
var _lowered: float = 0.0
## Whether the rifle cannot fire now: reloading or sprinting.
var lowered: bool = false


func _ready() -> void:
	position = REST
	_part(Vector3(0.06, 0.08, 0.36), Vector3(0, 0, 0), BODY)
	_part(Vector3(0.025, 0.025, 0.3), Vector3(0, 0.015, -0.3), METAL)
	_part(Vector3(0.04, 0.12, 0.05), Vector3(0, -0.09, 0.06), BODY)
	_part(Vector3(0.035, 0.1, 0.06), Vector3(0, -0.08, -0.1), METAL)


## Kick it back, as a shot leaves.
func fire() -> void:
	_kicked = KICK


func _process(delta: float) -> void:
	_kicked = move_toward(_kicked, 0.0, SETTLE * KICK * delta)
	_lowered = move_toward(_lowered, 1.0 if lowered else 0.0, LOWERING * delta)
	position = REST + Vector3(0, _kicked * 0.3, _kicked) + LOWER * _lowered
	rotation = Vector3(_kicked * 2.0 - TIP * _lowered * 0.5, 0, TIP * _lowered)


func _part(size: Vector3, place: Vector3, colour: Color) -> void:
	var look: Node3D = AssetShelf.primitive("box", 1.0, colour)
	look.scale = size
	look.position = place - Vector3(0, size.y / 2.0, 0)
	add_child(look)
