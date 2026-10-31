## When a game of the XCOM-style mode is over: one squad has no piece left,
## or the round limit has come.
##
## XCOM's missions end when one side is gone, and so does this. A game still
## going at `round_limit` (in `rules.json`) goes to the side with more health
## left, summed over its pieces -- the nearest thing to "who was winning" the
## board holds -- and is a draw only when the two sums are equal. The
## constants are `TacticalVictory`'s, so the scene reads either mode's ending
## the same way.
##
## When not to use it: an objective mission (XCOM's bombs and extractions).
## That is a cell to reach, and another rule.
class_name SquadVictory
extends RefCounted


## The side whose enemy has no piece left; at the round limit, the side with
## more health; `TacticalVictory.DRAW` on equal health or when both are gone;
## otherwise `TacticalVictory.NOBODY`.
static func winner(state: BoardState) -> int:
	var red_gone: bool = state.units_of(TacticalScenario.RED).is_empty()
	var blue_gone: bool = state.units_of(TacticalScenario.BLUE).is_empty()
	if red_gone and blue_gone:
		return TacticalVictory.DRAW
	if red_gone or blue_gone:
		return TacticalScenario.BLUE if red_gone else TacticalScenario.RED
	if state.turn_number >= round_limit() * TacticalScenario.FACTIONS:
		return _more_health(state)
	return TacticalVictory.NOBODY


## Rounds before a game nobody has won is decided on health.
static func round_limit() -> int:
	return int(SquadTable.rules()["round_limit"])


## `side`'s health left, summed over its pieces.
static func health_left(state: BoardState, side: int) -> int:
	var total: int = 0
	for unit: Unit in state.units_of(side):
		total += unit.health
	return total


## The rule, as the screen states it.
static func rule() -> String:
	return TranslationServer.translate("to win: leave the other squad no piece standing. After {rounds} rounds the side with more health left wins").format({
		rounds = round_limit()})


## The words for the end of a game.
static func announcement(winner_side: int, state: BoardState) -> String:
	var health: String = "red %d, blue %d health left" % [health_left(state, TacticalScenario.RED), health_left(state, TacticalScenario.BLUE)]
	if winner_side == TacticalVictory.DRAW:
		return TranslationServer.translate("a draw: {health}.  R starts again.").format({health = health})
	return TranslationServer.translate("{winner} wins: {health}.  R starts again.").format({
		winner = "red" if winner_side == TacticalScenario.RED else "blue", health = health})


static func _more_health(state: BoardState) -> int:
	var red: int = health_left(state, TacticalScenario.RED)
	var blue: int = health_left(state, TacticalScenario.BLUE)
	if red == blue:
		return TacticalVictory.DRAW
	return TacticalScenario.RED if red > blue else TacticalScenario.BLUE
