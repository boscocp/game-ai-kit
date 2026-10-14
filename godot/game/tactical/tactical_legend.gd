## What the legend beside the tactical board says: the sides, the ground, and
## one line per kind of piece with the label drawn on it.
##
## The type lines are built from the rules table rather than typed out, so
## the legend cannot claim a runner moves 6 after somebody changes it to 5.
##
## When not to use it: the other scenes. Their legends are short enough to
## read in place.
class_name TacticalLegend
extends RefCounted


## The legend's entries, `[Color, String]` each, for these types.
static func entries(types: Dictionary) -> Array[Array]:
	var lines: Array[Array] = [
		[UnitView.FACTION_COLOURS[TacticalScenario.RED], "red side"],
		[UnitView.FACTION_COLOURS[TacticalScenario.BLUE], "blue side"],
		[Color.TRANSPARENT, "circle walks, square stands still"],
		[BoardView.REACHABLE, "where the piece in hand can step"],
		[BoardView.SWATCHES[BoardView.PLAIN.x], "open ground"],
		[BoardView.SWATCHES[BoardView.ROUGH.x], "trees: cost 3, block sight"],
		[BoardView.SWATCHES[BoardView.WALL.x], "rock"],
		[BoardView.SWATCHES[BoardView.WATER.x], "water: only waders cross"],
	]
	for name: String in TacticalGame.LABELS:
		lines.append([Color.TRANSPARENT, _describe(TacticalGame.LABELS[name], types[name])])
	return lines


# "Ru runner: moves 6, beats Mo Ra" -- the label, the name, and the two facts
# that make the type a choice.
static func _describe(label: String, kind: UnitType) -> String:
	var beaten: Array[String] = []
	for name: String in kind.strong_against:
		beaten.append(TacticalGame.LABELS[name])
	var motion: String = "moves %d" % kind.movement if kind.mobile else "fixed"
	var beats: String = ", beats " + " ".join(beaten) if not beaten.is_empty() else ""
	return "%s %s: %s%s" % [label, kind.type_name, motion, beats]
