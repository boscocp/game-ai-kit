## One unit walking its route, cell by cell, over a fraction of a second.
##
## The rules move a unit at once: one state has it here, the next has it
## there. A person watching needs it to go along the route the rules chose, or
## the board reads as pieces teleporting. So the view keeps one of these per
## unit on the move, and asks it where the unit is *now*, between two cells.
##
## Time is handed in, never read from a clock, so a test can stop the walk
## partway and look -- headless, nothing is drawn, and this is what is left to
## hold.
##
## When not to use it: movement the rules themselves treat as continuous, such
## as T22's steering. There the position is the state, not a picture of it.
class_name UnitWalk
extends RefCounted

## How long one step takes. A five-cell walk is over in a little more than
## half a second: long enough to follow, short enough not to wait for.
const SECONDS_PER_CELL: float = 0.12

## Every cell the walk passes through: where it started, then each step.
var route: Array[Vector2i] = []
## How long it has been walking.
var elapsed: float = 0.0


## A walk from `start` along `path`, the cells a `Move` names after the start.
func _init(start: Vector2i, path: Array[Vector2i]) -> void:
	route.append(start)
	route.append_array(path)


## How long the whole walk takes.
func duration() -> float:
	return (route.size() - 1) * SECONDS_PER_CELL


## True once the unit stands on its last cell.
func finished() -> bool:
	return elapsed >= duration()


## The cell the walk ends on.
func destination() -> Vector2i:
	return route[route.size() - 1]


## Where the unit is, on a board whose cell centres `centre_of` gives:
## part of the way from the cell it last reached to the next one.
func point(centre_of: Callable) -> Vector2:
	if finished():
		return centre_of.call(destination())
	var progress: float = elapsed / SECONDS_PER_CELL
	var leg: int = int(progress)
	var from: Vector2 = centre_of.call(route[leg])
	return from.lerp(centre_of.call(route[leg + 1]), progress - leg)


## The way the unit faces: the direction of the step it is taking, or of its
## last step once it has arrived. Zero for a walk that goes nowhere.
func facing() -> Vector2i:
	if route.size() < 2:
		return Vector2i.ZERO
	var leg: int = mini(int(elapsed / SECONDS_PER_CELL), route.size() - 2)
	return (route[leg + 1] - route[leg]).sign()
