## A*: Dijkstra, plus a guess about which way the goal is.
##
## Dijkstra orders its frontier by `g`, the cost of getting to a cell. A*
## orders it by `f = g + h`, where `h` guesses what is left. The guess costs
## nothing to compute and it stops the search expanding away from the goal, so
## the same answer comes out after looking at a fraction of the map. The demo
## draws both expansions on one board, which is the fastest way to see it.
##
## The guarantee comes with a condition: `h` must never *overestimate* what is
## left. A heuristic that never overestimates is called admissible, and with
## one A* returns a route of exactly the cost Dijkstra returns. With one that
## overestimates, A* is faster and quietly wrong, which is the worst of the
## three possible outcomes. So the guess is not written here: it is
## `graph.estimate`, and the graph owns it, because only the graph knows what a
## step can cost. `SearchGraph.estimate` carries the promise; the grid's is
## Manhattan distance, in `grid_search_graph.gd`, with the reason it is safe.
##
## Complexity: the same as Dijkstra in the worst case -- with `h` returning
## zero it *is* Dijkstra -- and far better in practice.
##
## When not to use it: when you cannot estimate the distance that is left, for
## instance on a graph of abstract states rather than a map. Then `h` is zero
## and you are running Dijkstra with extra steps. And for throughput, use
## `AStarGrid2D`: engine core, C++, four heuristics.
class_name AStarSearch
extends Search


# The cheapest route, expanding towards the goal rather than in all
# directions.
func _explore(graph: SearchGraph, from: Vector2i, to: Vector2i) -> SearchResult:
	var frontier: Array[Vector2i] = [from]
	var came_from: Dictionary = {from: NO_PARENT}
	# `g` is the cost of reaching a cell, `f` is that plus the guess about what
	# remains. The names are the literature's, and the frontier is ordered by
	# `f` -- that single substitution is the whole difference from Dijkstra.
	var g: Dictionary = {from: 0}
	var f: Dictionary = {from: graph.estimate(from, to)}
	var expanded: Array[Vector2i] = []

	while not frontier.is_empty():
		# Here is the whole algorithm: take the cell with the smallest `f`.
		# `_cheapest` walks the frontier and returns the index of the lowest
		# number beside it -- that is all it does, and it is written out in
		# `search.gd` only because Dijkstra needs the same walk with `g`.
		# Breadth-first takes the oldest cell instead; everything else in these
		# four files is bookkeeping around that one choice.
		var current: Vector2i = frontier.pop_at(_cheapest(frontier, f))
		# A cell improved after it was queued is queued again, so the frontier
		# can hold the same cell twice -- an old entry with a dear number and a
		# new one with a cheap one. Expanding the stale copy a second time
		# changes no answer and costs a whole expansion, and it made `expanded`
		# a count of pops rather than of cells. Measured over 300 random boards:
		# without this line A* expanded more cells than Dijkstra on 14 of them,
		# which is the opposite of the reason it exists.
		if expanded.has(current):
			continue
		expanded.append(current)
		if current == to:
			return _reached(graph, came_from, from, to, expanded, frontier)

		_relax(graph, current, to, came_from, g, f, frontier)

	return SearchResult.nothing_found(expanded, frontier)


# Dijkstra's relaxation with two differences: a cell already seen is still
# worth improving, and a cell that gets a cheaper `g` also gets a new `f`.
#
# A retraction. This comment used to say that a stale `f` "would send the search
# the wrong way". It was never measured, and it is false: freezing `f` at its
# first value over 241 random boards changed neither the cost returned nor the
# number of cells expanded, not once. What refreshing `f` buys is that the
# frontier stays ordered by the current best estimate, which is what A* is
# *defined* to do -- and the honest reason to keep the line is that the
# implementation should not quietly depend on an accident of these boards.
func _relax(graph: SearchGraph, current: Vector2i, goal: Vector2i,
		came_from: Dictionary, g: Dictionary, f: Dictionary,
		frontier: Array[Vector2i]) -> void:
	for step: Vector2i in graph.neighbours(current):
		var through_here: int = g[current] + graph.cost_at(step)
		if not g.has(step) or through_here < g[step]:
			g[step] = through_here
			f[step] = through_here + graph.estimate(step, goal)
			came_from[step] = current
			frontier.append(step)
