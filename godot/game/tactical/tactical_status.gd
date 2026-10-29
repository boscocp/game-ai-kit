## The words beside the tactical board: whose turn, what they have to spend,
## what is in hand and what it does, and what to press next.
##
## Its own file because it is the one part of the scene a first-time player
## reads before anything else, and a test can read it the same way: given a
## state and a piece, it returns the text, with nothing else to set up.
##
## Every word goes through `TranslationServer.translate` (T79): these are
## static functions, and `tr()` is a method of an object. The names of the
## pieces are here too, with their articles, because Portuguese gives a tower
## another article than a runner, so "the {piece}" cannot be one key.
##
## A team's reasons are kept as a `Sentence` (T104): its English key and its
## values. `said` words one in the language on screen, here, where it is
## shown -- so the AI's state is the same in any language, and a language
## switched mid-turn rewords the last reason with the rest.
##
## When not to use it: anything the player has not got in hand. The status
## describes one piece; the legend describes the rest.
class_name TacticalStatus
extends RefCounted

## Each piece with "the" before it, as a sentence names it.
const THE_PIECE: Dictionary = {  # shown through tr()
	TacticalRules.RUNNER: "the runner", TacticalRules.SHIELD: "the shield",
	TacticalRules.MORTAR: "the mortar", TacticalRules.WADER: "the wader",
	TacticalRules.RAM: "the ram", TacticalRules.BOLT_TOWER: "the bolt tower",
	TacticalRules.WATCHTOWER: "the watchtower", TacticalRules.WORKSHOP: "the workshop",
}
## Each piece with "a" before it.
const A_PIECE: Dictionary = {  # shown through tr()
	TacticalRules.RUNNER: "a runner", TacticalRules.SHIELD: "a shield",
	TacticalRules.MORTAR: "a mortar", TacticalRules.WADER: "a wader",
	TacticalRules.RAM: "a ram", TacticalRules.BOLT_TOWER: "a bolt tower",
	TacticalRules.WATCHTOWER: "a watchtower", TacticalRules.WORKSHOP: "a workshop",
}


## Everything the status says, line by line, for this state, this piece in
## hand (or null), the last refusal (or "") and what just happened (or "").
## `can_attack` is false for a piece that has attacked this turn: the status
## must not offer it targets it can no longer strike.
static func text(state: BoardState, in_hand: Unit, refusal: String, news: String = "", can_attack: bool = true) -> String:
	var lines: Array[String] = [_headline(state), ControlPoints.describe(state), _piece(in_hand), _what_to_do(state, in_hand)]
	var targets: String = _targets(state, in_hand) if can_attack else ""
	if targets != "":
		lines.append(targets)
	lines.append(TranslationServer.translate("Z takes back the last thing you did  ·  space ends your turn, and {side} is paid {income} and its points").format({
		side = side_name(TacticalScenario.FACTIONS - 1 - state.current_faction), income = TacticalRules.INCOME}))
	if news != "":
		lines.append("\n" + news)
	if refusal != BoardState.LEGAL:
		lines.append("\n" + TranslationServer.translate("refused: {why}").format({why = TacticalRefusal.words(refusal)}))
	return "\n".join(lines)


## What the status says on the computer's turn, whichever side it plays: who
## is playing it, what it is about to do and why, and what to press. One
## blank line, before the decision, sets it apart; the news, the keys, the
## count and the plan follow without one. A played game's planner turn in
## pt-BR -- a strike's news, a long reason, six steps -- needed the room
## (T102 and its review).
static func computer_text(state: BoardState, turn: BlueTurn, controller: BlueController, news: String = "") -> String:
	var side: String = side_name(state.current_faction)
	var lines: Array[String] = [_headline(state), ControlPoints.describe(state),
		TranslationServer.translate("{side} is thinking with {controller}").format({side = side, controller = controller_said(controller)})]
	if news != "":
		lines.append(news)
	if turn.next != null:
		lines.append("\n" + TranslationServer.translate("next (drawn in pink): unit {unit} {why}").format({unit = turn.next.unit_id, why = said(turn.next.reason)}))
		lines.append(TranslationServer.translate("space plays it  ·  enter plays the rest of {side}'s turn").format({side = side}))
	else:
		lines.append("\n" + TranslationServer.translate("{side} has finished its turn. Space hands it back to {other}").format({
			side = side, other = side_name(TacticalScenario.FACTIONS - 1 - state.current_faction)}))
	lines.append(TranslationServer.translate("{count} decision(s) played this turn").format({count = turn.played.size()}))
	var plan: Array[String] = controller.plan_lines(said)
	if not plan.is_empty():
		lines.append("\n".join(plan) + "\n" + TranslationServer.translate("(the numbers on the board are the pieces each step counts on)"))
	return "\n".join(lines)


## A controller's name as the screen says it: its roster name, translated.
## The name itself stays the one `TacticalRoster` and the league look up.
static func controller_said(controller: BlueController) -> String:
	return name_said(controller.controller_name())


## A roster name as the screen says it. "learned" is said "learned policy":
## checkers' table already gives the word "learned" to its weights, in the
## plural, and one key has one translation in the whole game.
static func name_said(roster_name: String) -> String:
	if roster_name == "learned":  # not shown
		return TranslationServer.translate("learned policy")
	return TranslationServer.translate(roster_name)


## A piece's name as the screen says it: "runner", or "corredor".
static func piece(type_name: String) -> String:
	return TranslationServer.translate(type_name)


## A piece with "the" before it, in the language on screen.
static func the_piece(type_name: String) -> String:
	return TranslationServer.translate(THE_PIECE.get(type_name, type_name))


