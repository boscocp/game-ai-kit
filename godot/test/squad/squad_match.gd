# One game of the XCOM-style mode between two controllers, headless: red
# played by one `BlueController`, blue by another, through `BlueTurn` and
# `SquadRuleset` exactly as the tactical scene plays them (T85).
#
# Used by `weighed_squad_test.gd` for the seeded replay and by
# `squad_match_runner.gd` for `make test-squad-match`.
class_name SquadMatch
extends RefCounted


## Play to a winner, from the squads' start with `dice_seed`, and no further
## than the round limit allows. Returns {"winner", "rounds", "refused",
## "lost", "digest"}: "refused" and "lost" by side -- the decisions the board
## refused, and those of them the controller had nothing instead of -- and the
## digest sha256 of every turn's pieces, so one die that moves moves it.
##
## `between`, when given, is called with the side's controller each time it
## has just been asked a decision -- as its turn begins and after each
## decision is played -- for a measurement that lets a search think a frame
## at a time there (`squad_mcts_measure.gd`, T87).
static func play(red: BlueController, blue: BlueController, dice_seed: int, between: Callable = Callable()) -> Dictionary:
	var rules := SquadRuleset.new()
	var state: BoardState = rules.start()
	state.dice_seed = dice_seed
	var turns: Array[BlueTurn] = [BlueTurn.new(red, rules), BlueTurn.new(blue, rules)]
	var refused: Array[int] = [0, 0]
	var lost: Array[int] = [0, 0]
	var seen: Array = []
	var turns_allowed: int = SquadVictory.round_limit() * TacticalScenario.FACTIONS + 1
	while rules.winner(state) == TacticalVictory.NOBODY and state.turn_number <= turns_allowed:
		var turn: BlueTurn = turns[state.current_faction]
		turn.begin(state)
		_call(between, turn.controller)
		while not turn.finished() and rules.winner(state) == TacticalVictory.NOBODY:
			state = turn.play(state)
			_call(between, turn.controller)
		refused[state.current_faction] += turn.refused.size()
		lost[state.current_faction] += turn.lost.size()
		seen.append(pieces(state))
		if rules.winner(state) == TacticalVictory.NOBODY:
			state = rules.open_turn(state)[0]
	return {"winner": rules.winner(state), "rounds": state.turn_number / TacticalScenario.FACTIONS + 1,
		"refused": refused, "lost": lost, "digest": JSON.stringify(seen).sha256_text()}


static func _call(between: Callable, controller: BlueController) -> void:
	if between.is_valid():
		between.call(controller)


## Every piece on `state` as `[id, cell, health]`, in id order.
static func pieces(state: BoardState) -> Array:
	var found: Array = []
	for unit: Unit in state.units:
		found.append([unit.id, unit.cell.x, unit.cell.y, unit.health])
	found.sort_custom(func(one: Array, other: Array) -> bool: return one[0] < other[0])
	return found
