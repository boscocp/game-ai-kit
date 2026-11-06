## What the legend beside the board says in the XCOM-style mode (T85): the
## sides, the two tints of a walk, the fog, the numbers on the board, the
## ground as cover, the keys that build a map and its marks (T96), and one
## line per piece with the numbers of its shot.
##
## The piece lines are built from `SquadTable`, so the legend cannot claim a
## runner aims 65 after somebody changes it to 60 in `rules.json`.
##
## When not to use it: the Advance Wars mode, whose legend is
## `TacticalLegend` -- workshops, towers, funds and a counter table.
class_name SquadLegend
extends RefCounted


## The legend's entries, `[Color or Texture2D, String]` each.
static func entries() -> Array[Array]:
	var lines: Array[Array] = [
		[_picture(TacticalScenario.RED), TranslationServer.translate("red side: yours")],
		[_picture(TacticalScenario.BLUE), TranslationServer.translate("blue side: the computer")],
		[BoardView.REACHABLE, TranslationServer.translate("light: a walk that keeps the shot")],
		[IntentView.DASH, TranslationServer.translate("amber: a dash, the piece's whole turn")],
		[IntentView.FOG, TranslationServer.translate("dark: that side sees nothing here")],
		[IntentView.GHOST, TranslationServer.translate("faded, with ?: last seen there")],
		[UnitView.SPENT_TINT, TranslationServer.translate("greyed: acted this turn")],
		[UnitView.HEALTH_TEXT, TranslationServer.translate("yellow number: health")],
		[IntentView.LABEL, TranslationServer.translate("a % on an enemy: your hit chance")],
		[IntentView.LABEL_GROUND, TranslationServer.translate("on its turn: each option's score")],
		[IntentView.INTENT, TranslationServer.translate("pink: what the computer will do next")],
		[IntentView.THREAT, TranslationServer.translate("red (T): enemy odds on the cursor")],
		[BoardView.tile_texture(BoardView.PLAIN), TranslationServer.translate("open ground")],
		[BoardView.tile_texture(BoardView.TREES), TranslationServer.translate("trees: half cover ({half})").format({half = SquadTable.cover_worth("half")})],
		[BoardView.tile_texture(BoardView.WALL), TranslationServer.translate("rock: full cover ({full})").format({full = SquadTable.cover_worth("full")})],
		[BoardView.tile_texture(BoardView.WALL), TranslationServer.translate("trees and rock block sight")],
		[BoardView.tile_texture(BoardView.WATER), TranslationServer.translate("deep water: only waders cross")],
		[IntentView.LABEL, TranslationServer.translate("N new map, B a cell at a time")],
		[IntentView.DASH, TranslationServer.translate("amber: least entropy, next")],
		[IntentView.THREAT, TranslationServer.translate("red 0: a contradiction")],
	]
	for piece_name: String in SquadTable.squad():
		lines.append([_picture(TacticalScenario.RED, piece_name), describe(piece_name)])
	return lines


## "runner: aim 65, defence 10" -- the two numbers a hit chance starts from.
## The rest of a piece's numbers are in the status when it is in hand: the
## legend's column holds about thirty-five letters.
static func describe(piece_name: String) -> String:
	return TranslationServer.translate("{piece}: aim {aim}, defence {defence}").format({
		piece = TacticalStatus.piece(piece_name), aim = SquadTable.number(piece_name, "aim"),
		defence = SquadTable.number(piece_name, "defence")})


static func _picture(side: int, piece_name: String = TacticalRules.RUNNER) -> Texture2D:
	return UnitView.legend_picture(side, piece_name)
