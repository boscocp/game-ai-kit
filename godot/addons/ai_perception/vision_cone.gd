## What a watcher sees: near enough, within the angle it faces, nothing in the way.
##
## Three tests, cheapest first -- distance, then angle, then the line of sight
## that walks the cells -- so most of the board is turned away before the
## expensive one runs. `visible_cells` asks every cell within reach: O(reach²
## x reach), which is a few hundred line walks on this board.
##
## When not to use it: hundreds of watchers on a big map. Cast rays outwards
## once per watcher, or use the engine's physics, rather than asking each cell.
class_name VisionCone
extends RefCounted

## How far it sees, in cells, measured centre to centre.
var reach: float

## Half the cone's opening. 45 sees a quarter of the circle.
var half_angle_degrees: float

var opaque_from_cost: int


func _init(cone_reach: float, cone_half_angle_degrees: float,
		cone_opaque_from_cost: int = LineOfSight.DEFAULT_OPAQUE_FROM_COST) -> void:
	reach = cone_reach
	half_angle_degrees = cone_half_angle_degrees
	opaque_from_cost = cone_opaque_from_cost


## True when a watcher at `eye`, facing `facing`, sees `target`.
##
## A watcher always sees its own cell. A zero `facing` means it is facing
## nowhere in particular, and the angle test is skipped: a watcher looking
## round sees the whole circle within reach.
func sees(graph: GridGraph, eye: Vector2i, facing: Vector2i, target: Vector2i) -> bool:
	if target == eye:
		return true
	var offset := Vector2(target - eye)
	if offset.length() > reach:
		return false
	if facing != Vector2i.ZERO:
		var turn: float = absf(rad_to_deg(Vector2(facing).angle_to(offset)))
		if turn > half_angle_degrees:
			return false
	return LineOfSight.clear(graph, eye, target, opaque_from_cost)


## How near `target` is, from 1 at the eye to 0 at the edge of reach.
##
## Distance only; whether it is seen at all is `sees`. Kept apart because the
## influence map wants "how watched is this cell", and a cell seen at the edge
## of sight is watched less than one under the guard's nose.
func closeness(eye: Vector2i, target: Vector2i) -> float:
	return clampf(1.0 - Vector2(target - eye).length() / reach, 0.0, 1.0)


## Every cell on the board this watcher sees, the eye included.
func visible_cells(graph: GridGraph, eye: Vector2i, facing: Vector2i) -> Array[Vector2i]:
	var seen: Array[Vector2i] = []
	for cell: Vector2i in _square_around(eye, ceili(reach)):
		if graph.contains(cell) and sees(graph, eye, facing, cell):
			seen.append(cell)
	return seen


# Every cell within `span` columns and rows of `eye`, on the board or not.
func _square_around(eye: Vector2i, span: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y: int in range(eye.y - span, eye.y + span + 1):
		for x: int in range(eye.x - span, eye.x + span + 1):
			cells.append(Vector2i(x, y))
	return cells
