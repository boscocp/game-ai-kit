## The words beside the tactical board: whose turn, what they have to spend,
## what is in hand and what it does, and what to press next.
##
## Its own file because it is the one part of the scene a first-time player
## reads before anything else, and a test can read it the same way: given a
## state and a piece, it returns the text, with nothing else to set up.
##
## When not to use it: anything the player has not got in hand. The status
## describes one piece; the legend describes the rest.
class_name TacticalStatus
extends RefCounted


## Everything the status says, line by line, for this state, this piece in
## hand (or null), and the last refusal (or "").
static func text(state: BoardState, in_hand: Unit, refusal: String) -> String:
	var lines: Array[String] = [_headline(state), _piece(in_hand), _what_to_do(state, in_hand)]
	lines.append("space ends your turn; the next side is paid %d" % TacticalRules.INCOME)
	if refusal != BoardState.LEGAL:
		lines.append("\nrefused: " + refusal)
	return "\n".join(lines)


static func _headline(state: BoardState) -> String:
	var side: String = "red" if state.current_faction == TacticalScenario.RED else "blue"
	var forge: String = "owned" if state.owns(state.current_faction, TacticalRules.FORGE) else "not owned"
	return "turn %d  ·  %s to move  ·  funds %d  ·  forge %s" % [
		state.turn_number, side, state.funds_of(state.current_faction), forge]


# What the piece is and what it can do, in the numbers a plan is made of.
static func _piece(unit: Unit) -> String:
	if unit == null:
		return "nothing in hand"
	var kind: UnitType = unit.type
	var beats: String = ", ".join(kind.strong_against) if not kind.strong_against.is_empty() else "nothing"
	var motion: String = "movement left %d" % unit.movement_points if kind.mobile else "does not move"
	return "in hand: %s (unit %d)  ·  %s  ·  reach %d  ·  sight %d  ·  beats %s" % [
		kind.type_name, unit.id, motion, kind.attack_range, kind.sight, beats]


static func _what_to_do(state: BoardState, unit: Unit) -> String:
	if unit == null:
		return "click one of your pieces."
	if not unit.type.produces.is_empty():
		return "press 1-5 to build: %s. U buys the forge (%d)." % [_price_list(), TacticalRules.FORGE_COST]
	if not unit.type.mobile:
		return "a %s cannot move. Click another of your pieces." % unit.type.type_name
	if unit.movement_points == 0:
		return "this unit has no movement left. Click another of your pieces."
	return "click a highlighted cell to step there. A step costs the number on the cell, or 1."


static func _price_list() -> String:
	var types: Dictionary = TacticalRules.unit_types()
	var parts: Array[String] = []
	for index: int in range(TacticalRules.BUILDABLE.size()):
		var kind: UnitType = types[TacticalRules.BUILDABLE[index]]
		parts.append("%d %s (%d)" % [index + 1, kind.type_name, kind.cost])
	return ", ".join(parts)
