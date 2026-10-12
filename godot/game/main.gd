## The playable board: a scenario, two factions, and a mouse.
##
## There is no AI in this scene, deliberately. T2 builds the state every later
## lesson decides on, and the way to be sure the state is right is to play it by
## hand first. When `ai_search` lands, clicking a far cell will ask it for a
## route; until then a click moves one cell, because a route is a search and a
## search does not belong in `ai_core` or in a view.
##
## What the screen has to make obvious, and what the manual check in T2 asks
## for: whose turn it is, which unit is selected, where it may go, and why a
## refused move was refused.
class_name BoardGame
extends Node2D

const COLUMNS: int = 12
const ROWS: int = 8

## What a unit gets at the start of its side's turn.
const POINTS_PER_TURN: int = 4

const FACTIONS: int = 2
const RED: int = 0
const BLUE: int = 1

@onready var _board: BoardView = $BoardView
@onready var _units: UnitView = $UnitView
@onready var _status: Label = $Interface/Status

var _state: BoardState
var _selected_id: int = -1
var _last_refusal: String = ""


func _ready() -> void:
	_state = _build_scenario()
	_select_first_unit_of_the_side_to_move()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_end_turn()
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	_click_cell(_board.cell_at(_board.to_local(click.global_position)))


# A click either picks up one of your units or tries to step onto a cell.
func _click_cell(cell: Vector2i) -> void:
	var occupant: Unit = _state.unit_at(cell)
	if occupant != null and occupant.faction == _state.current_faction:
		_selected_id = occupant.id
		_last_refusal = ""
		_refresh()
		return
	_try_step(cell)


# One step, which is the only move this scene knows how to build.
func _try_step(cell: Vector2i) -> void:
	var unit: Unit = _state.unit_by_id(_selected_id)
	if unit == null:
		_last_refusal = "nothing is selected -- click one of your own units first"
		_refresh()
		return
	# Without this, a click on the far side of the board was refused with "a
	# step is one cell, no diagonals", which is true of the move this scene
	# built and is not the reason it could not be made. The reason is that this
	# scene cannot build a route at all, and the player deserves to be told
	# that rather than a rule they did not break.
	if not GridGraph.DIRECTIONS.has(cell - unit.cell):
		_last_refusal = (
			"that is more than one step away, and this scene moves one cell "
			+ "at a time -- routes arrive with ai_search in T3"
		)
		_refresh()
		return
	var path: Array[Vector2i] = [cell]
	var move := Move.new(unit.id, path)
	var refusal: String = _state.why_refused(move)
	if refusal != BoardState.LEGAL:
		_last_refusal = refusal
		_refresh()
		return
	_state = _state.apply(move)
	_last_refusal = ""
	_refresh()


func _end_turn() -> void:
	_state = _state.end_turn(FACTIONS, POINTS_PER_TURN)
	_last_refusal = ""
	_select_first_unit_of_the_side_to_move()
	_refresh()


# Whoever is to move starts with one of their units in hand, so the first click
# of a turn does something rather than teaching you that nothing is selected.
func _select_first_unit_of_the_side_to_move() -> void:
	var mine: Array[Unit] = _state.units_of(_state.current_faction)
	_selected_id = mine[0].id if not mine.is_empty() else -1


func _refresh() -> void:
	_board.draw_board(_state.graph, _affordable_steps())
	_units.show_state(_state, _board, _selected_id)
	_status.text = _status_line()


# The neighbouring cells the selected unit could actually step onto now. This
# is not pathfinding: it asks the board the same question a click would, which
# is why it can never disagree with what a click does.
func _affordable_steps() -> Array[Vector2i]:
	var unit: Unit = _state.unit_by_id(_selected_id)
	if unit == null:
		return []
	var found: Array[Vector2i] = []
	for step: Vector2i in _state.graph.neighbours(unit.cell):
		var path: Array[Vector2i] = [step]
		if _state.why_refused(Move.new(unit.id, path)) == BoardState.LEGAL:
			found.append(step)
	return found


func _status_line() -> String:
	var side: String = "red" if _state.current_faction == RED else "blue"
	var unit: Unit = _state.unit_by_id(_selected_id)
	var points: String = "-" if unit == null else str(unit.movement_points)
	var line: String = "turn %d  ·  %s to move  ·  movement left: %s  ·  space ends the turn" % [
		_state.turn_number, side, points,
	]
	if _last_refusal != BoardState.LEGAL:
		line += "\nrefused: " + _last_refusal
	return line


# Two units a board apart, a wall to walk around and a patch of rough ground to
# pay for. Small enough to read, and enough terrain that a route is a choice.
func _build_scenario() -> BoardState:
	var graph := GridGraph.new(COLUMNS, ROWS)
	for row: int in range(1, ROWS - 2):
		graph.block(Vector2i(6, row))
	for row: int in range(2, 5):
		graph.set_cost(Vector2i(4, row), 3)
		graph.set_cost(Vector2i(8, row), 3)

	var units: Array[Unit] = [
		Unit.new(1, RED, Vector2i(1, 4), 10, POINTS_PER_TURN),
		Unit.new(2, BLUE, Vector2i(10, 3), 10, POINTS_PER_TURN),
	]
	return BoardState.new(graph, units, RED)
