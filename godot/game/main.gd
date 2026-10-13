## The playable board: a scenario, two factions, a mouse, and an opponent that
## decides with a trained model.
##
## Red is yours and moves a cell at a time. Blue is played by `ai_learning`:
## when your turn ends, each of its units asks the combat model whether a
## fight in reach is worth taking, and walks at whichever node the capture
## model says it can hold soonest.
##
## The screen has to make the decision visible, not just its result -- a unit
## stepping backwards looks the same whether a model gave it a 3% chance or
## whether it had nowhere else to go. So every blue unit's reason, with the
## number in it, goes under the status line. That is invariant 13, and the
## manual check in T6 is whether a person can read it.
class_name BoardGame
extends Node2D

const COLUMNS: int = 12
const ROWS: int = 8

## What a unit gets at the start of its side's turn.
const POINTS_PER_TURN: int = 4

const FACTIONS: int = 2
const RED: int = 0
const BLUE: int = 1

## The side the learned policy plays. Red is the player's.
const AI_FACTION: int = BLUE

## The two cells worth taking. Two, because choosing between them is the
## capture model's whole job -- with one node there is nothing to predict.
const NODES: Array[Vector2i] = [Vector2i(10, 1), Vector2i(2, 6)]

@onready var _board: BoardView = $BoardView
@onready var _units: UnitView = $UnitView
@onready var _status: Label = $Interface/Status
@onready var _legend: Legend = $Interface/Legend

var _state: BoardState
var _selected_id: int = -1
var _last_refusal: String = ""

var _policy: LearnedPolicy

# What blue decided last turn, in its own words. Shown until it decides again.
var _ai_reasons: PackedStringArray = PackedStringArray()


func _ready() -> void:
	_legend.set_entries([
		[UnitView.FACTION_COLOURS[RED], "red: yours"],
		[UnitView.FACTION_COLOURS[BLUE], "blue: the learned opponent"],
		[BoardView.SWATCHES[BoardView.REACHABLE.x], "where the selected unit can step"],
		[BoardView.SWATCHES[BoardView.NODE.x], "a node both sides want"],
		[BoardView.SWATCHES[BoardView.ROUGH.x], "rough ground: dear to cross"],
		[BoardView.SWATCHES[BoardView.WALL.x], "wall"],
		[Color.WHITE, "below: blue's reasons, with its numbers"],
	] as Array[Array])
	_state = _build_scenario()
	# The search goes in from here rather than from inside the policy: a route
	# is a search, and no addon may depend on another. The game owns both and
	# is the right place to introduce them.
	_policy = LearnedPolicy.new(
		ModelFile.load_from(ModelFile.DEFAULT_PATH), NODES,
		LearnedPolicy.DEFAULT_THRESHOLD, AStarSearch.new())
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
	if _state.current_faction == AI_FACTION:
		_play_the_ai_turn()
		_state = _state.end_turn(FACTIONS, POINTS_PER_TURN)
	_select_first_unit_of_the_side_to_move()
	_refresh()


## One decision: red's turn ends, and blue decides and plays its own.
##
## Space does the same. It is here under the name every example shares (T21).
func step_decision() -> void:
	_end_turn()


## What blue reasoned with last turn: each unit's reason, with its number.
func decision_overlay() -> Dictionary:
	return {"deciding": "blue", "reasons": _ai_reasons}


# Every unit of the AI's side decides in turn, and plays what it decided.
#
# One unit at a time against the state the one before it left, rather than all
# of them deciding on the opening position: a unit that has watched a friend
# walk away is a unit whose `numeric_advantage` has changed, and deciding on a
# board that no longer exists is the oldest bug in turn-based AI.
#
# The loop holds a list taken before the first move and `_state` is replaced
# inside it, which looks like exactly that bug and is not: only each unit's
# id is read from the list, and the policy is handed the live state. The
# order is `state.units` order, which this scenario happens to build by id.
func _play_the_ai_turn() -> void:
	_ai_reasons = PackedStringArray()
	var unusable: String = _policy.why_unusable()
	if unusable != "":
		_ai_reasons.append("blue cannot think: " + unusable)
		return
	for unit: Unit in _state.units_of(AI_FACTION):
		var decision: LearnedDecision = _policy.decide(_state, unit.id)
		_ai_reasons.append(decision.reason)
		var next: BoardState = _state.apply(decision.move)
		if next != null:
			_state = next


# Whoever is to move starts with one of their units in hand, so the first click
# of a turn does something rather than teaching you that nothing is selected.
func _select_first_unit_of_the_side_to_move() -> void:
	var mine: Array[Unit] = _state.units_of(_state.current_faction)
	_selected_id = mine[0].id if not mine.is_empty() else -1


func _refresh() -> void:
	_board.draw_board(_state.graph, _affordable_steps(), NODES)
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
	for reason: String in _ai_reasons:
		line += "\n" + reason
	return line


# Two units a side, a wall to walk around, rough ground to pay for, and two
# nodes that are not equally far from everybody.
#
# Built so the AI has something to decide rather than something to do. Blue's
# healthy unit starts within reach of red's hurt one, which the combat model
# likes; blue's own hurt unit starts beside red's healthy one, which it does
# not -- so the first AI turn shows an attack and a retreat side by side.
func _build_scenario() -> BoardState:
	var graph := GridGraph.new(COLUMNS, ROWS)
	for row: int in range(1, ROWS - 2):
		graph.block(Vector2i(6, row))
	for row: int in range(2, 5):
		graph.set_cost(Vector2i(4, row), 3)
		graph.set_cost(Vector2i(8, row), 3)

	var units: Array[Unit] = [
		Unit.new(1, RED, Vector2i(1, 4), 10, POINTS_PER_TURN),
		Unit.new(2, RED, Vector2i(9, 5), 14, POINTS_PER_TURN),
		Unit.new(3, BLUE, Vector2i(10, 3), 15, POINTS_PER_TURN),
		Unit.new(4, BLUE, Vector2i(9, 6), 6, POINTS_PER_TURN),
	]
	return BoardState.new(graph, units, RED)
