## One board to start the search demo from, drawn as text, with the lesson it
## is there to show written beside it.
##
## Each named board makes a promise -- "A* expands fewer cells than Dijkstra
## here", "depth-first's route costs more" -- and carries the check that keeps
## it. A board is only worth naming if the four searches do something on it a
## person would not guess, and the check is how a test finds out that an edit
## to the layout quietly took the lesson away.
##
## The layout is rows of characters because that is the form a reader can
## picture without running anything: `#` a wall, `.` open ground, a digit from
## 2 to 9 mud costing that much, `S` the start and `G` the goal.
##
## When not to use it: a board bigger than a screen of text. At that size it
## belongs in a file of its own, read at load time.
class_name SearchBoard
extends RefCounted

## Which result is which, in every list of four this file is handed. The same
## order as `SearchDemo.NAMES`.
const BREADTH_FIRST: int = 0
const DEPTH_FIRST: int = 1
const DIJKSTRA: int = 2
const ASTAR: int = 3

var name: String
## What the board shows, in a sentence, for the screen.
var promise: String
var rows: Array[String]
# Takes the four results in the order above and says whether the promise held.
var _check: Callable


func _init(board_name: String, board_promise: String, board_rows: Array[String],
		check: Callable) -> void:
	name = board_name
	promise = board_promise
	rows = board_rows
	_check = check


## The boards the demo offers, in the order B steps through them.
static func named() -> Array[SearchBoard]:
	return [
		SearchBoard.new("wall and mud",
			"Dijkstra goes round the mud breadth-first wades through; A* takes the same route and looks at less",
			_wall_and_mud(), _astar_saves_work_round_the_mud),
		SearchBoard.new("maze",
			"one way through: all four find the same route, and only the work differs",
			_maze(), _every_route_costs_the_same),
		SearchBoard.new("open field",
			"nothing in the way: A* heads for the goal and expands under a quarter of what Dijkstra does",
			_open_field(), _astar_expands_under_a_quarter),
		SearchBoard.new("depth-first trap",
			"the goal is two cells away, but depth-first tries left first: its route costs more than Dijkstra's",
			_depth_first_trap(), _depth_first_pays_more),
	] as Array[SearchBoard]


## The board as a graph: walls blocked, mud at its digit, the rest open.
func graph() -> GridGraph:
	var built := GridGraph.new(rows[0].length(), rows.size())
	for row: int in range(rows.size()):
		for column: int in range(rows[row].length()):
			built.set_cost(Vector2i(column, row), cost_of(rows[row][column]))
	return built


## Where the `S` is.
func start() -> Vector2i:
	return _find("S")


## Where the `G` is.
func goal() -> Vector2i:
	return _find("G")


## True when the four results, in `SearchDemo.NAMES` order, keep this board's
## promise.
func promise_holds(results: Array[SearchResult]) -> bool:
	return _check.call(results)


## What one character of a layout costs to enter.
static func cost_of(character: String) -> int:
	if character == "#":
		return GridGraph.BLOCKED
	if character.is_valid_int():
		return character.to_int()
	return GridGraph.DEFAULT_COST


func _find(marker: String) -> Vector2i:
	for row: int in range(rows.size()):
		var column: int = rows[row].find(marker)
		if column >= 0:
			return Vector2i(column, row)
	return Vector2i(-1, -1)


# The demo's original board: a band of mud across the middle and a wall with
# one gap, at the bottom.
static func _wall_and_mud() -> Array[String]:
	return [
		"........#.......",
		"........#.......",
		"........#.......",
		"........#.......",
		"........#.......",
		"8S888888#88888G8",
		"........#.......",
		"........#.......",
		"........#.......",
		"................",
		"................",
	] as Array[String]


# A perfect maze: every open cell is reached by exactly one route, so there
# is only one answer and every search must find it.
static func _maze() -> Array[String]:
	return [
		".....#........G#",
		".#.###.###.#####",
		".#.....#.#.....#",
		".#######.#####.#",
		"...#.....#.....#",
		"##.#.#.###.###.#",
		".....#.#...#.#.#",
		"######.#.###.#.#",
		"...#...#.#...#.#",
		".#.#####.#.###.#",
		"S#.......#.....#",
	] as Array[String]


static func _open_field() -> Array[String]:
	return [
		"................",
		"................",
		"................",
		"................",
		"................",
		".S............G.",
		"................",
		"................",
		"................",
		"................",
		"................",
	] as Array[String]


# The goal is two cells to the right. Depth-first pushes its neighbours up,
# right, down, left and takes the last one pushed, so it sets off left and
# sweeps the board before it comes back.
static func _depth_first_trap() -> Array[String]:
	return [
		"................",
		"................",
		"................",
		"................",
		"................",
		".......S.G......",
		"................",
		"................",
		"................",
		"................",
		"................",
	] as Array[String]


static func _astar_saves_work_round_the_mud(results: Array[SearchResult]) -> bool:
	return (results[DIJKSTRA].cost < results[BREADTH_FIRST].cost
		and results[ASTAR].cost == results[DIJKSTRA].cost
		and results[ASTAR].expanded.size() < results[DIJKSTRA].expanded.size())


static func _every_route_costs_the_same(results: Array[SearchResult]) -> bool:
	for result: SearchResult in results:
		if not result.reached or result.cost != results[DIJKSTRA].cost:
			return false
	return true


static func _astar_expands_under_a_quarter(results: Array[SearchResult]) -> bool:
	return (results[ASTAR].cost == results[DIJKSTRA].cost
		and results[ASTAR].expanded.size() * 4 < results[DIJKSTRA].expanded.size())


# The trap is the sweep, not only the dear route: on an open field depth-first
# also pays more, but there it expands about what Dijkstra does. Here Dijkstra
# looks at a handful of cells and depth-first at most of the board.
static func _depth_first_pays_more(results: Array[SearchResult]) -> bool:
	return (results[DEPTH_FIRST].reached
		and results[DEPTH_FIRST].cost > results[DIJKSTRA].cost
		and results[DEPTH_FIRST].expanded.size() > 5 * results[DIJKSTRA].expanded.size())
