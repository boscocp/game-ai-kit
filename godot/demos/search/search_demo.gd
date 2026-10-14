## Four searches on one board, so the difference between them is visible.
##
## Each one is asked the same question and the answer is usually the same
## route. What differs is the work: breadth-first spreads in rings,
## depth-first bolts down one corridor, Dijkstra spreads in rings weighted by
## cost, and A* leans towards the goal and stops early. None of that survives
## in a finished path, which is why the demo exists.
##
## Keys: 1-4 choose the algorithm, space reveals one more expanded cell, enter
## reveals the rest, R builds a new board.
##
## Stepping does not re-run anything. The search is run once and
## `SearchResult.expanded` is replayed a cell at a time, which is exactly what
## that field is for.
class_name SearchDemo
extends Node2D

const COLUMNS: int = 16
const ROWS: int = 11
const MUD: int = 8

const NAMES: Array[String] = ["breadth-first", "depth-first", "dijkstra", "a*"]

@onready var _board: BoardView = $BoardView
@onready var _expansion: ExpansionView = $ExpansionView
@onready var _status: Label = $Interface/Status
@onready var _legend: Legend = $Interface/Legend

# Derived rather than written out. They were `Vector2i(1, 5)` and
# `Vector2i(14, 5)` beside a `COLUMNS` and a `ROWS` that looked adjustable:
# change either constant and the demo silently showed "no route" with its
# markers drawn off the board.
var _graph: GridGraph
var _from := Vector2i(1, ROWS / 2)
var _to := Vector2i(COLUMNS - 2, ROWS / 2)
var _chosen: int = 0
var _revealed: int = 0
var _result: SearchResult
# `expansion_counts()` for the current board, worked out when it is built.
var _counts: String = ""


func _ready() -> void:
	_legend.set_entries([
		[ExpansionView.NEXT, "white outline: the cell it takes next"],
		[ExpansionView.FRONTIER, "pink outline: the frontier,"],
		[Color.TRANSPARENT, "    what it chooses among"],
		[ExpansionView.EARLY, "dark square: expanded early"],
		[ExpansionView.LATE, "bright square: expanded late"],
		[Color.TRANSPARENT, "    (dark to bright is the order)"],
		[ExpansionView.PATH, "line: the route found"],
		[ExpansionView.START, "green dot: start"],
		[ExpansionView.GOAL, "red dot: goal"],
		[BoardView.SWATCHES[BoardView.ROUGH.x], "mud: costs the number on it"],
		[BoardView.SWATCHES[BoardView.WALL.x], "wall"],
	] as Array[Array])
	_graph = _build_board()
	_counts = expansion_counts()
	_board.draw_board(_graph, [] as Array[Vector2i])
	_choose(0)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed():
		return
	var key := event as InputEventKey
	if key == null:
		return
	_handle(key.keycode)


# The four searches, in the order the files are meant to be read.
func searches() -> Array[Search]:
	return [
		BreadthFirstSearch.new(),
		DepthFirstSearch.new(),
		DijkstraSearch.new(),
		AStarSearch.new(),
	] as Array[Search]


## Run one algorithm on the current board and start its replay from nothing.
func choose_search(index: int) -> void:
	_choose(index)


## One decision: the search takes one more cell off its frontier.
##
## The step every example offers (T21), so a person can stop on the frame where
## the search did something surprising and read why.
func step_decision() -> void:
	step(1)


## What the search is reasoning with right now -- the same cells the overlay
## draws -- for `test/demo_overlays.gd` to check is there.
func decision_overlay() -> Dictionary:
	var about_to: Variant = _result.expanded[_revealed] if _revealed < _result.expanded.size() else null
	var overlay: Dictionary = {
		"algorithm": NAMES[_chosen],
		"expanded": _result.expanded.slice(0, _revealed),
		"frontier": frontier_after(_revealed),
	}
	if about_to != null:
		overlay["about_to_expand"] = about_to
	else:
		overlay["route"] = _result.path
	return overlay


## The frontier as it stood after `revealed` cells were expanded.
##
## `SearchResult` keeps only the frontier at the end, and the replay needs it
## at every step. All four searches put every unseen passable neighbour of a
## cell on the frontier as they expand it -- except the goal's, because they
## stop there -- so the frontier after k expansions is every cell seen by then
## that has not been expanded. `search_demo_test.gd` holds this against the
## real final frontier of all four, which is how it can be trusted.
func frontier_after(revealed: int) -> Array[Vector2i]:
	var expanded: Array[Vector2i] = _result.expanded.slice(0, revealed)
	var seen: Array[Vector2i] = [_from]
	for cell: Vector2i in expanded:
		if cell != _to:
			_see_neighbours(cell, seen)
	return seen.filter(func(cell: Vector2i) -> bool: return not cell in expanded)


func _see_neighbours(cell: Vector2i, seen: Array[Vector2i]) -> void:
	for neighbour: Vector2i in _graph.neighbours(cell):
		if not _graph.is_blocked(neighbour) and not neighbour in seen:
			seen.append(neighbour)


## Reveal `count` more expanded cells, stopping at the end.
func step(count: int) -> void:
	_revealed = mini(_revealed + count, _result.expanded.size())
	_refresh()


func _handle(keycode: Key) -> void:
	if keycode >= KEY_1 and keycode <= KEY_4:
		_choose(keycode - KEY_1)
	elif keycode == KEY_SPACE:
		step(1)
	elif keycode == KEY_ENTER or keycode == KEY_KP_ENTER:
		step(_result.expanded.size())
	elif keycode == KEY_R:
		_ready()


func _choose(index: int) -> void:
	_chosen = clampi(index, 0, NAMES.size() - 1)
	_result = searches()[_chosen].search(_graph, _from, _to)
	_revealed = 0
	_refresh()


func _refresh() -> void:
	_expansion.show_search(_result, _board, _revealed, _from, _to, frontier_after(_revealed))
	_status.text = _status_line()


func _status_line() -> String:
	var cost: String = str(_result.cost) if _result.reached else "no route"
	return (
		"%s  ·  expanded %d of %d  ·  steps %d  ·  cost %s"
		+ "\n%s"
		+ "\n1-4 choose  ·  space steps  ·  enter finishes  ·  R rebuilds"
	) % [NAMES[_chosen], _revealed, _result.expanded.size(), _result.path.size(), cost, _counts]


## What each of the four paid to answer the same question, and what its
## answer cost -- the comparison the demo exists for, on screen without
## pressing 1 to 4 and remembering the numbers. Both numbers, because either
## alone misleads: depth-first expands few cells and finds a dear route.
func expansion_counts() -> String:
	var parts: Array[String] = []
	var all: Array[Search] = searches()
	for index: int in range(all.size()):
		var result: SearchResult = all[index].search(_graph, _from, _to)
		parts.append("%s %d cells, cost %d" % [NAMES[index], result.expanded.size(), result.cost])
	return "expanded / route cost:  " + "  ·  ".join(parts)


# A band of mud across the middle and a wall with one gap. Enough that the four
# disagree: breadth-first walks the mud, Dijkstra goes round, A* goes round
# having looked at far less, and depth-first does something embarrassing.
func _build_board() -> GridGraph:
	var graph := GridGraph.new(COLUMNS, ROWS)
	for column: int in range(COLUMNS):
		graph.set_cost(Vector2i(column, _from.y), MUD)
	for row: int in range(0, ROWS - 2):
		graph.block(Vector2i(COLUMNS / 2, row))
	graph.set_cost(_from, GridGraph.DEFAULT_COST)
	graph.set_cost(_to, GridGraph.DEFAULT_COST)
	return graph
