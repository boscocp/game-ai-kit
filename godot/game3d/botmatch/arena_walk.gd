## The bot match's walk grid with height in it, as the graph A* searches.
##
## The grid says which cells a body fits in; this adds that a bot walks from
## one cell to a neighbour only when the floor between them rises or falls by
## `max_rise` at most. So the way onto a platform is up its stair, one step a
## cell, and never up the platform's side -- a grid that knew only open and
## blocked would take the side, the shortest way, and the bot would walk up
## a wall. `botmatch_test.gd` shows that happening on the plain grid.
##
## It is T62's port, `SearchGraph`, so the searches in `ai_search` run over
## it unchanged. Every step costs one, as on the grid, and the estimate is
## Manhattan distance, consistent for the grid's reason: no step costs less.
##
## When not to use it: a bot that may drop off an edge it cannot climb. Then
## a step down is allowed and the same step up is not, the graph is directed,
## and the mirror that keeps the match fair has to be checked again.
class_name ArenaWalk
extends SearchGraph

var grid: GakGridGraph
## Each cell's floor height, row-major like the grid.
var heights: PackedFloat64Array
var max_rise: float = 0.0


func _init(over: GakGridGraph, floor_heights: PackedFloat64Array, rise: float) -> void:
	grid = over
	heights = floor_heights
	max_rise = rise


## True when the cell is on the grid.
func contains(node: Vector2i) -> bool:
	return grid.contains(node)


## The open cardinal neighbours whose floor is within a step of this one's.
func neighbours(node: Vector2i) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for next: Vector2i in grid.neighbours(node):
		if absf(height_of(next) - height_of(node)) <= max_rise:
			found.append(next)
	return found


## What the grid says this cell costs to enter.
func cost_at(node: Vector2i) -> int:
	return grid.cost_at(node)


## Manhattan distance: consistent, because every step costs at least one.
func estimate(node: Vector2i, goal: Vector2i) -> int:
	return absi(node.x - goal.x) + absi(node.y - goal.y)


## The floor height of a cell on the grid.
func height_of(node: Vector2i) -> float:
	return heights[node.y * grid.width + node.x]
