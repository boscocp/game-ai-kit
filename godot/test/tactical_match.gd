# One game of the tactical scenario between two controllers, headless: red
# played by one `BlueController`, blue by another, every turn opened by
# `TurnStart` exactly as the scene opens it.
#
# A controller decides for whichever side is to move -- `RuleBasedBlue`
# reads `state.current_faction`, not "blue" -- so the same rules can play
# red. Its sentences still say "red's workshop", which nobody reads here.
#
# Used by the learned blue's tests, by `export_capture_rows.gd`, which cuts
# the capture model's rows out of these games, and by the win rates in T44.
class_name TacticalMatch
extends RefCounted


## Play to a winner or the round limit, from the scenario with `dice_seed`.
## `watch`, when given, is called with the state at the start of every turn,
## after the turn has opened -- which is when points are paid and a hold is
## counted. Returns {"winner", "rounds", "decisions", "refused"}.
static func play(red: BlueController, blue: BlueController, dice_seed: int,
		watch: Callable = Callable()) -> Dictionary:
	var state: BoardState = TacticalScenario.build()
	state.dice_seed = dice_seed
	var turns: Array[BlueTurn] = [BlueTurn.new(red), BlueTurn.new(blue)]
	var decisions: int = 0
	var refused: Array[TacticalDecision] = []
	while TacticalVictory.winner(state) == TacticalVictory.NOBODY:
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
		"rounds": state.turn_number / TacticalScenario.FACTIONS + 1,
		"decisions": decisions,
		"refused": refused,
	}
