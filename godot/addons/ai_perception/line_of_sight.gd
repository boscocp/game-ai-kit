## Can one cell see another? Draw the line between them; nothing opaque on it.
##
## Opaque is a wall, or ground at least `opaque_from_cost` dear to enter: trees
## cost movement *and* block sight, one map with two meanings. The line is
## Bresenham's, always drawn from the same end, so sight is symmetric by
## construction. Cost is one lookup per cell on the line: O(distance).
##
## When not to use it: partial cover, or a world that is not a grid. This is
## all or nothing, cell by cell.
class_name LineOfSight
extends RefCounted

## Ground this dear to enter blocks sight as well. Three is the board's tree.
const DEFAULT_OPAQUE_FROM_COST: int = 3


## True when nothing on this cell lets sight through.
static func is_opaque(graph: GridGraph, cell: Vector2i,
		opaque_from_cost: int = DEFAULT_OPAQUE_FROM_COST) -> bool:
	return graph.is_blocked(cell) or graph.cost_at(cell) >= opaque_from_cost


## True when `from` can see `to`: every cell strictly between them lets sight
## through. The two end cells are not asked -- a guard can see a player
## standing in a bush, which is what the bush is *for* in the light rules.
static func clear(graph: GridGraph, from: Vector2i, to: Vector2i,
		opaque_from_cost: int = DEFAULT_OPAQUE_FROM_COST) -> bool:
	for cell: Vector2i in cells_between(from, to):
		if is_opaque(graph, cell, opaque_from_cost):
			return false
	return true


## The cells a line from `from` to `to` passes through, ends excluded.
##
## Bresenham's line is not symmetric: drawn from A to B and from B to A, it can
## step through different cells where it crosses a corner, and a guard would
## then see a player who cannot see the guard. So the line is always drawn from
## the smaller end, and the same cells come back whichever way it is asked.
static func cells_between(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if _comes_after(from, to):
		return cells_between(to, from)
	var cells: Array[Vector2i] = []
	var cursor: Vector2i = from
	var across: int = absi(to.x - from.x)
	var down: int = -absi(to.y - from.y)
	var step := Vector2i(signi(to.x - from.x), signi(to.y - from.y))
	var error: int = across + down
	while true:
		var doubled: int = 2 * error
		if doubled >= down:
			error += down
			cursor.x += step.x
		if doubled <= across:
			error += across
			cursor.y += step.y
		if cursor == to:
			break
		cells.append(cursor)
	return cells


# The order the line is drawn in: by column, then by row.
static func _comes_after(one: Vector2i, other: Vector2i) -> bool:
	return one.x > other.x or (one.x == other.x and one.y > other.y)
