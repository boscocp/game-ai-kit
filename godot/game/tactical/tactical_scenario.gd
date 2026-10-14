## The tactical map, and the state a game of it starts from.
##
## A river runs down the middle with one bridge, so where you cross is a
## decision before anything else is: the bridge is narrow and everyone can see
## it, the water is open only to waders, and the trees on either bank are slow
## to cross and good to hide in. The map is the same turned half round, so
## neither side starts nearer the bridge. Each side has a workshop in its own
## corner, a bolt tower covering its bank, and a watchtower looking across.
##
## The map is written as text, one row per line, in the characters
## `TacticalRules` names. A reader sees the board in the source without
## running anything, and a change to the map is a diff a person can review.
##
## When not to use it: a second map. This is one scenario's layout, not a map
## format; the day there are two, the rows belong in a data file.
class_name TacticalScenario
extends RefCounted

const RED: int = 0
const BLUE: int = 1
const FACTIONS: int = 2

## The board, row by row: `.` open, `T` trees, `#` rock, `~` water. Row 4,
## where the river is missing, is the bridge.
const MAP: Array[String] = [
	"..T...~~......",
	".TT...~~.T....",
	".....T~~.T....",
	"..#..T~~......",
	"..#........#..",
	"......~~T..#..",
	"....T.~~T.....",
	"....T.~~...TT.",
	"......~~...T..",
]


## A fresh game: red to move, both sides with their buildings, two soldiers
## each and the starting funds.
static func build() -> BoardState:
	var types: Dictionary = TacticalRules.unit_types()
	var graphs: Dictionary = TacticalRules.graphs_from(MAP)
	var units: Array[Unit] = []
	for placed: Array in _placements():
		var kind: UnitType = types[placed[2]]
		units.append(Unit.new(units.size() + 1, placed[0], placed[1], 10, kind.movement, kind))
	var state := BoardState.new(graphs[UnitType.GROUND], units, RED)
	state.movement_graphs = {TacticalRules.WATER_MOVER: graphs[TacticalRules.WATER_MOVER]}
	state.funds = {RED: TacticalRules.STARTING_FUNDS, BLUE: TacticalRules.STARTING_FUNDS}
	return state


# Faction, cell, type -- the two sides mirrored through the board's centre, so
# neither starts nearer the bridge.
static func _placements() -> Array[Array]:
	return [
		[RED, Vector2i(1, 7), TacticalRules.WORKSHOP],
		[RED, Vector2i(3, 5), TacticalRules.BOLT_TOWER],
		[RED, Vector2i(4, 1), TacticalRules.WATCHTOWER],
		[RED, Vector2i(2, 6), TacticalRules.RUNNER],
		[RED, Vector2i(3, 7), TacticalRules.SHIELD],
		[BLUE, Vector2i(12, 1), TacticalRules.WORKSHOP],
		[BLUE, Vector2i(10, 3), TacticalRules.BOLT_TOWER],
		[BLUE, Vector2i(9, 7), TacticalRules.WATCHTOWER],
		[BLUE, Vector2i(11, 2), TacticalRules.RUNNER],
		[BLUE, Vector2i(10, 1), TacticalRules.SHIELD],
	]
