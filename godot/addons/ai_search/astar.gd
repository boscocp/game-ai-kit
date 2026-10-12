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
## three possible outcomes and the reason `heuristic` below documents its own
## condition.
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
func _explore(graph: GridGraph, from: Vector2i, to: Vector2i) -> SearchResult:
	var frontier: Array[Vector2i] = [from]
	var came_from: Dictionary = {from: NO_PARENT}
	# `g` is the cost of reaching a cell, `f` is that plus the guess about what
	# remains. The names are the literature's, and the frontier is ordered by
	# `f` -- that single substitution is the whole difference from Dijkstra.
	var g: Dictionary = {from: 0}
	var f: Dictionary = {from: heuristic(from, to)}
	var expanded: Array[Vector2i] = []

	while not frontier.is_empty():
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
func _relax(graph: GridGraph, current: Vector2i, goal: Vector2i,
		came_from: Dictionary, g: Dictionary, f: Dictionary,
		frontier: Array[Vector2i]) -> void:
	for step: Vector2i in graph.neighbours(current):
		var through_here: int = g[current] + graph.cost_at(step)
		if not g.has(step) or through_here < g[step]:
			g[step] = through_here
			f[step] = through_here + heuristic(step, goal)
			came_from[step] = current
			frontier.append(step)


## The guess: how much is left, at best, from `cell` to `goal`.
##
## Manhattan distance, which is the number of cardinal steps between two cells
## when nothing is in the way. It is admissible **as long as no cell costs less
## than one to enter**: a route cannot be shorter than the number of steps, and
## each step costs at least one, so the guess cannot exceed the truth.
##
## That condition used to be a warning in this comment, with nothing behind it.
## It is now a rule in `GridGraph.set_cost`, which clamps any cost below one to
## one and keeps `BLOCKED` as the only value outside the range. A board that
## would break this heuristic can no longer be built, which is a better place
## for the condition than a paragraph nobody reads at the moment they need it.
func heuristic(cell: Vector2i, goal: Vector2i) -> int:
	return absi(cell.x - goal.x) + absi(cell.y - goal.y)
