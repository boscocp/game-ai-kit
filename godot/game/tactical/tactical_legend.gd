## What the legend beside the tactical board says: the sides, the ground, and
## one line per kind of piece, beside the picture it is drawn with.
##
## The type lines are built from the rules table rather than typed out, so
## the legend cannot claim a runner moves 6 after somebody changes it to 5.
##
## Static, so its words go through `TranslationServer.translate` (T79); the
## scene asks for the entries again when the language changes.
##
## When not to use it: the other scenes. Their legends are short enough to
## read in place.
class_name TacticalLegend
extends RefCounted


## The legend's entries, `[Color or Texture2D, String]` each, for these types.
static func entries(types: Dictionary) -> Array[Array]:
	var lines: Array[Array] = [
		[_picture(TacticalScenario.RED, TacticalRules.RUNNER), TranslationServer.translate("red side: yours")],
		[_picture(TacticalScenario.BLUE, TacticalRules.RUNNER), TranslationServer.translate("blue side: the computer")],
		[BoardView.REACHABLE, TranslationServer.translate("where the piece in hand can walk")],
		[UnitView.SPENT_TINT, TranslationServer.translate("greyed: moved this turn")],
		[UnitView.HEALTH_TEXT, TranslationServer.translate("yellow number: health")],
		[IntentView.INTENT, TranslationServer.translate("pink: what blue will do next")],
		[IntentView.THREAT, TranslationServer.translate("red: enemy reach (T)")],
		[BoardView.tile_texture(BoardView.PLAIN), TranslationServer.translate("open ground")],
		[BoardView.tile_texture(BoardView.TREES), TranslationServer.translate("trees: cost 3 to enter")],
		[BoardView.tile_texture(BoardView.WALL), TranslationServer.translate("rock: nothing crosses")],
		[BoardView.tile_texture(BoardView.WATER), TranslationServer.translate("deep water: only waders cross")],
		[BoardView.tile_texture(BoardView.BRIDGE), TranslationServer.translate("bridge: the quick crossing")],
		[BoardView.tile_texture(BoardView.ROUGH), TranslationServer.translate("ford: anyone crosses, cost {cost}").format({cost = TacticalRules.FORD_COST})],
		[BoardView.tile_texture(BoardView.NODE), TranslationServer.translate("flag: a point, +{income} a turn to its holder").format({income = TacticalRules.POINT_INCOME})],
	]
	for name: String in types:
		lines.append([_picture(TacticalScenario.RED, name), describe(types[name], types)])
	return lines


## "runner: moves 6, beats mortar, ram" -- the name, and the two facts that
## make the type a choice. A type that beats every building says so in three
## words: the ram's three names ran the legend off a 1280-pixel screen.
static func describe(kind: UnitType, types: Dictionary) -> String:
	var motion: String = TranslationServer.translate("fixed")
	if kind.mobile:
		motion = TranslationServer.translate("moves {cells}").format({cells = kind.movement})
	var buildings: Array[String] = []
	for name: String in types:
		if not (types[name] as UnitType).mobile:
			buildings.append(name)
	var against: Array[String] = kind.strong_against.duplicate()
	against.sort()
	buildings.sort()
	var beaten: String = TacticalStatus.pieces(kind.strong_against)
	if against == buildings:
		beaten = TranslationServer.translate("every building")
	if kind.strong_against.is_empty():
		return "%s: %s" % [TacticalStatus.piece(kind.type_name), motion]
	return TranslationServer.translate("{piece}: {motion}, beats {beaten}").format({
		piece = TacticalStatus.piece(kind.type_name), motion = motion, beaten = beaten})


static func _picture(faction: int, type_name: String) -> Texture2D:
	return UnitView.legend_picture(faction, type_name)
