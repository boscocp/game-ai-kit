## The board as a graph: cells, what it costs to enter one, and what is next to it.
##
## This is the whole world every other addon reasons about. A* needs neighbours
## and a cost; STRIPS needs to know what is reachable; the learned policy needs
## the same board the player sees. One type, so they cannot disagree.
##
## Cost is the cost of *entering* a cell, never of leaving it, because that is
## the convention every search in this kit relies on and mixing the two is the
## classic off-by-one-edge in pathfinding code.
##
## Queries are O(1); `neighbours` is O(1) with four cardinal directions. There
## is no search here on purpose -- `ai_core` holds types, not algorithms.
##
## When not to use it: a hex board, a navigation mesh, or anything where a cell
## is not an integer coordinate. This is a square grid and says so.
class_name GridGraph
extends RefCounted

## A cell nothing may enter. Kept distinct from a high cost, because "expensive"
## and "impossible" are different answers and a search that confuses them will
## happily plan a route through a wall and then charge you for it.
const BLOCKED: int = -1

## What a cell costs to enter when nobody has said otherwise.
const DEFAULT_COST: int = 1

## The four cardinal directions, in a fixed order, so a search that breaks ties
## by insertion order behaves the same on every run. A test that depends on an
## arbitrary iteration order is a test that fails on another machine.
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]

var width: int
var height: int

# Row-major, one entry per cell. A flat array rather than a dictionary of
# Vector2i: the board is dense, every cell has a cost, and a flat array is the
# shape a reader can picture.
var _costs: PackedInt32Array


func _init(grid_width: int, grid_height: int, cost: int = DEFAULT_COST) -> void:
	width = grid_width
	height = grid_height
	_costs = PackedInt32Array()
	_costs.resize(width * height)
	_costs.fill(cost)


## True when the cell is on the board at all.
##
## Separate from `is_blocked` deliberately: off-board and blocked are different
## failures, and a caller that cannot tell them apart writes a worse message.
func contains(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


## What it costs to enter this cell, or `BLOCKED`.
##
## A cell off the board answers `BLOCKED` rather than failing: a search walks
## off the edge constantly and an error there would be noise, not information.
func cost_at(cell: Vector2i) -> int:
	if not contains(cell):
		return BLOCKED
	return _costs[cell.y * width + cell.x]


## Set what it costs to enter this cell. Off-board is ignored, not an error.
func set_cost(cell: Vector2i, cost: int) -> void:
	if not contains(cell):
		return
	_costs[cell.y * width + cell.x] = cost


## Make this cell impassable.
func block(cell: Vector2i) -> void:
	set_cost(cell, BLOCKED)


## True when nothing may enter this cell, including because it is off the board.
func is_blocked(cell: Vector2i) -> bool:
	return cost_at(cell) == BLOCKED


## The cells reachable in one step, blocked and off-board ones already dropped.
##
## Returning only passable neighbours is what lets a search read like the
## pseudocode in the book: the filtering is the graph's job, not the search's.
func neighbours(cell: Vector2i) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for direction: Vector2i in DIRECTIONS:
		var step: Vector2i = cell + direction
		if not is_blocked(step):
			found.append(step)
	return found


## An independent copy. Used wherever a caller must not see the board change.
func duplicate_graph() -> GridGraph:
	var copy := GridGraph.new(width, height)
	copy._costs = _costs.duplicate()
	return copy
