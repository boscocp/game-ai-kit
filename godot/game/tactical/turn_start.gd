## What happens between one side's turn and the next, in one place: the turn
## passes, the side to move is paid its income and its points, and then its
## towers fire.
##
## One place because the scene, the tests and the measuring scripts all play
## turns, and each used to call `end_turn` with the income by hand -- so a new
## rule at the start of a turn, such as the points (T44), would have reached
## the screen and not the measurements.
##
## Paid before the towers fire: a side is paid for what it held when its turn
## came, and a holder the tower then destroys was still holding.
##
## When not to use it: inside a turn. Nothing here is an action a side takes.
class_name TurnStart
extends RefCounted


## The next side's turn opened on `state`, as `[BoardState, Array[Array]]`:
## the new state and one line for each thing that happened -- points paid,
## towers fired -- in that order, each a `Sentence` worded where it is shown.
static func open(state: BoardState) -> Array:
	var next: BoardState = state.end_turn(TacticalScenario.FACTIONS, 0, TacticalRules.INCOME)
	var said: Array[Array] = []
	var paid: Array = ControlPoints.pay(next)
	if not (paid[1] as Array).is_empty():
		said.append(paid[1])
	var fired: Array = TacticalCombat.towers_fire(paid[0])
	said.append_array(fired[1])
	return [fired[0], said]
