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

## The board, row by row: `.` open, `T` trees, `#` rock, `~` water, `=` the
## bridge.
const MAP: Array[String] = [
	"..T...~~......",
	".TT...~~.T....",
	".....T~~.T....",
	"..#..T~~......",
	"..#...==...#..",
	"......~~T..#..",
	"....T.~~T.....",
	"....T.~~...TT.",
	"......~~...T..",
]


## The two control points (T44), one on each bank, each beside the river's
## top or bottom end: far from its own side's workshop, five cells from the
## bridge, and one step from water, so a wader reaches the other side's point
## without the bridge. Two, not three: the map is the same turned half round,
## and on a board fourteen wide no cell is its own mirror, so the points come
## in pairs. Not on the bridge: a flag there hides the only dry crossing, and
## the bridge is already where the fight is -- a point elsewhere gives a
## second place worth going.
const POINTS: Array[Vector2i] = [Vector2i(5, 0), Vector2i(8, 8)]


## The river runs down columns 6 and 7; a cell left of column 7 is on red's
## bank, and the bridge's two cells sit one on each.
const RIVER_MIDDLE: int = 7


## True when the two cells are on opposite banks of the river.
static func across_the_river(here: Vector2i, there: Vector2i) -> bool:
	return (here.x < RIVER_MIDDLE) != (there.x < RIVER_MIDDLE)


## A fresh game: red to move, both sides with their buildings, two soldiers
## each and the starting funds.
static func build() -> BoardState:
	var types: Dictionary = TacticalRules.unit_types()
	var graphs: Dictionary = TacticalRules.graphs_from(MAP)
	var units: Array[Unit] = []
	for placed: Dictionary in _placements():
		var kind: UnitType = types[placed["type"]]
		var health: int = 10 if kind.mobile else TacticalRules.BUILDING_HEALTH
		units.append(Unit.new(units.size() + 1, placed["side"], placed["cell"], health, kind.movement, kind))
	var state := BoardState.new(graphs[UnitType.GROUND], units, RED)
	state.movement_graphs = {TacticalRules.WATER_MOVER: graphs[TacticalRules.WATER_MOVER]}
	state.funds = {RED: TacticalRules.STARTING_FUNDS, BLUE: TacticalRules.STARTING_FUNDS}
	return state


# Who stands where -- the two sides mirrored through the board's centre, so
# neither starts nearer the bridge.
static func _placements() -> Array[Dictionary]:
	var placed: Array[Dictionary] = []
	for side: Array in [[RED, Vector2i.ZERO], [BLUE, Vector2i(13, 8)]]:
		for spot: Array in _one_side():
			var cell: Vector2i = spot[0] if side[0] == RED else side[1] - spot[0]
			placed.append({"side": side[0], "cell": cell, "type": spot[1]})
	return placed


# Red's pieces, cell and type; blue's are the same turned half round.
static func _one_side() -> Array[Array]:
	return [
		[Vector2i(1, 7), TacticalRules.WORKSHOP],
		[Vector2i(3, 5), TacticalRules.BOLT_TOWER],
		[Vector2i(4, 1), TacticalRules.WATCHTOWER],
		[Vector2i(2, 6), TacticalRules.RUNNER],
		[Vector2i(3, 7), TacticalRules.SHIELD],
	]
