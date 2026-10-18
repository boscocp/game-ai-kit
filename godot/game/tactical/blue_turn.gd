## Blue's turn, one decision at a time: decided, shown, and only then played.
##
## Each piece blue owns is asked once, the workshop first so that what it
## builds is on the board before anyone walks; each walker is then asked once
## more, after its walk is played, whom to attack from where it stands (T26).
## The next decision is made from the board as the last one left it, kept in
## `next` for the scene to draw, and played when the person presses space --
## so the screen always shows what blue is about to do before it does it,
## which is invariant 13.
##
## A workshop with no room beside it is asked once more, after the last
## walker (T45): its walkers may have moved off, and money left in the bank is
## a piece not on the board. Asked first all the same -- what it builds is on
## the board before anyone walks, whenever there is room.
##
## A decision the board refuses is not played and is kept in `refused`. The
## controller's contract says that never happens, and the tests hold it to
## that over many games; if it does, the turn goes on rather than stopping.
##
## When not to use it: red's turn, which a person plays (`TacticalTurn`).
class_name BlueTurn
extends RefCounted

var controller: BlueController
## What blue will do next, or null once every piece has been asked.
var next: TacticalDecision
## What blue has done this turn, in order.
var played: Array[TacticalDecision] = []
## Decisions the board refused. Empty, unless a controller breaks its contract.
var refused: Array[TacticalDecision] = []
var _waiting: Array[int] = []
# Workshops that had no room when asked, to be asked again at the end.
var _ask_again: Array[int] = []
# The walker whose move was just decided, to be asked about an attack once
# that move is played -- or -1. Asked after, not with, the move, because who is
# in reach depends on where the move left it.
var _to_ask_about_attacking: int = -1


func _init(deciding: BlueController) -> void:
	controller = deciding


## Start blue's turn on `state`: queue every piece, and decide the first.
func begin(state: BoardState) -> void:
	played.clear()
	refused.clear()
	_waiting.clear()
	_ask_again.clear()
	_to_ask_about_attacking = -1
	controller.begin_turn(state)
	for unit: Unit in state.units_of(state.current_faction):
		if not unit.type.produces.is_empty():
			_waiting.push_front(unit.id)
		elif unit.type.mobile:
			_waiting.append(unit.id)
	_decide_next(state)


## True once every piece has had its decision played.
func finished() -> bool:
	return next == null


## Play `next` on `state`, decide the one after, and return the new state.
func play(state: BoardState) -> BoardState:
	var after: BoardState = next.played_on(state)
	if after == null:
		refused.append(next)
		after = state
	else:
		played.append(next)
	_decide_next(after)
	return after


func _decide_next(state: BoardState) -> void:
	next = null
	if _to_ask_about_attacking != -1:
		var walker: int = _to_ask_about_attacking
		_to_ask_about_attacking = -1
		if state.unit_by_id(walker) != null:
			next = controller.decide_attack(state, walker)
	while next == null and not (_waiting.is_empty() and _ask_again.is_empty()):
		if _waiting.is_empty():
			_waiting.append_array(_ask_again)
			_ask_again.clear()
		var unit: Unit = state.unit_by_id(_waiting.pop_front())
		if unit == null:
			continue
		if unit.type.produces.is_empty():
			next = controller.decide_move(state, unit.id)
			_to_ask_about_attacking = unit.id
		else:
			next = _decide_build(state, unit)


# The workshop's decision; one with no room beside it is remembered, to be
# asked again once every walker has had its turn -- once, not again after.
func _decide_build(state: BoardState, workshop: Unit) -> TacticalDecision:
	var decision: TacticalDecision = controller.decide_build(state, workshop.id)
	var built: bool = decision.order != null or decision.upgrade != null
	if not built and RuleBasedBlue.no_room_beside(state, workshop) and not _asked_already(workshop.id):
		_ask_again.append(workshop.id)
	return decision


# True when `unit_id` has had a decision played this turn.
func _asked_already(unit_id: int) -> bool:
	for done: TacticalDecision in played:
		if done.unit_id == unit_id:
			return true
	return false
