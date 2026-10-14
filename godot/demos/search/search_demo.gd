## Four searches on a board you can draw on, so the difference between them is
## visible wherever you care to ask.
##
## Each one is asked the same question and the answer is usually the same
## route. What differs is the work: breadth-first spreads in rings,
## depth-first bolts down one corridor, Dijkstra spreads in rings weighted by
## cost, and A* leans towards the goal and stops early. None of that survives
## in a finished path, which is why the demo exists -- and one board teaches
## one lesson, which is why you can paint walls and mud, drag the start and the
## goal, and start from a maze, an open field or a trap.
##
## Keys: 1-4 choose the algorithm, space reveals one more expanded cell, enter
## reveals the rest. W, M and G choose wall, mud or open ground to paint; - and
## = change what mud costs; B steps through the named boards, C clears the
## board and R rebuilds the named board you started from, even after C.
##
## Stepping does not re-run anything. The search is run once and
## `SearchResult.expanded` is replayed a cell at a time, which is exactly what
## that field is for. Changing the board does re-run it, from nothing.
class_name SearchDemo
extends Node2D

const MUD: int = 8
## What mud may cost. Below 2 it is open ground; above 9 it no longer fits as
## one digit on the tile.
const CHEAPEST_MUD: int = 2
const DEAREST_MUD: int = 9

const NAMES: Array[String] = ["breadth-first", "depth-first", "dijkstra", "a*"]

## What a left-drag paints, in the order W, M and G choose them.
enum Brush { WALL, MUD, GROUND }
const BRUSH_NAMES: Array[String] = ["wall", "mud", "open ground"]

# What the mouse is holding while a button is down.
enum Holding { NOTHING, START, GOAL, BRUSH, ERASER }

@onready var _board: BoardView = $BoardView
@onready var _expansion: ExpansionView = $ExpansionView
@onready var _status: Label = $Interface/Status
@onready var _help: Label = $Interface/Help
@onready var _legend: Legend = $Interface/Legend

