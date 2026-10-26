## The playable board: a scenario, two factions, a mouse, and an opponent that
## decides with a trained model.
##
## Red is yours and moves a cell at a time. Blue is played by `ai_learning`:
## when your turn ends, each of its units asks the combat model whether a
## fight in reach is worth taking, and otherwise walks at a node red is
## standing on -- a written rule, not a model -- or at whichever node the
## capture model says it can hold soonest. Holding a node for
## `SkirmishVictory.HOLD_TURNS` of your turns wins.
##
## The screen has to make the decision visible, not just its result -- a unit
## stepping backwards looks the same whether a model gave it a 3% chance or
## whether it had nowhere else to go. So every blue unit's reason, with the
## number in it, goes in the status beside the board. That is invariant 13, and
## the manual check in T6 is whether a person can read it.
##
## The layout is the board in the middle of the window, the status to its left
## and the legend to its right, all three level with the board's top edge. T8
## measured the old one: a 384 px board pinned to a corner of a 1280 px window,
## and the status line it described 600 px away from it.
class_name BoardGame
extends Node2D

const COLUMNS: int = 12
const ROWS: int = 8

## What a unit gets at the start of its side's turn.
const POINTS_PER_TURN: int = 4

const FACTIONS: int = 2
const RED: int = 0
const BLUE: int = 1

const SIDE_NAMES: Array[String] = ["red", "blue"]  # shown through tr()

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
var _victory: SkirmishVictory = SkirmishVictory.new(NODES, FACTIONS)

# What blue has played this turn, in its own words, and the decision it is
# about to play -- decided and drawn, not yet played.
var _ai_reasons: PackedStringArray = PackedStringArray()
var _played: Array[LearnedDecision] = []
var _plan: LearnedDecision = null

# Blue's units that have still to decide this turn, by id.
var _blue_to_decide: Array[int] = []


func _ready() -> void:
	_legend.set_entries(_legend_entries())
	_state = _build_scenario()
	BoardLayout.lay_out(self, _state.graph, _status, _legend)
	# The search goes in from here rather than from inside the policy: a route
	# is a search, and no addon may depend on another. The game owns both and
	# is the right place to introduce them.
	_policy = LearnedPolicy.new(
		TacticalWeights.load_from(LearnedPolicy.WEIGHTS_PATH), NODES,
		LearnedPolicy.DEFAULT_THRESHOLD, GridPathfinder.new(AStarSearch.new()))
	_select_first_unit_of_the_side_to_move()
	_refresh()
	Language.apply_if_opened_alone(self)


# The words are rebuilt in the language just chosen (T79): a Label set from
# code keeps the words it was given. The notification also comes on entering
# the tree, before _ready, when there is nothing to rebuild yet.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_legend.set_entries(_legend_entries())
		_refresh()


func _legend_entries() -> Array[Array]:
	return [
		[UnitView.legend_picture(RED, Art.NO_TYPE), tr("red: yours (white: id, yellow: health)")],
		[UnitView.legend_picture(BLUE, Art.NO_TYPE), tr("blue: the learned opponent")],
		[Color.TRANSPARENT, tr("white frame round a unit: the one in hand")],
		[PlanView.ROUTE, tr("blue's next move, not yet played")],
		[BoardView.REACHABLE, tr("where the unit in hand can step")],
		[BoardView.tile_texture(BoardView.NODE), tr("a node: hold it {turns} turns to win").format({turns = SkirmishVictory.HOLD_TURNS})],
		[BoardView.tile_texture(BoardView.PLAIN), tr("open ground")],
		[BoardView.tile_texture(BoardView.ROUGH), tr("rough ground: costs the number on it")],
		[BoardView.tile_texture(BoardView.WALL), tr("wall")],
	] as Array[Array]


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and key.keycode == KEY_R:
		get_tree().reload_current_scene()
		return
	if event.is_action_pressed("ui_accept"):
		_end_turn()
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	_click_cell(_board.cell_at(_board.to_local(click.global_position)))


