# One game of the tactical scenario between two controllers, headless: red
# played by one `BlueController`, blue by another, every turn opened by
# `TurnStart` exactly as the scene opens it.
#
# A controller decides for whichever side is to move -- `RuleBasedBlue`
# reads `state.current_faction`, not "blue" -- so the same rules can play
# red, and its sentences say "the enemy", which is right from either side.
#
# Used by the learned blue's tests and by `tactical_win_rates.gd`.
class_name TacticalMatch
extends RefCounted


## Play to a winner or the round limit, from the scenario with `dice_seed`
## -- and no further: a game still going after the round limit's turns, which
## `TacticalVictory` says cannot happen, returns `NOBODY` rather than hanging
## whoever called it.
## `watch`, when given, is called with the state at the start of every turn,
## after the turn has opened -- which is when points are paid and a hold is
## counted. Returns {"winner", "rounds", "decisions", "refused",
## "at_the_limit"} -- the last true when the game was settled by score or a
## draw at the round limit rather than at a workshop (T47).
static func play(red: BlueController, blue: BlueController, dice_seed: int,
		watch: Callable = Callable()) -> Dictionary:
	var state: BoardState = TacticalScenario.build()
	state.dice_seed = dice_seed
	var turns: Array[BlueTurn] = [BlueTurn.new(red), BlueTurn.new(blue)]
	var decisions: int = 0
	var refused: Array[TacticalDecision] = []
	var turns_allowed: int = TacticalVictory.ROUND_LIMIT * TacticalScenario.FACTIONS + 1
	while TacticalVictory.winner(state) == TacticalVictory.NOBODY and state.turn_number <= turns_allowed:
		if watch.is_valid():
			watch.call(state)
		var turn: BlueTurn = turns[state.current_faction]
		turn.begin(state)
		while not turn.finished() and TacticalVictory.winner(state) == TacticalVictory.NOBODY:
			state = turn.play(state)
			decisions += 1
		refused.append_array(turn.refused)
		if TacticalVictory.winner(state) == TacticalVictory.NOBODY:
			state = TurnStart.open(state)[0]
	return {
		"winner": TacticalVictory.winner(state),
		# A draw is called when round 41 would open; it lasted 40.
		"rounds": mini(state.turn_number / TacticalScenario.FACTIONS + 1, TacticalVictory.ROUND_LIMIT),
		"at_the_limit": TacticalVictory.at_the_limit(state),
		"decisions": decisions,
		"refused": refused,
	}
