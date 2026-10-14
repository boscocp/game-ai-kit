## Every cell a piece can walk to this turn, and the cheapest walk to each.
##
## A uniform-cost flood from the piece, over its own cost map, stopping at its
## movement points and going round every other piece. Small enough to read in
## one go, and it is Dijkstra's algorithm with the goal taken away: the search
## lesson's `DijkstraSearch` stops at one goal, and a move highlight wants all
## of them.
##
## The board still has the last word. Each walk found here is put to
## `BoardState.why_refused` before it is offered, so the highlight cannot
## promise a move the board would refuse.
##
## When not to use it: large boards. The frontier is a plain array searched
## for its cheapest cell each round, which is fine at 14x9 and quadratic in
## general.
class_name TacticalReach
extends RefCounted


## Cell -> the walk to it (start excluded), for every cell `unit` can reach
## now. Empty for a piece that cannot move or has no movement left.
static func walks_for(state: BoardState, unit: Unit) -> Dictionary:
	var spent: Dictionary = {unit.cell: 0}
	var came_from: Dictionary = {}
	var frontier: Array[Vector2i] = [unit.cell]
	while not frontier.is_empty():
		var here: Vector2i = _cheapest(frontier, spent)
		frontier.erase(here)
		frontier.append_array(_expand(state, unit, here, spent, came_from))
	return _legal_walks(state, unit, came_from)


## Cell -> what the cheapest walk from `from` costs, for every cell the
## graph lets anything reach, with no limit on movement and nobody in the
## way. The same flood as `walks_for`, asked a different question: not
## "where can I go this turn" but "how far is everything".
static func route_costs(graph: GridGraph, from: Vector2i) -> Dictionary:
	var spent: Dictionary = {from: 0}
	var frontier: Array[Vector2i] = [from]
	while not frontier.is_empty():
		var here: Vector2i = _cheapest(frontier, spent)
		frontier.erase(here)
		frontier.append_array(_relax(graph, here, spent))
	return spent


# The neighbours of `here` that a walk through it reaches more cheaply than
# any found so far -- written into `spent` and returned to be flooded on.
# Taken cheapest first, with the cost charged for the cell entered, the first
# walk to reach a cell is already its cheapest, so "more cheaply" only ever
# means "for the first time" here: the reason `dijkstra.gd` gives, measured.
static func _relax(graph: GridGraph, here: Vector2i, spent: Dictionary) -> Array[Vector2i]:
	var improved: Array[Vector2i] = []
	for next: Vector2i in graph.neighbours(here):
		var cost: int = spent[here] + graph.cost_at(next)
		if cost < spent.get(next, cost + 1):
			spent[next] = cost
			improved.append(next)
	return improved


# The neighbours of `here` reached more cheaply through it than any way found
# so far, and still affordable -- written down, and returned to be expanded.
static func _expand(state: BoardState, unit: Unit, here: Vector2i, spent: Dictionary,
		came_from: Dictionary) -> Array[Vector2i]:
	var improved: Array[Vector2i] = []
	for next: Vector2i in _open_neighbours(state, unit, here):
		var cost: int = spent[here] + state.graph_for(unit).cost_at(next)
		if cost <= unit.movement_points and cost < spent.get(next, cost + 1):
			spent[next] = cost
			came_from[next] = here
			improved.append(next)
	return improved


static func _cheapest(frontier: Array[Vector2i], spent: Dictionary) -> Vector2i:
	var best: Vector2i = frontier[0]
	for cell: Vector2i in frontier:
		if spent[cell] < spent[best]:
			best = cell
	return best


# Neighbours on the board, open to this piece's kind of feet, and empty.
static func _open_neighbours(state: BoardState, unit: Unit, cell: Vector2i) -> Array[Vector2i]:
	var ground: GridGraph = state.graph_for(unit)
	var found: Array[Vector2i] = []
	for next: Vector2i in ground.neighbours(cell):
		if not ground.is_blocked(next) and state.unit_at(next) == null:
			found.append(next)
	return found


# Each walk rebuilt from the flood, kept only when the board agrees to it.
static func _legal_walks(state: BoardState, unit: Unit, came_from: Dictionary) -> Dictionary:
	var walks: Dictionary = {}
	for goal: Vector2i in came_from:
		var path: Array[Vector2i] = [goal]
		while came_from[path[0]] != unit.cell:
			path.push_front(came_from[path[0]])
		if state.why_refused(Move.new(unit.id, path)) == BoardState.LEGAL:
			walks[goal] = path
	return walks