# A click either picks up one of your units or tries to step onto a cell.
func _click_cell(cell: Vector2i) -> void:
	if _victory.winner != SkirmishVictory.NOBODY:
		return
	if _state.current_faction == AI_FACTION:
		_last_refusal = tr("blue is deciding -- space plays the move it has drawn")
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
		_last_refusal = tr("nothing is selected -- click one of your own units first")
		_refresh()
		return
	# Without this, a click on the far side of the board was refused with "a
	# step is one cell, no diagonals", which is true of the move this scene
	# built and is not the reason it could not be made. The reason is that this
	# scene cannot build a route at all, and the player deserves to be told
	# that rather than a rule they did not break.
	if not GridGraph.DIRECTIONS.has(cell - unit.cell):
		_last_refusal = tr("{cell} is more than one step away -- you move one cell at a time, onto a highlighted cell").format({cell = cell})
		_refresh()
		return
	var path: Array[Vector2i] = [cell]
	var move := Move.new(unit.id, path)
	var refusal: String = _state.why_refused(move)
	if refusal != BoardState.LEGAL:
		_last_refusal = refusal
		_refresh()
		return
	_units.walk(unit.id, unit.cell, path)
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
	if _victory.winner != SkirmishVictory.NOBODY:
		return
	if _state.current_faction == AI_FACTION:
		_play_the_plan()
	else:
		_hand_over()
		_ai_reasons = PackedStringArray()
		_played.clear()
		if _victory.winner == SkirmishVictory.NOBODY:
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
		var walker: Unit = _state.unit_by_id(_plan.unit_id)
		_units.walk(walker.id, walker.cell, _plan.move.path)
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
		_ai_reasons.append(tr("blue cannot think: {why}").format({why = unusable}))
		_blue_to_decide.clear()
	while _plan == null and not _blue_to_decide.is_empty():
		var unit_id: int = _blue_to_decide.pop_front()
		if _state.unit_by_id(unit_id) != null:
			_plan = _policy.decide(_state, unit_id)
	if _plan == null:
		_hand_over()


# End the turn, and count the holds of the side whose turn it now is: holding
# is judged at the start of the holder's own turn, so the other side has had
# its whole turn to break it.
func _hand_over() -> void:
	_state = _state.end_turn(FACTIONS, POINTS_PER_TURN)
	_victory.turn_started(_state)


# Red starts its turn with one of its units in hand, so the first click of a
# turn does something rather than teaching you that nothing is selected.
#
# Blue has nothing in hand. Its turn used to ring its first unit and tint that
# unit's steps, while the status named the unit actually deciding -- so on the
# second decision the board and the status pointed at different units, and a
# player read blue's steps as their own.
func _select_first_unit_of_the_side_to_move() -> void:
	var mine: Array[Unit] = _state.units_of(_state.current_faction)
	var is_yours: bool = _state.current_faction != AI_FACTION
	_selected_id = mine[0].id if is_yours and not mine.is_empty() else -1


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


# Whose turn, what is in hand, what to do about it -- in the order a first-time
# player asks -- then what was refused and what blue is thinking.
func _status_line() -> String:
	if _victory.winner != SkirmishVictory.NOBODY:
		return SkirmishVictory.announcement(_victory.winner, SIDE_NAMES)
	var lines: Array[String] = [_whose_turn(), _in_hand(), _what_to_do(), SkirmishVictory.rule()]
	var holds: String = _victory.progress(_state, SIDE_NAMES)
	if holds != "":
		lines.append(holds)
	if _last_refusal != BoardState.LEGAL:
		lines.append("\n" + tr("refused: {why}").format({why = TacticalRefusal.words(_last_refusal)}))
	if not _ai_reasons.is_empty():
		lines.append("\n" + tr("blue this turn:"))
		for reason: String in _ai_reasons:
			lines.append(reason)
	if _plan != null:
		lines.append("\n" + tr("next, not yet played: {why}").format({why = _plan.reason}))
	return "\n".join(lines)


func _whose_turn() -> String:
	if _state.current_faction == AI_FACTION:
		return tr("turn {turn}  ·  blue to move: the learned opponent").format({turn = _state.turn_number})
	return tr("turn {turn}  ·  red to move: you are red").format({turn = _state.turn_number})


func _in_hand() -> String:
	if _plan != null:
		return tr("blue's unit {unit} is deciding").format({unit = _plan.unit_id})
	var unit: Unit = _state.unit_by_id(_selected_id)
	if unit == null:
		return tr("no unit in hand")
	return tr("unit {unit} in hand  ·  movement left: {points}").format({unit = unit.id, points = unit.movement_points})


# The next thing to do, for the state the board is actually in: an
# instruction to click a highlighted cell is wrong when none is highlighted.
func _what_to_do() -> String:
	if _plan != null:
		return tr("space plays the move drawn as a blue line and box.")
	if _selected_id == -1:
		return tr("click one of your units. Space ends your turn.")
	if _affordable_steps().is_empty():
		return tr("this unit cannot step anywhere now -- click another of your units, or press space to end your turn.")
	return tr("click one of your units, then a highlighted cell next to it. A step costs the number on the cell it enters, or 1. Space ends your turn.")


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
