## When a game of the tactical scenario is over.
##
## The goal is the enemy workshop. Destroying it needs combat, which T26
## brings; until then a side **takes** it by having one of its walking units
## beside it -- one step away, in one of the four directions -- at the start of
## its own turn. The other side had its whole turn to do something about it.
## That rule is provisional and the screen says so.
##
## When not to use it: once T26 lands. Taking by standing next to it is a
## stand-in for a fight, and it goes when there is one.
class_name TacticalVictory
extends RefCounted

## Nobody has won yet.
const NOBODY: int = -1
## Nobody won, and the game is over: the round limit came first.
const DRAW: int = -2
## Rounds before a game that nobody has won is called a draw. A rule, not a
## convenience: without it two players who never reach a workshop -- or a
## blue that cannot -- play for ever, and "a game ends" is not true.
const ROUND_LIMIT: int = 40


## The side that has just taken the enemy workshop, `DRAW` once the round
## limit is reached, or `NOBODY`. Asked at the start of a turn, of the side
## about to move -- so taking the workshop on the last turn still counts.
static func winner(state: BoardState) -> int:
	var side: int = state.current_faction
	for workshop: Unit in _enemy_workshops(state, side):
		if _walker_beside(state, side, workshop.cell):
			return side
	if state.turn_number >= ROUND_LIMIT * TacticalScenario.FACTIONS:
		return DRAW
	return NOBODY


## The rule, as the screen states it before anybody has won.
static func rule() -> String:
	return "to win: start your turn with a unit beside the enemy workshop (provisional, until T26 brings combat), or it is a draw after %d rounds" % ROUND_LIMIT


## The words for the end of a game, provisional rule and all.
static func announcement(winner_side: int) -> String:
	if winner_side == DRAW:
		return "a draw: %d rounds, and nobody took a workshop.  R starts again." % ROUND_LIMIT
	return "%s wins: a %s unit stood beside the enemy workshop at the start of its turn. (Provisional: until T26 brings combat, that is what taking it means.)  R starts again." % [
		TacticalStatus.side_name(winner_side), TacticalStatus.side_name(winner_side)]


static func _enemy_workshops(state: BoardState, side: int) -> Array[Unit]:
	var found: Array[Unit] = []
	for unit: Unit in state.units:
		if unit.faction != side and unit.type.type_name == TacticalRules.WORKSHOP:
			found.append(unit)
	return found


static func _walker_beside(state: BoardState, side: int, cell: Vector2i) -> bool:
	for step: Vector2i in GridGraph.DIRECTIONS:
		var neighbour: Unit = state.unit_at(cell + step)
		if neighbour != null and neighbour.faction == side and neighbour.type.mobile:
			return true
	return false
