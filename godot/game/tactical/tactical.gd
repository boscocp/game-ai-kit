## The tactical scenario, red against the computer, with turns as Advance Wars
## plays them.
##
## Red is a person. Click one of your units and everywhere it can reach lights
## up; click a lit cell and it walks there and is spent, greyed out until your
## next turn, and the next unit that can still move is picked up for you.
## W has the unit in hand wait where it is. With the
## workshop in hand, 1-5 build -- once a turn -- and U buys the forge. Z, or
## the button, takes back the last thing you did, as far back as the start of
## the turn. Space, or the button, ends it, and asks first while units are
## still unspent.
##
## Blue is the computer: whichever `BlueController` the scene was given, the
## rule-based one until T11 brings a planner. Each of its decisions is drawn
## before it is played, and space plays it, or enter plays the rest of the
## turn -- the scene is an example in
## invariant 13's sense, which is why it is `make demo-tactical`.
##
## The game ends when one side takes the other's workshop, or in a draw at the
## round limit (`TacticalVictory`).
class_name TacticalGame
extends Node2D

## What the scene says it is, on screen, before anything else.
const WHAT_THIS_IS: String = "tactics in the style of Advance Wars: build, cross the river, take the enemy workshop"

## The controllers still to come, named on screen beside the one playing, so
## a person knows blue is a slot and not a fixed opponent.
const CONTROLLERS_TO_COME: String = "the planner comes with T11, the learned policy after T26"

@onready var _board: BoardView = $BoardView
@onready var _units: UnitView = $UnitView
@onready var _intent: IntentView = $IntentView
@onready var _status: Label = $Interface/Status
@onready var _header: Label = $Interface/Header
@onready var _legend: Legend = $Interface/Legend
@onready var _end_button: Button = $Interface/EndTurn
@onready var _undo_button: Button = $Interface/Undo

## The game as it stands. Public so tests can set a scene up directly.
var state: BoardState
## Who plays blue. Set it before the scene enters the tree to hand blue to
## another controller; T11 and T12 play theirs this way.
var blue: BlueController = RuleBasedBlue.new()
## `TacticalVictory.NOBODY` while the game is on; then the winner, or `DRAW`.
var winner: int = TacticalVictory.NOBODY
var _turn := TacticalTurn.new()
var _blue_turn: BlueTurn
var _types: Dictionary = TacticalRules.unit_types()
var _selected_id: int = -1
var _last_refusal: String = ""
# What the last action did, in words, so a build is confirmed and not only
# visible as a smaller number.
var _last_event: String = ""
# True after one press of end turn with units still unspent: the next press
# ends it. Any other action puts it back.
var _confirming_end: bool = false


func _ready() -> void:
	_legend.set_entries(TacticalLegend.entries(_types))
	_end_button.pressed.connect(end_turn)
	_undo_button.pressed.connect(undo)
	new_game()
	BoardLayout.lay_out(self, state.graph, _status, _legend)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		_press(key.keycode)
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		click_cell(_board.cell_at(_board.to_local(click.global_position)))


## Start again: red to move, nobody spent, nobody winning.
func new_game() -> void:
	state = TacticalScenario.build()
	winner = TacticalVictory.NOBODY
	_blue_turn = BlueTurn.new(blue)
	_start_red_turn()


## A click picks up one of your units or walks the one in hand to a lit cell.
## Clicking the unit already in hand does nothing more: the turn starts with
## one in hand, and a click meant to pick it up must not spend it.
func click_cell(cell: Vector2i) -> void:
	if not _reds_turn():
		return
	var occupant: Unit = state.unit_at(cell)
	_last_event = ""
	_confirming_end = false
	if occupant != null and occupant.faction == state.current_faction:
		_pick_up(occupant)
	elif occupant != null:
		_last_refusal = "%s is %s's %s -- you can pick up only your own pieces" % [
			cell, TacticalStatus.side_name(occupant.faction), occupant.type.type_name]
	else:
		_walk_to(cell)
	_refresh()


## Build the `index`th buildable type at the workshop in hand, on the first
## free cell beside it the new unit could stand on. A workshop builds once a
## turn, and the build can be taken back like a move.
func build(index: int) -> void:
	if not _reds_turn():
		return
	_confirming_end = false
	var kind: UnitType = _types[TacticalRules.BUILDABLE[index]]
	var workshop: Unit = state.unit_by_id(_selected_id)
	if workshop != null and not workshop.type.produces.is_empty() and _turn.is_spent(workshop.id):
		_refuse("the workshop has already built this turn; Z takes the build back")
		return
	var order := ProductionOrder.new(_selected_id, kind, TacticalRules.free_cell_beside(state, workshop, kind))
	if _act(state.produce(order), state.why_production_refused(order)):
		_turn.spend(_selected_id)
		_last_event = "built a %s at %s; it moves next turn" % [kind.type_name, order.cell]
	_refresh()


