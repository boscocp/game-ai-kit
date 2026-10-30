## The square grid from `ai_core`, seen through the port the searches ask.
##
## Three of the four answers are the grid's own, passed through. The fourth,
## A\*'s estimate, is Manhattan distance, and it lives here rather than in
## `astar.gd` because whether it is safe is a fact about the grid, not about A\*.
##
## A wrapper, not a copy: it holds the grid it was given, so a cell blocked
## after it was made is blocked to the next search too.
##
## When not to use it: a graph that is not a square grid of cells. Write your
## own `GakSearchGraph`; this file is the example of how short that is.
class_name GridSearchGraph
extends GakSearchGraph

## The grid every answer comes from.
var grid: GakGridGraph


func _init(over: GakGridGraph) -> void:
	grid = over


## True when the cell is on the board.
func contains(node: Vector2i) -> bool:
	return grid.contains(node)


## The cardinal neighbours that are on the board and not blocked.
func neighbours(node: Vector2i) -> Array[Vector2i]:
	return grid.neighbours(node)


## What the grid says this cell costs to enter.
func cost_at(node: Vector2i) -> int:
	return grid.cost_at(node)


## Manhattan distance: the cardinal steps between two cells with nothing in
## the way.
##
## Consistent, which is the promise `GakSearchGraph.estimate` asks for, **because
## no cell costs less than one to enter**: one step changes the distance by
## exactly one, and entering any cell costs at least that. `GakGridGraph.set_cost`
## clamps every cost below one to one, so a board that would break this cannot
## be built.
func estimate(node: Vector2i, goal: Vector2i) -> int:
	return absi(node.x - goal.x) + absi(node.y - goal.y)
