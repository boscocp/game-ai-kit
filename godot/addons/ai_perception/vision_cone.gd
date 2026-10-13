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

## Half the cone's opening. 45 opens a quarter of the circle, by angle; on a
## grid that is fewer cells than a quarter of the disc, because the cells on
## the axis behind the eye count for no quadrant.
var half_angle_degrees: float

var opaque_from_cost: int


func _init(cone_reach: float, cone_half_angle_degrees: float,
		cone_opaque_from_cost: int = LineOfSight.DEFAULT_OPAQUE_FROM_COST) -> void:
	reach = cone_reach
	half_angle_degrees = cone_half_angle_degrees
	opaque_from_cost = cone_opaque_from_cost


## True when a watcher at `eye`, facing `facing`, sees `target`.
##
## A watcher always sees its own cell, whatever its reach. A target off the
## board is never seen. A zero `facing` means facing nowhere in particular, and
## the angle test is skipped: a watcher looking round sees the whole circle.
func sees(graph: GridGraph, eye: Vector2i, facing: Vector2i, target: Vector2i) -> bool:
	if target == eye:
		return true
	if not graph.contains(target):
		return false
	var offset := Vector2(target - eye)
	if offset.length() > reach:
		return false
	if facing != Vector2i.ZERO and not _within_angle(Vector2(facing), offset):
		return false
	return LineOfSight.clear(graph, eye, target, opaque_from_cost)


## How near `target` is, from 1 at the eye to 0 at the edge of reach.
##
## Distance only; whether it is seen at all is `sees`. Kept apart because the
## influence map wants "how watched is this cell", and a cell seen at the edge
## of sight is watched less than one under the guard's nose. The eye is
## answered first: with no reach, 0 / 0 there was NaN, and everywhere else the
## clamp already turns a division by zero into 0.
func closeness(eye: Vector2i, target: Vector2i) -> float:
	if target == eye:
		return 1.0
	return clampf(1.0 - Vector2(target - eye).length() / reach, 0.0, 1.0)


## Every cell on the board this watcher sees, the eye included.
func visible_cells(graph: GridGraph, eye: Vector2i, facing: Vector2i) -> Array[Vector2i]:
	var seen: Array[Vector2i] = []
	for cell: Vector2i in _square_around(eye, ceili(reach)):
		if graph.contains(cell) and sees(graph, eye, facing, cell):
			seen.append(cell)
	return seen


# Inside the cone's opening, a cell exactly on its edge included.
#
# Compared as cosines with a margin, because the angle itself is not exact:
# the diagonal measures 45.00000125 degrees, and a 45-degree cone tested with
# `angle_to` left out every cell on its own edge. The margin is 1e-6 because
# `Vector2` is single precision: 1e-9 was still too tight, and a test said so.
func _within_angle(facing: Vector2, offset: Vector2) -> bool:
	var edge: float = cos(deg_to_rad(half_angle_degrees))
	return facing.normalized().dot(offset.normalized()) >= edge - 1e-6


# Every cell within `span` columns and rows of `eye`, on the board or not.
func _square_around(eye: Vector2i, span: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y: int in range(eye.y - span, eye.y + span + 1):
		for x: int in range(eye.x - span, eye.x + span + 1):
			cells.append(Vector2i(x, y))
	return cells