## A piece with "a" before it, in the language on screen.
static func a_piece(type_name: String) -> String:
	return TranslationServer.translate(A_PIECE.get(type_name, type_name))


## Several pieces' names as a list, "mortar, ram", in the language on screen.
static func pieces(type_names: Array) -> String:
	var said: Array[String] = []
	for type_name: String in type_names:
		said.append(piece(type_name))
	return ", ".join(said)


## A sentence a team kept, in the language on screen: its key translated,
## and each value worded by `word`.
static func said(sentence: Array) -> String:
	return Sentence.translated(sentence, TacticalStatus.word)


## A value of a kept sentence as the screen says it: a board's refusal by its
## shape, a piece's name or another key through the tables, and anything
## else -- a plan's step, a fact, a number -- as it is.
static func word(value: String) -> String:
	return TacticalRefusal.words(value)


## A piece with "the" before it, as a value of a kept sentence.
static func the_piece_sentence(type_name: String) -> Array:
	return Sentence.of(THE_PIECE.get(type_name, type_name))


## A piece with "a" before it, as a value of a kept sentence.
static func a_piece_sentence(type_name: String) -> Array:
	return Sentence.of(A_PIECE.get(type_name, type_name))


## Several values as one value of a kept sentence, "mortar, ram": each is
## worded on its own where it is shown. Empty for none.
static func listed(values: Array) -> Array:
	return _chained(values, "{first}, {rest}")


## Several deeds as one value of a kept sentence, in the order they come:
## "hunt then siege".
static func in_order(values: Array) -> Array:
	return _chained(values, "{first} then {rest}")  # shown through tr()


# `values` as nested sentences, the first and the rest joined by `key`.
static func _chained(values: Array, key: String) -> Array:
	if values.is_empty():
		return []
	if values.size() == 1:
		return Sentence.of("{only}", {only = values[0]})
	return Sentence.of(key, {first = values[0], rest = _chained(values.slice(1), key)})


## A faction's name as the screen says it.
static func side_name(faction: int) -> String:
	if faction == TacticalScenario.RED:
		return TranslationServer.translate("red")
	return TranslationServer.translate("blue")


# A round is both sides' turns. `BoardState.turn_number` counts each side's
# turn, so red's third turn is its turn 4 -- a person playing "three turns"
# counts rounds.
static func _headline(state: BoardState) -> String:
	var forge: String = TranslationServer.translate("not owned")
	if state.owns(state.current_faction, TacticalRules.FORGE):
		forge = TranslationServer.translate("owned")
	return TranslationServer.translate("round {round}  ·  {side} to move  ·  funds {funds}  ·  forge {forge}").format({
		round = state.turn_number / TacticalScenario.FACTIONS + 1, side = side_name(state.current_faction),
		funds = state.funds_of(state.current_faction), forge = forge})


# What the piece is and what it can do, in the numbers a plan is made of.
static func _piece(unit: Unit) -> String:
	if unit == null:
		return TranslationServer.translate("nothing in hand")
	var kind: UnitType = unit.type
	var beats: String = TranslationServer.translate("nothing")
	if not kind.strong_against.is_empty():
		beats = pieces(kind.strong_against)
	var motion: String = TranslationServer.translate("does not move")
	if kind.mobile:
		motion = TranslationServer.translate("movement left {points}").format({points = unit.movement_points})
	# Sight is in the table and not on the screen: nothing uses it until there
	# is fog to see through (T20), and a number with no effect misleads.
	return TranslationServer.translate("in hand: {piece} (unit {unit})  ·  health {health}  ·  {motion}  ·  reach {reach}  ·  beats {beats}").format({
		piece = piece(kind.type_name), unit = unit.id, health = unit.health, motion = motion,
		reach = kind.attack_range, beats = beats})


static func _what_to_do(state: BoardState, unit: Unit) -> String:
	if unit == null:
		return TranslationServer.translate("click one of your pieces.")
	if not unit.type.produces.is_empty():
		if state.owns(state.current_faction, TacticalRules.FORGE):
			return TranslationServer.translate("press 1-5 to build: {prices}.").format({prices = _price_list()})
		return TranslationServer.translate("press 1-5 to build: {prices}. U buys the forge ({cost}).").format({
			prices = _price_list(), cost = TacticalRules.FORGE_COST})
	if not unit.type.mobile:
		return TranslationServer.translate("{piece} cannot move. Click another of your pieces.").format({piece = a_piece(unit.type.type_name)})
	if unit.movement_points == 0:
		return TranslationServer.translate("this unit has no movement left. Click another of your pieces.")
	return TranslationServer.translate("click a lit cell to walk there, and the unit is spent until your next turn; W has it wait where it is. A step costs the number on the cell, or 1.")


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
		var target: String = TranslationServer.translate("{piece} at {cell}, health {health}")
		if lean > 0:
			target = TranslationServer.translate("{piece} at {cell}, health {health} (you beat it)")
		elif lean < 0:
			target = TranslationServer.translate("{piece} at {cell}, health {health} (it beats you)")
		parts.append(target.format({piece = the_piece(enemy.type.type_name), cell = enemy.cell, health = enemy.health}))
	if parts.is_empty():
		return ""
	return TranslationServer.translate("click an enemy to attack it, once a turn: {targets}").format({targets = "; ".join(parts)})


static func _price_list() -> String:
	var types: Dictionary = TacticalRules.unit_types()
	var parts: Array[String] = []
	for index: int in range(TacticalRules.BUILDABLE.size()):
		var kind: UnitType = types[TacticalRules.BUILDABLE[index]]
		parts.append("%d %s (%d)" % [index + 1, piece(kind.type_name), kind.cost])
	return ", ".join(parts)