## The unit in hand waits where it stands, and is spent. Taken back by undo.
func wait() -> void:
	if not _reds_turn():
		return
	_confirming_end = false
	var unit: Unit = state.unit_by_id(_selected_id)
	if unit == null or not unit.id in _turn.unspent(state):
		_refuse("nothing in hand that can still move")
		return
	_turn.remember(state)
	_turn.spend(unit.id)
	_last_event = "the %s waits at %s" % [unit.type.type_name, unit.cell]
	_last_refusal = ""
	_select_next_unspent()
	_refresh()


## Buy the forge for red. Taken back by undo like anything else.
func buy_forge() -> void:
	if not _reds_turn():
		return
	_confirming_end = false
	var forge: Upgrade = TacticalRules.forge()
	if _act(state.buy(forge), state.why_upgrade_refused(forge)):
		_last_event = "bought the forge: rams can be built"
	_refresh()


## Take back the last thing red did this turn: the unit goes back to its cell
## and is no longer spent, a build is unbuilt and paid back.
func undo() -> void:
	if not _reds_turn():
		return
	_confirming_end = false
	var spent_before: Array[int] = _turn.spent_ids()
	var before: BoardState = _turn.undo()
	if before == null:
		_refuse("nothing to take back this turn")
		return
	state = before
	_last_refusal = ""
	_last_event = "taken back"
	_hold_what_was_taken_back(spent_before)
	_refresh()


# Put back in hand the unit whose action was just taken back, so the next
# click acts on it; failing that, keep the hand unless its unit is gone.
func _hold_what_was_taken_back(spent_before: Array[int]) -> void:
	for unit_id: int in spent_before:
		if not _turn.is_spent(unit_id) and state.unit_by_id(unit_id) != null:
			_selected_id = unit_id
			return
	if state.unit_by_id(_selected_id) == null:
		_select_next_unspent()


## End red's turn. With units still unspent the first press only asks; the
## second ends it.
func end_turn() -> void:
	if not _reds_turn():
		return
	var waiting: int = _turn.unspent(state).size()
	if waiting > 0 and not _confirming_end:
		_confirming_end = true
		_refuse("%d unit(s) have not moved. End the turn anyway? Press space or the button again" % waiting)
		return
	_hand_to_blue()


## One decision by the computer: on red's turn, red's turn ends -- the decision
## being waited on is blue's -- and on blue's turn, blue plays the decision on
## screen and shows the next. The step every example offers (T21).
func step_decision() -> void:
	if winner != TacticalVictory.NOBODY:
		return
	if _reds_turn():
		_hand_to_blue()
	elif _blue_turn.finished():
		_start_red_turn()
	else:
		state = _blue_turn.play(state)
		_refresh()


## Play blue's turn to its end, every decision still drawn and recorded, and
## hand the board back to red -- for the many holds a long game brings.
func play_rest_of_blue_turn() -> void:
	while _blue_thinking():
		step_decision()
	if winner == TacticalVictory.NOBODY and not _reds_turn():
		step_decision()


## What blue is reasoning with: who is playing it, the decision about to be
## played and why, and what it has done this turn -- for
## `test/demo_overlays.gd` to check is there.
func decision_overlay() -> Dictionary:
	var overlay: Dictionary = {"controller": blue.controller_name(), "to_move": TacticalStatus.side_name(state.current_faction)}
	if _blue_thinking():
		overlay["next"] = _described(_blue_turn.next)
	if not _blue_turn.played.is_empty():
		overlay["played"] = _blue_turn.played.map(_described)
	return overlay


## True while blue's turn is on and it still has a decision to play -- and
## only while the game is on, which is what keeps a game that ended at the
## hand-off from drawing blue's next move over the result.
func _blue_thinking() -> bool:
	return (winner == TacticalVictory.NOBODY and state.current_faction == TacticalScenario.BLUE
		and _blue_turn.next != null)


## True while it is red's turn and the game is still on.
func _reds_turn() -> bool:
	return winner == TacticalVictory.NOBODY and state.current_faction == TacticalScenario.RED


func _press(keycode: Key) -> void:
	if keycode == KEY_R:
		new_game()
	elif keycode == KEY_SPACE and _reds_turn():
		end_turn()
	elif keycode == KEY_SPACE:
		step_decision()
	elif keycode >= KEY_1 and keycode <= KEY_5:
		build(keycode - KEY_1)
	elif keycode == KEY_U:
		buy_forge()
	elif keycode == KEY_Z:
		undo()
	elif keycode == KEY_W:
		wait()
	elif keycode == KEY_ENTER or keycode == KEY_KP_ENTER:
		play_rest_of_blue_turn()


func _pick_up(unit: Unit) -> void:
	_selected_id = unit.id
	_last_refusal = ""
	if _turn.is_spent(unit.id) and unit.type.mobile:
		# Held, so the status describes it, but with nothing lit: a spent unit
		# has nowhere to go until next turn.
		_last_refusal = "this %s has moved this turn; Z takes the move back" % unit.type.type_name


