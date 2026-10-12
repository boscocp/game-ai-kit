## One unit's proposed walk, step by step.
##
## The path is carried by the move rather than worked out by the board, and that
## split is the reason `ai_core` can hold no algorithms: whoever wants to move
## supplies the route, and the board only rules on whether it is legal. A*, a
## planner and a human clicking a tile all produce the same type.
##
## The path excludes the starting cell and lists every cell entered, in order.
## Listing the start was the first design and it made every cost calculation
## carry an "except the first one" clause, which is where mistakes live.
##
## When not to use it: an attack, a build order, anything that is not a walk.
## Those are separate types, and squeezing them in here as a flag is how a
## clean board state turns into a switch statement.
class_name Move
extends RefCounted

var unit_id: int

## Cells entered, in order, not including where the unit started.
var path: Array[Vector2i]


func _init(moving_unit_id: int, cells: Array[Vector2i]) -> void:
	unit_id = moving_unit_id
	path = cells.duplicate()


## Where the unit ends up, or `fallback` when the move goes nowhere.
##
## A move with an empty path is legal and means "stay": a turn in which a unit
## holds its ground is a decision, and the AI lessons need to be able to make
## it.
func destination(fallback: Vector2i) -> Vector2i:
	if path.is_empty():
		return fallback
	return path[path.size() - 1]


## What this walk costs on `graph`, or `GridGraph.BLOCKED` if any step is.
##
## Cost is summed over entered cells, which is why the path excludes the start:
## you never pay to stand where you already are.
func cost_on(graph: GridGraph) -> int:
	var total: int = 0
	for cell: Vector2i in path:
		var step_cost: int = graph.cost_at(cell)
		if step_cost == GridGraph.BLOCKED:
			return GridGraph.BLOCKED
		total += step_cost
	return total
