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
## **The last round decides** (T47). A game still going at the round limit is
## not a draw by default: the side with the higher score wins, the score
## being, in order, its workshop's health, its point-turns
## (`ControlPoints.POINT_TURNS`: each point, each turn it was held -- two
## points for one turn are two; the task said rounds, and point-turns keep
## the second point worth holding), and the cost of what it has left
## standing. Blue's shield for moving second counts there like any piece:
## the counter is meant to be worth something. The score is read when round
## 41 would open, after red has been paid and its towers have fired once
## more than blue's -- measured in wave 51's review, it changed no outcome. A draw only when all three are equal --
## Advance Wars By Web gives a day-limit game to the side with the most
## properties, Polytopia's Perfection mode to the higher score
## (`docs/design/tactical-references.md`, §1.4).
##
## When not to use it: a scenario won by anything but a building, such as
## holding ground or a count of kills. That is another rule, and another file.
class_name TacticalVictory
extends RefCounted

## Nobody has won yet.
const NOBODY: int = -1
## Nobody won, and the game is over: the round limit came first and the
## scores were equal.
const DRAW: int = -2
## Rounds before a game that nobody has won is called a draw. A rule, not a
## convenience: without it two players who never reach a workshop -- or a
## blue that cannot -- play for ever, and "a game ends" is not true.
const ROUND_LIMIT: int = 40


## The side whose enemy has no workshop left; at the round limit, the side
## with the higher `score`, or `DRAW` on equal scores; otherwise `NOBODY`.
## Asked after every action, so a workshop destroyed on the last turn still
## counts.
static func winner(state: BoardState) -> int:
	for side: int in range(TacticalScenario.FACTIONS):
		if not _has_workshop(state, side):
			return TacticalScenario.FACTIONS - 1 - side
	if state.turn_number >= ROUND_LIMIT * TacticalScenario.FACTIONS:
		return _higher_score(state)
	return NOBODY


## True when the game ended at the round limit rather than at a workshop --
## on scores or in a draw.
static func at_the_limit(state: BoardState) -> bool:
	return state.turn_number >= ROUND_LIMIT * TacticalScenario.FACTIONS and _has_workshop(state, 0) and _has_workshop(state, 1)


## `side`'s score for the round limit, compared in order: its workshop's
## health, the turns it held points, the cost of what it has left standing.
static func score(state: BoardState, side: int) -> Array[int]:
	var workshop: int = 0
	var standing: int = 0
	for unit: Unit in state.units_of(side):
		if unit.type.type_name == TacticalRules.WORKSHOP:
			workshop = unit.health
		standing += unit.type.cost
	var held: int = state.tally.get(ControlPoints.POINT_TURNS, {}).get(side, 0)
	return [workshop, held, standing]


static func _higher_score(state: BoardState) -> int:
	var red: Array[int] = score(state, TacticalScenario.RED)
	var blue: Array[int] = score(state, TacticalScenario.BLUE)
	for index: int in range(red.size()):
		if red[index] != blue[index]:
			return TacticalScenario.RED if red[index] > blue[index] else TacticalScenario.BLUE
	return DRAW


## The rule, as the screen states it before anybody has won -- and, since
## T47, the second player's counter, which is part of what is fair about it.
static func rule() -> String:
	if TacticalRules.SECOND_PLAYER_SHIELD:
		return TranslationServer.translate("to win: destroy the enemy workshop -- attack it with a unit in reach. After {rounds} rounds the higher score wins: workshop health, then point-turns held (each point, each turn it was held), then what is left standing; blue moves second and starts with one more shield").format({
			rounds = ROUND_LIMIT})
	return TranslationServer.translate("to win: destroy the enemy workshop -- attack it with a unit in reach. After {rounds} rounds the higher score wins: workshop health, then point-turns held (each point, each turn it was held), then what is left standing").format({
		rounds = ROUND_LIMIT})


## The words for the end of a game.
static func announcement(winner_side: int, state: BoardState = null) -> String:
	if state != null and at_the_limit(state):
		return _at_the_limit_said(winner_side, state)
	if winner_side == DRAW:
		return TranslationServer.translate("a draw: {rounds} rounds, and nobody destroyed a workshop.  R starts again.").format({rounds = ROUND_LIMIT})
	return TranslationServer.translate("{winner} wins: the {loser} workshop is destroyed.  R starts again.").format({
		winner = TacticalStatus.side_name(winner_side), loser = TacticalStatus.side_name(TacticalScenario.FACTIONS - 1 - winner_side)})


static func _at_the_limit_said(winner_side: int, state: BoardState) -> String:
	var scores: String = TranslationServer.translate("red {red}, blue {blue} (workshop health, point-turns held, left standing)").format({
		red = score(state, TacticalScenario.RED), blue = score(state, TacticalScenario.BLUE)})
	if winner_side == DRAW:
		return TranslationServer.translate("a draw: {rounds} rounds, and the scores are equal -- {scores}.  R starts again.").format({
			rounds = ROUND_LIMIT, scores = scores})
	return TranslationServer.translate("{winner} wins on score after {rounds} rounds: {scores}.  R starts again.").format({
		winner = TacticalStatus.side_name(winner_side), rounds = ROUND_LIMIT, scores = scores})


static func _has_workshop(state: BoardState, side: int) -> bool:
	for unit: Unit in state.units_of(side):
		if unit.type.type_name == TacticalRules.WORKSHOP:
			return true
	return false
