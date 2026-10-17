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
## hand (or null), the last refusal (or "") and what just happened (or "").
## `can_attack` is false for a piece that has attacked this turn: the status
## must not offer it targets it can no longer strike.
static func text(state: BoardState, in_hand: Unit, refusal: String, news: String = "", can_attack: bool = true) -> String:
	var lines: Array[String] = [_headline(state), ControlPoints.describe(state), _piece(in_hand), _what_to_do(state, in_hand)]
	var targets: String = _targets(state, in_hand) if can_attack else ""
	if targets != "":
		lines.append(targets)
	lines.append("Z takes back the last thing you did  ·  space ends your turn, and blue is paid %d and its points" % TacticalRules.INCOME)
	if news != "":
		lines.append("\n" + news)
	if refusal != BoardState.LEGAL:
		lines.append("\nrefused: " + refusal)
	return "\n".join(lines)


## What the status says on blue's turn: who is playing it, what it is about
## to do and why, and what to press.
static func blue_text(state: BoardState, turn: BlueTurn, controller: BlueController, news: String = "") -> String:
	var lines: Array[String] = [_headline(state), ControlPoints.describe(state), "blue is thinking with %s" % controller.controller_name()]
	if news != "":
		lines.append("\n" + news)
	if turn.next != null:
		lines.append("\nnext (drawn in pink): unit %d %s" % [turn.next.unit_id, turn.next.reason])
		lines.append("\nspace plays it  ·  enter plays the rest of blue's turn")
	else:
		lines.append("\nblue has finished its turn. Space hands it back to red")
	lines.append("\n%d decision(s) played this turn" % turn.played.size())
	return "\n".join(lines)


## A faction's name as the screen says it.
static func side_name(faction: int) -> String:
	return "red" if faction == TacticalScenario.RED else "blue"


# A round is both sides' turns. `BoardState.turn_number` counts each side's
# turn, so red's third turn is its turn 4 -- a person playing "three turns"
# counts rounds.
static func _headline(state: BoardState) -> String:
	var forge: String = "owned" if state.owns(state.current_faction, TacticalRules.FORGE) else "not owned"
	return "round %d  ·  %s to move  ·  funds %d  ·  forge %s" % [
		state.turn_number / TacticalScenario.FACTIONS + 1, side_name(state.current_faction),
		state.funds_of(state.current_faction), forge]


# What the piece is and what it can do, in the numbers a plan is made of.
static func _piece(unit: Unit) -> String:
	if unit == null:
		return "nothing in hand"
	var kind: UnitType = unit.type
	var beats: String = ", ".join(kind.strong_against) if not kind.strong_against.is_empty() else "nothing"
	var motion: String = "movement left %d" % unit.movement_points if kind.mobile else "does not move"
	# Sight is in the table and not on the screen: nothing uses it until there
	# is fog to see through (T20), and a number with no effect misleads.
	return "in hand: %s (unit %d)  ·  health %d  ·  %s  ·  reach %d  ·  beats %s" % [
		kind.type_name, unit.id, unit.health, motion, kind.attack_range, beats]


static func _what_to_do(state: BoardState, unit: Unit) -> String:
	if unit == null:
		return "click one of your pieces."
	if not unit.type.produces.is_empty():
		if state.owns(state.current_faction, TacticalRules.FORGE):
			return "press 1-5 to build: %s." % _price_list()
		return "press 1-5 to build: %s. U buys the forge (%d)." % [_price_list(), TacticalRules.FORGE_COST]
	if not unit.type.mobile:
		return "a %s cannot move. Click another of your pieces." % unit.type.type_name
	if unit.movement_points == 0:
		return "this unit has no movement left. Click another of your pieces."
	return "click a lit cell to walk there, and the unit is spent until your next turn; W has it wait where it is. A step costs the number on the cell, or 1."


# The enemies the piece in hand could attack from where it stands, with how
# the counter table leans on each fight -- or "" when none is in reach.
static func _targets(state: BoardState, unit: Unit) -> String:
	if unit == null or unit.type.attack_range <= 0:
		return ""
	var parts: Array[String] = []
	for enemy: Unit in state.units:
		if TacticalCombat.why_refused(state, Attack.new(unit.id, enemy.id)) != BoardState.LEGAL:
			continue
		var lean: int = TacticalCombat.counter(unit.type, enemy.type)
		var said: String = " (you beat it)" if lean > 0 else (" (it beats you)" if lean < 0 else "")
		parts.append("the %s at %s, health %d%s" % [enemy.type.type_name, enemy.cell, enemy.health, said])
	if parts.is_empty():
		return ""
	return "click an enemy to attack it, once a turn: " + "; ".join(parts)


static func _price_list() -> String:
	var types: Dictionary = TacticalRules.unit_types()
	var parts: Array[String] = []
	for index: int in range(TacticalRules.BUILDABLE.size()):
		var kind: UnitType = types[TacticalRules.BUILDABLE[index]]
		parts.append("%d %s (%d)" % [index + 1, kind.type_name, kind.cost])
	return ", ".join(parts)
