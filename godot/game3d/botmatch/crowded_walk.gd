## The walk graph with the bodies near a bot in it: their cells closed, for
## an A* that goes round them.
##
## `ArenaWalk` knows walls, boxes and heights, which never move; a body does,
## so it is not in the walk grid. When a bot is blocked by one, this wraps
## the walk for one search with the cells under the bodies near it closed --
## T62's port again, so the same A* answers. The detour it finds is one of
## the ways `PassageChoice` prices.
##
## When not to use it: to plan a whole route. The bodies will have moved
## long before a bot reaches the far end; this is for the next few metres.
class_name CrowdedWalk
extends GakSearchGraph

var walk: ArenaWalk
## Cells closed by a body, as a set.
var closed: Dictionary = {}


func _init(over: ArenaWalk, closed_cells: Array[Vector2i]) -> void:
	walk = over
	for cell: Vector2i in closed_cells:
		closed[cell] = true


## True when the cell is on the grid.
func contains(node: Vector2i) -> bool:
	return walk.contains(node)


## The walk's neighbours, less the cells a body stands in.
func neighbours(node: Vector2i) -> Array[Vector2i]:
	return walk.neighbours(node).filter(func(next: Vector2i) -> bool: return not closed.has(next))


## What the walk says this cell costs to enter.
func cost_at(node: Vector2i) -> int:
	return walk.cost_at(node)


## The walk's estimate, Manhattan distance: closing cells only makes a route
## dearer, so a guess that never overshot the walk does not overshoot this.
func estimate(node: Vector2i, goal: Vector2i) -> int:
	return walk.estimate(node, goal)
