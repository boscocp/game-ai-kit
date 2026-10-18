## Where a side can strike on its next turn, cell by cell: how many of its
## pieces could attack each one (T48).
##
## Dave Mark's modular influence maps (Game AI Pro 2, ch. 30) keep one map per
## faction of "what they can hit", and the warning that matters here is his:
## measure by **path**, not by straight line -- the tiger behind the fence is
## close and is not a threat. On this board the fence is the river. A shield
## two cells away across deep water cannot reach you next turn, and a map that
## said it could would send every piece running from the bank. So a walker's
## threat is the cells it could walk to on its own cost map with its whole
## movement, and the cells within its reach of those; a bolt tower's is the
## ring of its reach round it, because it does not walk.
##
## Pieces are not walls here, on purpose: next turn they may have moved. The
## map errs towards caution -- a cell counted threatened may turn out safe --
## which is the right way round for a map a piece chooses where to stand by.
## (`docs/design/tactical-references.md`, §2.2; it is drawn on the board, as
## Into the Breach telegraphs its enemies' attacks, §2.5.)
##
## Complexity: per piece one flood of the board (`TacticalReach.route_costs`)
## and a reach-sized square per cell it can stand on.
##
## When not to use it: as a prediction of what the other side will do. It is
## what it could do, all of it at once, by every piece.
class_name ThreatMap
extends RefCounted


## Cell -> how many of `side`'s pieces could attack it on `side`'s next turn.
## A cell nothing threatens is absent, not 0.
static func of(state: BoardState, side: int) -> Dictionary[Vector2i, int]:
	var threat: Dictionary[Vector2i, int] = {}
	for unit: Unit in state.units_of(side):
		if unit.type.attack_range <= 0:
			continue
		for cell: Vector2i in strikes(state, unit):
			threat[cell] = threat.get(cell, 0) + 1
	return threat


## Every cell `unit` could attack on its side's next turn: from where it
## stands, and -- for a walker -- from every cell its whole movement reaches
## on its own cost map.
static func strikes(state: BoardState, unit: Unit) -> Array[Vector2i]:
	var graph: GridGraph = state.graph_for(unit)
	var hit: Dictionary[Vector2i, bool] = {}
	for here: Vector2i in _standing_places(graph, unit):
		for cell: Vector2i in _within(graph, here, unit.type.attack_range):
			hit[cell] = true
	return hit.keys()


# Where `unit` could stand to attack from next turn: where it is, and for a
# walker every cell its whole movement reaches on `graph`.
static func _standing_places(graph: GridGraph, unit: Unit) -> Array[Vector2i]:
	var places: Array[Vector2i] = [unit.cell]
	if not unit.type.mobile:
		return places
	var costs: Dictionary = TacticalReach.route_costs(graph, unit.cell)
	for cell: Vector2i in costs:
		if costs[cell] <= unit.type.movement:
			places.append(cell)
	return places


# The cells on the board within `reach` steps of `here` as the crow flies,
# `here` itself left out: a piece does not attack the cell it stands on.
static func _within(graph: GridGraph, here: Vector2i, reach: int) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	var side: int = 2 * reach + 1
	for index: int in range(side * side):
		var offset := Vector2i(index % side - reach, index / side - reach)
		var cell: Vector2i = here + offset
		if absi(offset.x) + absi(offset.y) <= reach and cell != here and graph.contains(cell):
			found.append(cell)
	return found
