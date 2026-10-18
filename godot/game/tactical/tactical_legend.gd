## What the legend beside the tactical board says: the sides, the ground, and
## one line per kind of piece, beside the picture it is drawn with.
##
## The type lines are built from the rules table rather than typed out, so
## the legend cannot claim a runner moves 6 after somebody changes it to 5.
##
## When not to use it: the other scenes. Their legends are short enough to
## read in place.
class_name TacticalLegend
extends RefCounted


## The legend's entries, `[Color or Texture2D, String]` each, for these types.
static func entries(types: Dictionary) -> Array[Array]:
	var lines: Array[Array] = [
		[_picture(TacticalScenario.RED, TacticalRules.RUNNER), "red side: yours"],
		[_picture(TacticalScenario.BLUE, TacticalRules.RUNNER), "blue side: the computer"],
		[BoardView.REACHABLE, "where the piece in hand can walk"],
		[UnitView.SPENT_TINT, "greyed: moved this turn"],
		[UnitView.HEALTH_TEXT, "yellow number: health"],
		[IntentView.INTENT, "pink: what blue will do next"],
		[IntentView.THREAT, "red: enemy reach (T)"],
		[BoardView.tile_texture(BoardView.PLAIN), "open ground"],
		[BoardView.tile_texture(BoardView.TREES), "trees: cost 3 to enter"],
		[BoardView.tile_texture(BoardView.WALL), "rock: nothing crosses"],
		[BoardView.tile_texture(BoardView.WATER), "deep water: only waders cross"],
		[BoardView.tile_texture(BoardView.BRIDGE), "bridge: the quick crossing"],
		[BoardView.tile_texture(BoardView.ROUGH), "ford: anyone crosses, cost %d" % TacticalRules.FORD_COST],
		[BoardView.tile_texture(BoardView.NODE), "flag: a point, +%d a turn to its holder" % TacticalRules.POINT_INCOME],
	]
	for name: String in types:
		lines.append([_picture(TacticalScenario.RED, name), describe(types[name], types)])
	return lines


## "runner: moves 6, beats mortar, ram" -- the name, and the two facts that
## make the type a choice. A type that beats every building says so in three
## words: the ram's three names ran the legend off a 1280-pixel screen.
static func describe(kind: UnitType, types: Dictionary) -> String:
	var motion: String = "moves %d" % kind.movement if kind.mobile else "fixed"
	var buildings: Array[String] = []
	for name: String in types:
		if not (types[name] as UnitType).mobile:
			buildings.append(name)
	var against: Array[String] = kind.strong_against.duplicate()
	against.sort()
	buildings.sort()
	var beaten: String = "every building" if against == buildings else ", ".join(kind.strong_against)
	var beats: String = ", beats " + beaten if not kind.strong_against.is_empty() else ""
	return "%s: %s%s" % [kind.type_name, motion, beats]


static func _picture(faction: int, type_name: String) -> Texture2D:
	return UnitView.legend_picture(faction, type_name)
