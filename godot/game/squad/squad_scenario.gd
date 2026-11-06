## Where the two squads start: the tactical map, four pieces a side, nothing
## else -- no workshop, no towers, no funds and no points.
##
## The map is `TacticalScenario.MAP`, read as it is: the river, the bridge,
## the fords, the trees and the rock. Each squad stands on its own bank by
## its own map edge, the two mirrored through the board's centre as the
## tactical game's sides are, so neither starts nearer a crossing. Red's
## shield starts beside the rock at (2, 4), in full cover from the river.
##
## Since T96 the map can be another: N in the scene builds one by wave
## function collapse (`SquadMapBuild`) and `use_map` puts it here, where
## every rule of the mode reads it -- the squads' cells stay these, pinned
## to open ground on every map built. `use_map([])` puts the tactical map
## back. The starts stay where they are because the rules, the evaluation
## and the enemy's memory of the starts all read `RED_CELLS`.
##
## When not to use it: a layout of pieces. The cells are one layout; a mode
## with another belongs in a data file.
class_name SquadScenario
extends RefCounted

## Red's pieces' cells, in `SquadTable.squad()`'s order; blue's are the same
## turned half round.
const RED_CELLS: Array[Vector2i] = [Vector2i(1, 2), Vector2i(1, 4), Vector2i(0, 5), Vector2i(1, 6)]

## The corner the board turns half round about: blue's cell is this less red's.
const TURNED: Vector2i = Vector2i(13, 8)

# The map built by `use_map`; empty while the squads fight on the tactical map.
static var _built: Array[String] = []


## A fresh game: red to move, both squads at full health and movement.
static func build() -> BoardState:
	var types: Dictionary = SquadTable.unit_types()
	var graphs: Dictionary = TacticalRules.graphs_from(rows())
	var units: Array[Unit] = []
	for side: int in [TacticalScenario.RED, TacticalScenario.BLUE]:
		var names: Array[String] = SquadTable.squad()
		for index: int in range(names.size()):
			var kind: UnitType = types[names[index]]
			var cell: Vector2i = RED_CELLS[index] if side == TacticalScenario.RED else TURNED - RED_CELLS[index]
			units.append(Unit.new(units.size() + 1, side, cell, SquadTable.number(kind.type_name, "health"), kind.movement, kind))
	var state := BoardState.new(graphs[UnitType.GROUND], units, TacticalScenario.RED)
	state.movement_graphs = {TacticalRules.WATER_MOVER: graphs[TacticalRules.WATER_MOVER]}
	return state


## The map the squads fight on, for the rules that read its letters: the
## tactical map, or the one `use_map` was given.
static func rows() -> Array[String]:
	return _built if not _built.is_empty() else TacticalScenario.MAP


## Fight the next game on `built`, rows of `TacticalRules`' letters the size
## of the tactical map; on the tactical map again when `built` is empty.
static func use_map(built: Array[String]) -> void:
	_built = built.duplicate()


## Every piece's starting cell, red's then blue's, with its kind: what a
## built map pins to open ground and checks the squads can use.
static func starts() -> Array[Array]:
	var found: Array[Array] = []
	for side: int in [TacticalScenario.RED, TacticalScenario.BLUE]:
		var names: Array[String] = SquadTable.squad()
		for index: int in range(names.size()):
			var cell: Vector2i = RED_CELLS[index] if side == TacticalScenario.RED else TURNED - RED_CELLS[index]
			found.append([cell, names[index]])
	return found
