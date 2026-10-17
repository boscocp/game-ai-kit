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
	_to_ask_about_attacking = -1
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
	while next == null and not _waiting.is_empty():
		var unit: Unit = state.unit_by_id(_waiting.pop_front())
		if unit == null:
			continue
		if unit.type.produces.is_empty():
			next = controller.decide_move(state, unit.id)
			_to_ask_about_attacking = unit.id
		else:
			next = controller.decide_build(state, unit.id)