var _boards: Array[SearchBoard] = SearchBoard.named()
# Which named board the current one started from. C keeps it, so R after C
# still rebuilds that board rather than the first.
var _board_index: int = 0
# True after C, until a named board is loaded again.
var _blank: bool = false
var _edited: bool = false
var _graph: GridGraph
var _from: Vector2i
var _to: Vector2i
var _chosen: int = 0
var _revealed: int = 0
var _result: SearchResult
# All four searches on the current board, run again on every change, for the
# comparison line and the board's promise.
var _all: Array[SearchResult] = []
var _brush: Brush = Brush.WALL
var _mud_cost: int = MUD
var _holding: Holding = Holding.NOTHING
# The cell the last drag event landed on, so a fast drag paints every cell it
# passed over and not only the ones the mouse happened to be reported on.
var _last_dragged := Vector2i(-1, -1)


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
		[BoardView.tile_texture(BoardView.ROUGH), "mud: costs the number on it"],
		[BoardView.tile_texture(BoardView.WALL), "wall"],
	] as Array[Array])
	load_board(0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		pointer(event, _cell_under_mouse())
		return
	var key := event as InputEventKey
	if key != null and key.pressed:
		_handle(key.keycode)


## The four searches, in the order the files are meant to be read.
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
	elif _result.reached:
		overlay["route"] = _result.path
	else:
		overlay["route"] = "no route: the goal is walled off"
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


## Start again from one of the named boards, throwing away every edit.
func load_board(index: int) -> void:
	_board_index = posmod(index, _boards.size())
	var board: SearchBoard = _boards[_board_index]
	_graph = board.graph()
	_from = board.start()
	_to = board.goal()
	_mud_cost = MUD
	_edited = false
	_blank = false
	_board_changed()


## Open ground everywhere, with the start and the goal where they were.
func clear_board() -> void:
	_graph = GridGraph.new(_graph.width, _graph.height)
	_blank = true
	_edited = false
	_board_changed()


## Choose what a left-drag paints.
func choose_brush(brush: Brush) -> void:
	_brush = brush
	_refresh()


## Paint the chosen terrain on one cell. The start and the goal sit on open
## ground and are never painted over: a wall under the goal would make "no
## route" mean "you buried it" rather than "it is walled off".
func paint(cell: Vector2i) -> void:
	_set_terrain(cell, _brush_cost())


## Make one cell open ground again, at `GridGraph.DEFAULT_COST`.
func erase(cell: Vector2i) -> void:
	_set_terrain(cell, GridGraph.DEFAULT_COST)


## Make mud dearer or cheaper -- the mud already on the board as well as the
## brush, because the question worth asking is "at what price does Dijkstra
## stop going round?", and that is one board at several prices.
func change_mud_cost(change: int) -> void:
	var old_cost: int = _mud_cost
	_mud_cost = clampi(_mud_cost + change, CHEAPEST_MUD, DEAREST_MUD)
	if _mud_cost == old_cost:
		_refresh()
		return
	if _reprice(old_cost, _mud_cost) == 0:
		_refresh()
		return
	_edited = true
	_board_changed()


## Put the start on another open cell. False, and nothing changes, when the
## cell is a wall, off the board, or the goal.
func move_start(cell: Vector2i) -> bool:
	if not _can_stand_on(cell) or cell == _from:
		return false
	_from = cell
	_edited = true
	_board_changed()
	return true


## Put the goal on another open cell, on the same terms as the start.
func move_goal(cell: Vector2i) -> bool:
	if not _can_stand_on(cell) or cell == _to:
		return false
	_to = cell
	_edited = true
	_board_changed()
	return true


## The name of the board on screen, and whether it has been edited.
func board_name() -> String:
	var named: String = "blank" if _blank else _boards[_board_index].name
	return named + (", edited" if _edited else "")


## True when the board on screen still keeps the promise of the named board it
## started from. A blank board promises nothing, and keeps it.
func promise_holds() -> bool:
	return _blank or _boards[_board_index].promise_holds(_all)


# Every cell that cost `old_cost` costs `new_cost` now; how many did. Mud of
# another price is left alone -- but walk the price onto it and the two become
# one, which no named board can show because all their mud costs 8.
func _reprice(old_cost: int, new_cost: int) -> int:
	var changed: int = 0
	for cell: Vector2i in _cells():
		if _graph.cost_at(cell) == old_cost:
			_graph.set_cost(cell, new_cost)
			changed += 1
	return changed


func _cells() -> Array[Vector2i]:
	var every: Array[Vector2i] = []
	for row: int in range(_graph.height):
		for column: int in range(_graph.width):
			every.append(Vector2i(column, row))
	return every


func _can_stand_on(cell: Vector2i) -> bool:
	return not _graph.is_blocked(cell) and cell != _from and cell != _to


func _set_terrain(cell: Vector2i, cost: int) -> void:
	if not _graph.contains(cell) or cell == _from or cell == _to:
		return
	if _graph.cost_at(cell) == cost:
		return
	_graph.set_cost(cell, cost)
	_edited = true
	_board_changed()


func _brush_cost() -> int:
	match _brush:
		Brush.WALL:
			return GridGraph.BLOCKED
		Brush.MUD:
			return _mud_cost
	return GridGraph.DEFAULT_COST


# Everything that depends on the board, worked out again from nothing: the
# tiles, the four searches behind the comparison, and the chosen one's replay.
func _board_changed() -> void:
	_board.draw_board(_graph, [] as Array[Vector2i])
	_all = []
	for search: Search in searches():
		_all.append(search.search(_graph, _from, _to))
	_choose(_chosen)


## What a mouse event does to `cell`, the cell under the pointer. Public, and
## handed the cell rather than reading the cursor, because headless tests have
## no cursor: this is the whole of the mouse layer except where the mouse is.
##
## A left press picks up the start or the goal when it lands on one, and
## otherwise starts painting; a right press starts erasing; moving with a
## button down carries on; letting go drops whatever was held.
func pointer(event: InputEvent, cell: Vector2i) -> void:
	var click := event as InputEventMouseButton
	if click == null:
		_drag_to(cell)
	elif not click.pressed:
		_holding = Holding.NOTHING
	elif click.button_index == MOUSE_BUTTON_LEFT or click.button_index == MOUSE_BUTTON_RIGHT:
		_holding = _picked_up(click.button_index, cell)
		_last_dragged = cell
		_drag_to(cell)


func _picked_up(button: MouseButton, cell: Vector2i) -> Holding:
	if button == MOUSE_BUTTON_RIGHT:
		return Holding.ERASER
	if cell == _from:
		return Holding.START
	if cell == _to:
		return Holding.GOAL
	return Holding.BRUSH


# What the held button does on the way to `cell`. The dots jump to where the
# mouse is; the brush and the eraser touch every cell between the last event
# and this one, so a quick stroke still draws an unbroken wall. Each of these
# ignores a cell where nothing would change, so a drag that sits still does not
# search again on every motion event.
func _drag_to(cell: Vector2i) -> void:
	match _holding:
		Holding.START:
			move_start(cell)
		Holding.GOAL:
			move_goal(cell)
		Holding.BRUSH:
			_stroke(_last_dragged, cell, _brush_cost())
		Holding.ERASER:
			_stroke(_last_dragged, cell, GridGraph.DEFAULT_COST)
	_last_dragged = cell


func _stroke(from: Vector2i, to: Vector2i, cost: int) -> void:
	for passed: Vector2i in _cells_between(from, to):
		_set_terrain(passed, cost)


# The cells on a straight line from `from` to `to`, both ends included,
# sampled once per cell of the longer side.
func _cells_between(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var steps: int = maxi(absi(to.x - from.x), absi(to.y - from.y))
	var passed: Array[Vector2i] = []
	for index: int in range(steps + 1):
		var point: Vector2 = Vector2(from).lerp(Vector2(to), float(index) / maxf(steps, 1.0))
		passed.append(Vector2i(point.round()))
	return passed


func _cell_under_mouse() -> Vector2i:
	return _board.cell_at(_board.get_local_mouse_position())


func _handle(keycode: Key) -> void:
	if keycode >= KEY_1 and keycode <= KEY_4:
		_choose(keycode - KEY_1)
	elif keycode == KEY_SPACE:
		step(1)
	elif keycode == KEY_ENTER or keycode == KEY_KP_ENTER:
		step(_result.expanded.size())
	else:
		_handle_edit(keycode)


func _handle_edit(keycode: Key) -> void:
	match keycode:
		KEY_W:
			choose_brush(Brush.WALL)
		KEY_M:
			choose_brush(Brush.MUD)
		KEY_G:
			choose_brush(Brush.GROUND)
		KEY_MINUS, KEY_KP_SUBTRACT:
			change_mud_cost(-1)
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			change_mud_cost(1)
		KEY_B:
			load_board(_board_index + 1)
		KEY_C:
			clear_board()
		KEY_R:
			load_board(_board_index)


func _choose(index: int) -> void:
	_chosen = clampi(index, 0, NAMES.size() - 1)
	_result = _all[_chosen]
	_revealed = 0
	_refresh()


func _refresh() -> void:
	_expansion.show_search(_result, _board, _revealed, _from, _to, frontier_after(_revealed))
	_status.text = _status_line()
	_help.text = _help_text()


func _status_line() -> String:
	return (
		"%s  ·  expanded %d of %d  ·  steps %d  ·  %s"
		+ "\n%s"
		+ "\n%s"
		+ "\n1-4 choose  ·  space steps  ·  enter finishes"
	) % [NAMES[_chosen], _revealed, _result.expanded.size(), _result.path.size(),
		_route_cost(_result), expansion_counts(), promise_line()]


## What each of the four paid to answer the same question, and what its
## answer cost -- the comparison the demo exists for, on screen without
## pressing 1 to 4 and remembering the numbers. Both numbers, because either
## alone misleads: depth-first expands few cells and finds a dear route.
func expansion_counts() -> String:
	var parts: Array[String] = []
	for index: int in range(_all.size()):
		parts.append("%s %d cells, %s" % [NAMES[index], _all[index].expanded.size(), _route_cost(_all[index])])
	return "expanded / route cost:  " + "  ·  ".join(parts)


## Which board this is and what it was chosen to show -- and, once it has
## been edited, whether it still shows it, so an edit that breaks the lesson
## says so rather than leaving the reader to wonder why A* looks no better.
func promise_line() -> String:
	if _blank:
		return "board: blank  ·  paint something and see what each search makes of it"
	var verdict: String = "it does" if promise_holds() else "not any more"
	if not _edited:
		return "board: %s  ·  %s" % [board_name(), _boards[_board_index].promise]
	return "board: %s  ·  does it still show what it was for?  %s" % [board_name(), verdict]


# "No route" is an answer like any other, and the work done to reach it is
# still on screen: the whole region the start could reach.
func _route_cost(result: SearchResult) -> String:
	return "cost %d" % result.cost if result.reached else "no route"


func _help_text() -> String:
	return "\n".join([
		"Edit the board",
		"left-drag: paint %s" % BRUSH_NAMES[_brush],
		"right-drag: erase to open ground",
		"W wall  ·  M mud  ·  G open ground",
		"- and =: mud costs %d" % _mud_cost,
		"drag a dot to move start or goal",
		"B next board  ·  C clear",
		"R rebuilds the named board",
	])
