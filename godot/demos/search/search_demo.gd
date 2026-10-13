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


func _ready() -> void:
	_legend.set_entries([
		[ExpansionView.NEXT, "expanded next"],
		[ExpansionView.EARLY, "expanded early"],
		[ExpansionView.LATE, "expanded late"],
		[ExpansionView.FRONTIER, "still waiting when it stopped"],
		[ExpansionView.PATH, "the route found"],
		[ExpansionView.START, "start"],
		[ExpansionView.GOAL, "goal"],
		[BoardView.SWATCHES[1], "mud: dear to cross"],
		[BoardView.SWATCHES[2], "wall"],
	] as Array[Array])
	_graph = _build_board()
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
	return {
		"algorithm": NAMES[_chosen],
		"expanded": _result.expanded.slice(0, _revealed),
		"about_to_expand": about_to if about_to != null else "finished",
	}


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
	_expansion.show_search(_result, _board, _revealed, _from, _to)
	_status.text = _status_line()


func _status_line() -> String:
	var cost: String = str(_result.cost) if _result.reached else "no route"
	return (
		"%s  ·  expanded %d of %d  ·  steps %d  ·  cost %s"
		+ "\n1-4 choose  ·  space steps  ·  enter finishes  ·  R rebuilds"
	) % [NAMES[_chosen], _revealed, _result.expanded.size(), _result.path.size(), cost]


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