# Walk the unit in hand along the cheapest route the highlight offered, or,
# for a cell it did not offer, try one step so the board says why not.
func _walk_to(cell: Vector2i) -> void:
	var unit: Unit = state.unit_by_id(_selected_id)
	if unit != null and _turn.is_spent(unit.id):
		_refuse("this %s has moved this turn; Z takes the move back" % unit.type.type_name)
		return
	var walks: Dictionary = TacticalReach.walks_for(state, unit) if unit != null else {}
	var path: Array[Vector2i] = [cell]
	if walks.has(cell):
		path = walks[cell]
	var move := Move.new(_selected_id, path)
	if _act(state.apply(move), _explained(state.why_refused(move), cell)):
		_turn.spend(_selected_id)
		_select_next_unspent()


# Keep the new state and remember the old one for undo, or keep the reason it
# was refused -- never neither. True when it was kept.
func _act(next: BoardState, refusal: String) -> bool:
	if next == null:
		_last_refusal = refusal
		return false
	_turn.remember(state)
	state = next
	_last_refusal = ""
	return true


func _refuse(reason: String) -> void:
	_last_refusal = reason
	_refresh()


# The board says a cell is blocked; the game knows what it is blocked *by*.
func _explained(refusal: String, cell: Vector2i) -> String:
	if not refusal.ends_with("is blocked") or not state.graph.contains(cell):
		return refusal
	match TacticalScenario.MAP[cell.y][cell.x]:
		TacticalRules.WATER:
			return refusal + ": water, which only waders cross"
		TacticalRules.ROCK:
			return refusal + ": rock, which nothing crosses"
	return refusal


func _hand_to_blue() -> void:
	state = state.end_turn(TacticalScenario.FACTIONS, 0, TacticalRules.INCOME)
	_confirming_end = false
	_last_refusal = ""
	_last_event = ""
	_selected_id = -1
	winner = TacticalVictory.winner(state)
	_blue_turn.begin(state)
	_refresh()


func _start_red_turn() -> void:
	if state.current_faction != TacticalScenario.RED:
		state = state.end_turn(TacticalScenario.FACTIONS, 0, TacticalRules.INCOME)
		winner = TacticalVictory.winner(state)
	_turn.begin()
	_last_refusal = ""
	_last_event = ""
	_confirming_end = false
	_select_next_unspent()
	_refresh()


# The next of red's units that can still walk, or nothing when none can.
func _select_next_unspent() -> void:
	var waiting: Array[int] = _turn.unspent(state)
	_selected_id = waiting[0] if not waiting.is_empty() else -1


func _described(decision: TacticalDecision) -> Dictionary:
	return {"unit": decision.unit_id, "kind": decision.kind(), "why": decision.reason, "target": decision.target}


func _refresh() -> void:
	# Blue's turn draws neither red's reach nor red's spent units: what is on
	# screen then is blue's decision.
	var reach: Array[Vector2i] = []
	_units.spent.clear()
	if _reds_turn():
		reach = _steps_in_reach()
		_units.spent = _turn.spent_ids()
	_board.draw_board(state.graph, reach, [] as Array[Vector2i], _terrain())
	_units.show_state(state, _board, _selected_id)
	_intent.show_decision(_blue_turn.next if _blue_thinking() else null, state, _board)
	_header.text = "%s\n%s\nblue is played by %s" % [WHAT_THIS_IS, TacticalVictory.rule(), blue.describe()]
	_end_button.disabled = not _reds_turn()
	_undo_button.disabled = not (_reds_turn() and _turn.can_undo())
	_status.text = _status_text()


func _status_text() -> String:
	if winner != TacticalVictory.NOBODY:
		return TacticalVictory.announcement(winner)
	if not _reds_turn():
		return TacticalStatus.blue_text(state, _blue_turn, blue) + "\n\n" + CONTROLLERS_TO_COME
	var unit: Unit = state.unit_by_id(_selected_id)
	var news: String = _last_event
	if unit == null and _turn.unspent(state).is_empty():
		news = (news + "\n" if news != "" else "") + "every unit has moved: space ends the turn"
	return TacticalStatus.text(state, unit, _last_refusal, news)


# Every cell the unit in hand can walk to this turn; nothing for a spent one.
func _steps_in_reach() -> Array[Vector2i]:
	var unit: Unit = state.unit_by_id(_selected_id)
	var found: Array[Vector2i] = []
	if unit != null and not _turn.is_spent(unit.id):
		found.assign(TacticalReach.walks_for(state, unit).keys())
	return found


# The ground the board's costs alone would draw wrong: trees as rough ground,
# water as a wall, the bridge as open ground.
func _terrain() -> Dictionary:
	var tiles: Dictionary = {}
	var kinds: Dictionary = {
		TacticalRules.TREES: BoardView.TREES, TacticalRules.WATER: BoardView.WATER,
		TacticalRules.BRIDGE: BoardView.BRIDGE,
	}
	for letter: String in kinds:
		for cell: Vector2i in TacticalRules.cells_of(TacticalScenario.MAP, letter):
			tiles[cell] = kinds[letter]
	return tiles
