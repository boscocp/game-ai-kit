## When a game of the tactical scenario is over.
##
## The goal is the enemy workshop: destroy it and you have won. Until T26 a
## side "took" it by standing beside it at the start of its turn, a stand-in
## that said it would last only until there was combat; now there is, and an
## attack that brings the workshop to nothing ends the game at once.
##
## A workshop cannot hit back, but it is besieged, not fought: it starts with
## `TacticalRules.BUILDING_HEALTH` and each attack is one blow (see
## `TacticalCombat`), so taking it takes turns -- turns in which the bolt
## tower and the pieces a player keeps at home can answer.
##
## When not to use it: a scenario won by anything but a building, such as
## holding ground or a count of kills. That is another rule, and another file.
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


## The side whose enemy has no workshop left, `DRAW` once the round limit is
## reached, or `NOBODY`. Asked after every action, so a workshop destroyed on
## the last turn still counts.
static func winner(state: BoardState) -> int:
	for side: int in range(TacticalScenario.FACTIONS):
		if not _has_workshop(state, side):
			return TacticalScenario.FACTIONS - 1 - side
	if state.turn_number >= ROUND_LIMIT * TacticalScenario.FACTIONS:
		return DRAW
	return NOBODY


## The rule, as the screen states it before anybody has won.
static func rule() -> String:
	return "to win: destroy the enemy workshop -- attack it with a unit in reach -- or it is a draw after %d rounds" % ROUND_LIMIT


## The words for the end of a game.
static func announcement(winner_side: int) -> String:
	if winner_side == DRAW:
		return "a draw: %d rounds, and nobody destroyed a workshop.  R starts again." % ROUND_LIMIT
	return "%s wins: the %s workshop is destroyed.  R starts again." % [
		TacticalStatus.side_name(winner_side), TacticalStatus.side_name(TacticalScenario.FACTIONS - 1 - winner_side)]


static func _has_workshop(state: BoardState, side: int) -> bool:
	for unit: Unit in state.units_of(side):
		if unit.type.type_name == TacticalRules.WORKSHOP:
			return true
	return false
