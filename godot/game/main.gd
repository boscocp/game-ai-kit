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
@onready var _plan_view: PlanView = $PlanView

var _state: BoardState
var _selected_id: int = -1
var _last_refusal: String = ""

var _policy: LearnedPolicy

# What blue has played this turn, in its own words, and the decision it is
# about to play -- decided and drawn, not yet played.
var _ai_reasons: PackedStringArray = PackedStringArray()
var _played: Array[LearnedDecision] = []
var _plan: LearnedDecision = null

# Blue's units that have still to decide this turn, by id.
var _blue_to_decide: Array[int] = []


func _ready() -> void:
	_legend.set_entries([
		[UnitView.FACTION_COLOURS[RED], "red: yours (numbers are ids)"],
		[UnitView.FACTION_COLOURS[BLUE], "blue: the learned opponent"],
		[Color.WHITE, "ring: the unit in hand"],
		[PlanView.ROUTE, "blue's next move, not yet played"],
		[BoardView.SWATCHES[BoardView.REACHABLE.x], "where the unit in hand can step"],
		[BoardView.SWATCHES[BoardView.NODE.x], "a node both sides want"],
		[BoardView.SWATCHES[BoardView.PLAIN.x], "open ground"],
		[BoardView.SWATCHES[BoardView.ROUGH.x], "rough ground: dear to cross"],
		[BoardView.SWATCHES[BoardView.WALL.x], "wall"],
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
	if _state.current_faction == AI_FACTION:
		_last_refusal = "blue is deciding -- space plays the move it has drawn"
		_refresh()
		return
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
	step_decision()


## Space, and the step every example offers (T21): one decision at a time.
##
## On red's turn it ends red's turn, and blue's first unit decides -- decides
## and is drawn, not played. Each press after that plays the move on screen
## and lets the next unit decide, and the press after blue's last move hands
## the board back. So every blue decision is on the screen before it happens.
func step_decision() -> void:
	if _state.current_faction == AI_FACTION:
		_play_the_plan()
	else:
		_state = _state.end_turn(FACTIONS, POINTS_PER_TURN)
		_ai_reasons = PackedStringArray()
		_played.clear()
		_blue_to_decide.assign(_state.units_of(AI_FACTION).map(func(unit: Unit) -> int: return unit.id))
		_plan_the_next_unit()
	_last_refusal = ""
	_select_first_unit_of_the_side_to_move()
	_refresh()


## What blue is reasoning with: every decision this turn, the one about to be
## played last, each with the number it was made on.
func decision_overlay() -> Dictionary:
	var decisions: Array[Dictionary] = []
	for decision: LearnedDecision in _played + ([_plan] if _plan != null else []):
		var entry: Dictionary = {"unit": decision.unit_id, "action": decision.action}
		entry.merge({"number": PlanView.number_of(decision), "reason": decision.reason})
		if is_finite(decision.win_probability):
			entry["p_win"] = decision.win_probability
		if is_finite(decision.predicted_turns):
			entry["turns"] = decision.predicted_turns
		entry["played"] = decision != _plan
		decisions.append(entry)
	return {"decisions": decisions}


# Play the move on screen, then let the next unit decide.
func _play_the_plan() -> void:
	_ai_reasons.append(_plan.reason)
	_played.append(_plan)
	var next: BoardState = _state.apply(_plan.move)
	if next != null:
		_state = next
	_plan_the_next_unit()


# The next blue unit decides against the board as it is now, after the moves
# already played -- a unit that has watched a friend walk away has a different
# `numeric_advantage`, and deciding on a board that no longer exists is the
# oldest bug in turn-based AI. With nobody left to decide, blue's turn ends.
func _plan_the_next_unit() -> void:
	_plan = null
	var unusable: String = _policy.why_unusable()
	if unusable != "":
		_ai_reasons.append("blue cannot think: " + unusable)
		_blue_to_decide.clear()
	while _plan == null and not _blue_to_decide.is_empty():
		var unit_id: int = _blue_to_decide.pop_front()
		if _state.unit_by_id(unit_id) != null:
			_plan = _policy.decide(_state, unit_id)
	if _plan == null:
		_state = _state.end_turn(FACTIONS, POINTS_PER_TURN)


# Whoever is to move starts with one of their units in hand, so the first click
# of a turn does something rather than teaching you that nothing is selected.
func _select_first_unit_of_the_side_to_move() -> void:
	var mine: Array[Unit] = _state.units_of(_state.current_faction)
	_selected_id = mine[0].id if not mine.is_empty() else -1


func _refresh() -> void:
	_board.draw_board(_state.graph, _affordable_steps(), NODES)
	_units.show_state(_state, _board, _selected_id)
	_plan_view.show_plan(_plan, _state, _board)
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
	var space: String = "space plays blue's next move" if _plan != null else "space ends the turn"
	var line: String = "turn %d  ·  %s to move  ·  movement left: %s  ·  %s" % [
		_state.turn_number, side, points, space,
	]
	if _last_refusal != BoardState.LEGAL:
		line += "\nrefused: " + _last_refusal
	for reason: String in _ai_reasons:
		line += "\n" + reason
	if _plan != null:
		line += "\nnext, not yet played: " + _plan.reason
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
