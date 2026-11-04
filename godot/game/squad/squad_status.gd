## The words beside the board in the XCOM-style mode (T85): whose turn, the
## piece in hand and its numbers, what it can do, and -- before any shot --
## each target's hit chance with the sum that made it.
##
## `TacticalStatus` is the Advance Wars status: funds, the forge, a counter
## table, income at the end of the turn. None of those is in this mode, and
## a person reading them would look for a workshop that is not there. What
## this mode has instead is the shot's arithmetic, so the status spells it
## out -- "63% = aim 65 - defence 20 - cover 0, flanked" -- for every enemy
## the piece in hand may shoot, which is the hit chance and its reasons that
## step 2 asks for. The same chance is written on the target on the board.
##
## When not to use it: the Advance Wars mode, whose status is
## `TacticalStatus`. The two share the names of the sides and the pieces.
class_name SquadStatus
extends RefCounted

## The shot's refusals, as `SquadCombat.why_refused` writes them, as keys:
## a refusal is worded by its shape where it reaches the screen, as
## `TacticalRefusal` words the board's.
const SHAPES: Array[String] = [  # shown through tr()
	"no unit {id} is on the board",
	"unit {id} is not on the side to move",
	"unit {id} has dashed or shot this turn",
	"unit {id} is on the same side",
	"unit {shooter} sees no enemy unit {target} to shoot",
	"unit {target} is {apart} away, and unit {shooter} reaches {reach}",
]


## Everything the status says on the person's turn, line by line: the
## round, the piece in hand (or null) and what to do with it, its shots
## when `can_attack`, what just happened and the last refusal.
static func text(state: BoardState, in_hand: Unit, refusal: String, news: String, can_attack: bool) -> String:
	var lines: Array[String] = [headline(state), _piece(in_hand), _what_to_do(in_hand)]
	var shots: Array[String] = shot_lines(state, in_hand) if can_attack else [] as Array[String]
	if not shots.is_empty():
		lines.append(TranslationServer.translate("click an enemy to shoot it; the chance, and why:"))
		lines.append_array(shots)
	lines.append(TranslationServer.translate("Z takes back a walk that drew no dice and showed no enemy  ·  space ends your turn"))
	if news != "":
		lines.append("\n" + news)
	if refusal != BoardState.LEGAL:
		lines.append("\n" + TranslationServer.translate("refused: {why}").format({why = words(refusal)}))
	return "\n".join(lines)


## What the status says on the computer's turn: who plays it, what it is
## about to do and why, and how to read what it weighed on the board.
static func computer_text(state: BoardState, turn: BlueTurn, controller: BlueController, news: String) -> String:
	var side: String = TacticalStatus.side_name(state.current_faction)
	var lines: Array[String] = [headline(state), TranslationServer.translate("{side} is thinking with {controller}").format({
		side = side, controller = TacticalStatus.controller_said(controller)})]
	if news != "":
		lines.append(news)
	if turn.next != null:
		lines.append("\n" + TranslationServer.translate("next (drawn in pink): unit {unit} {why}").format({
			unit = turn.next.unit_id, why = TacticalStatus.said(turn.next.reason)}))
		lines.append(TranslationServer.translate("space plays it  ·  enter plays the rest of {side}'s turn").format({side = side}))
		if not controller.weighed().is_empty():
			lines.append(TranslationServer.translate("on the board, every option it weighed: its score above, its best hit chance below, the one it takes framed; V hides them"))
	else:
		lines.append("\n" + TranslationServer.translate("{side} has finished its turn. Space hands it back to {other}").format({
			side = side, other = TacticalStatus.side_name(TacticalScenario.FACTIONS - 1 - state.current_faction)}))
	lines.append(TranslationServer.translate("{count} decision(s) played this turn").format({count = turn.played.size()}))
	return "\n".join(lines)


## The first line: the round, the side to move, and each side's health.
static func headline(state: BoardState) -> String:
	return TranslationServer.translate("round {round}  ·  {side} to move  ·  health left: red {red}, blue {blue}").format({
		round = state.turn_number / TacticalScenario.FACTIONS + 1, side = TacticalStatus.side_name(state.current_faction),
		red = SquadVictory.health_left(state, TacticalScenario.RED), blue = SquadVictory.health_left(state, TacticalScenario.BLUE)})


## One line for each enemy `shooter` may shoot now: the target, its chance,
## and the sum behind it -- the shooter's aim, the target's defence, the
## cover that faces the shooter, and whether the shooter has flanked it.
static func shot_lines(state: BoardState, shooter: Unit) -> Array[String]:
	var lines: Array[String] = []
	if shooter == null:
		return lines
	var rows: Array[String] = SquadScenario.rows()
	for enemy: Unit in state.units:
		if SquadCombat.why_refused(state, rows, Attack.new(shooter.id, enemy.id)) != BoardState.LEGAL:
			continue
		var given: Dictionary = SquadCombat.inputs(rows, shooter, enemy)
		var line: String = TranslationServer.translate("{piece} at {cell}: {chance}% = aim {aim} - defence {defence} - cover {cover}")
		if given["flanked"]:
			line = TranslationServer.translate("{piece} at {cell}: {chance}% = aim {aim} - defence {defence} - cover {cover}, flanked")
		lines.append(line.format({piece = TacticalStatus.the_piece(enemy.type.type_name), cell = enemy.cell,
			chance = SquadCombat.hit_chance(given["aim"], given["defence"], given["cover"]),
			aim = given["aim"], defence = given["defence"], cover = given["cover"]}))
	return lines


## A refusal in the language on screen: a shot's by its shape, anything else
## -- the board's walk -- as the Advance Wars status words it.
static func words(refusal: String) -> String:
	var worded: String = TacticalRefusal.worded_by(refusal, SHAPES)
	return worded if worded != "" else TacticalRefusal.words(refusal)


# What the piece is, in the numbers a shot is made of.
static func _piece(unit: Unit) -> String:
	if unit == null:
		return TranslationServer.translate("nothing in hand")
	var kind: String = unit.type.type_name
	return TranslationServer.translate("in hand: {piece} (unit {unit})  ·  health {health}  ·  aim {aim}, defence {defence}, damage {damage}  ·  range {range}, sight {sight}  ·  movement left {points}, an action is {action}").format({
		piece = TacticalStatus.piece(kind), unit = unit.id, health = unit.health, aim = SquadTable.number(kind, "aim"),
		defence = SquadTable.number(kind, "defence"), damage = SquadTable.number(kind, "damage"), range = unit.type.attack_range,
		sight = unit.type.sight, points = unit.movement_points, action = SquadTable.action(kind)})


static func _what_to_do(unit: Unit) -> String:
	if unit == null:
		return TranslationServer.translate("click one of your pieces.")
	if unit.movement_points == 0:
		return TranslationServer.translate("this piece has acted this turn. Click another of your pieces.")
	if not SquadCombat.can_shoot(unit):
		return TranslationServer.translate("this piece has dashed: it may not shoot this turn. Click another of your pieces.")
	return TranslationServer.translate("click a lit cell to walk there: a light cell keeps the shot, an amber one is a dash and ends the piece's turn. Or shoot first, from here.")
