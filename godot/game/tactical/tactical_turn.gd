## Red's turn as Advance Wars plays it: each unit acts once and is then spent,
## and every action can be taken back until the turn ends.
##
## `BoardState` already returns a new state for every move and leaves the old
## one alone, so undo is not a second model of the game: it is the list of
## states the turn passed through, each kept with which units were spent in
## it. Taking one back restores both, so a unit is never back on its old cell
## and still greyed out.
##
## When not to use it: blue's turn. Blue plays decisions the screen has
## already shown; there is nothing for a person to take back.
class_name TacticalTurn
extends RefCounted

var _spent: Array[int] = []
# Who has attacked this turn. Apart from `_spent` because a unit that has
# walked may still attack once from where it stopped, as in Advance Wars.
var _attacked: Array[int] = []
# Each entry is [BoardState, Array[int], Array[int]]: the state before an
# action, and who was spent and who had attacked then.
var _history: Array[Array] = []


## Start a new turn: nobody is spent and there is nothing to undo.
func begin() -> void:
	_spent.clear()
	_attacked.clear()
	_history.clear()


## Remember `before`, the state an action is about to replace, so that it can
## be taken back.
func remember(before: BoardState) -> void:
	_history.append([before, _spent.duplicate(), _attacked.duplicate()])


## Mark a unit as having acted this turn.
func spend(unit_id: int) -> void:
	if not unit_id in _spent:
		_spent.append(unit_id)


## Mark a unit as having attacked this turn, which also spends it.
func attacked(unit_id: int) -> void:
	spend(unit_id)
	if not unit_id in _attacked:
		_attacked.append(unit_id)


## Forget everything that could be taken back. Called after an attack: a fight
## once seen cannot be unseen, and undoing it would let a player read the dice
## and try again -- or try the attacks in another order, since each fight hands
## its dice on to the next (wave 46's review: 258 wins in 400 straight, 348
## picking the better of two orders).
func seal() -> void:
	_history.clear()


## True when the unit has attacked this turn: once a turn is all it gets.
func has_attacked(unit_id: int) -> bool:
	return unit_id in _attacked


## True when the unit has acted this turn.
func is_spent(unit_id: int) -> bool:
	return unit_id in _spent


## Every spent unit, for the view to grey out.
func spent_ids() -> Array[int]:
	return _spent.duplicate()


## True when there is an action to take back.
func can_undo() -> bool:
	return not _history.is_empty()


## The state before the last action, with who was spent then; null when
## there is nothing to undo.
func undo() -> BoardState:
	if _history.is_empty():
		return null
	var last: Array = _history.pop_back()
	_spent.assign(last[1])
	_attacked.assign(last[2])
	return last[0]


## Units of the side to move that can still walk this turn, in id order: not
## spent, mobile, and with movement left -- so a unit built this turn, which
## has none, is never offered.
func unspent(state: BoardState) -> Array[int]:
	var found: Array[int] = []
	for unit: Unit in state.units_of(state.current_faction):
		if unit.type.mobile and unit.movement_points > 0 and not is_spent(unit.id):
			found.append(unit.id)
	return found
