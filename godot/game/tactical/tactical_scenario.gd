## The tactical map, and the state a game of it starts from.
##
## A river runs down the middle with one bridge and a ford at each end, so
## where you cross is a decision before anything else is: the bridge is narrow
## and quick and everyone can see it, the fords (T48) are slow and far apart,
## the deep water is open only to waders, and the trees on either bank are
## slow to cross and good to hide in. The fords came in a pair because the
## map is the same turned half round, and the bridge already holds the only
## crossing that is its own mirror. Before them one bridge one cell wide was
## the only dry way over, and wave 49 measured the pieces queued behind it. The map is the same turned half round, so
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
## bridge, `f` a ford.
const MAP: Array[String] = [
	"..T...ff......",
	".TT...~~.T....",
	".....T~~.T....",
	"..#..T~~......",
	"..#...==...#..",
	"......~~T..#..",
	"....T.~~T.....",
	"....T.~~...TT.",
	"......ff...T..",
]


## The two control points (T44), one on each bank, each beside the river's
## top or bottom end: far from its own side's workshop, five cells from the
## bridge, and one step from a ford, so the far side's point is the first
## thing a piece coming over the ford reaches. Two, not three: the map is the same turned half round,
## and on a board fourteen wide no cell is its own mirror, so the points come
## in pairs. Not on the bridge: a flag there hides the only dry crossing, and
## the bridge is already where the fight is -- a point elsewhere gives a
## second place worth going.
const POINTS: Array[Vector2i] = [Vector2i(5, 0), Vector2i(8, 8)]


## Where blue's extra shield stands when `TacticalRules.SECOND_PLAYER_SHIELD`
## gives it one: diagonal to its workshop, on open ground, not on a point.
const SECOND_PLAYER_SHIELD_CELL: Vector2i = Vector2i(11, 0)


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
	_counter_for_the_second_player(units, types)
	var state := BoardState.new(graphs[UnitType.GROUND], units, RED)
	state.movement_graphs = {TacticalRules.WATER_MOVER: graphs[TacticalRules.WATER_MOVER]}
	state.funds = {RED: TacticalRules.STARTING_FUNDS, BLUE: TacticalRules.STARTING_FUNDS + TacticalRules.SECOND_PLAYER_FUNDS}
	return state


# Blue moves second, and is given what `TacticalRules` says the side moving
# second gets (T47): more health on its workshop, and a shield.
static func _counter_for_the_second_player(units: Array[Unit], types: Dictionary) -> void:
	for unit: Unit in units:
		if unit.faction == BLUE and unit.type.type_name == TacticalRules.WORKSHOP:
			unit.health += TacticalRules.SECOND_PLAYER_WORKSHOP_HEALTH
	if TacticalRules.SECOND_PLAYER_SHIELD:
		var shield: UnitType = types[TacticalRules.SHIELD]
		units.append(Unit.new(units.size() + 1, BLUE, SECOND_PLAYER_SHIELD_CELL, 10, shield.movement, shield))


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
