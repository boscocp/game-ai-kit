## Dijkstra: the cheapest route when steps cost different amounts.
##
## Breadth-first with one change that matters: instead of taking the oldest
## cell off the frontier, take the cheapest-so-far. Mud now costs what mud
## costs, and the route round it wins on its own merits rather than because
## somebody special-cased it.
##
## It also keeps improving a cell it has already seen. Breadth-first never
## revisits, because with equal steps the first visit is the best one. With
## costs that is false: a long way round can arrive cheaper, and the line that
## allows it is the `or` below.
##
## Complexity: O(V²) as written. Two linear scans are why -- picking the
## cheapest walks the frontier, and the closed-set check walks what has been
## expanded. With a binary heap and a set it is O(E log V). Both scans are the
## readable choice and the kit says so out loud in `search.gd`; the version
## with the heap is called `AStarGrid2D` and is already in the engine.
##
## When not to use it: when you know roughly where the goal is. Dijkstra does
## not, so it expands in every direction equally and looks at most of the map.
## A* is the same algorithm with that knowledge added, and it is the next file.
class_name DijkstraSearch
extends Search


## The cheapest route from `from` to `to`, counting what each cell costs to
## enter.
func search(graph: GridGraph, from: Vector2i, to: Vector2i) -> SearchResult:
	var frontier: Array[Vector2i] = [from]
	var came_from: Dictionary = {from: NO_PARENT}
	# Cost so far, per cell. `g` is the literature's name for it and renaming
	# it hurts the reader who came from the book.
	var g: Dictionary = {from: 0}
	var expanded: Array[Vector2i] = []

	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_at(_cheapest(frontier, g))
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

		_relax(graph, current, came_from, g, frontier)

	return SearchResult.nothing_found(expanded, frontier)


# Offer every neighbour a cheaper way in, and queue the ones that take it.
#
# The `or` is the line that separates this from breadth-first: a cell already
# seen is still worth improving, because a longer way round can arrive cheaper
# when the ground is not all the same.
static func _relax(graph: GridGraph, current: Vector2i, came_from: Dictionary,
		g: Dictionary, frontier: Array[Vector2i]) -> void:
	for step: Vector2i in graph.neighbours(current):
		var through_here: int = g[current] + graph.cost_at(step)
		if not g.has(step) or through_here < g[step]:
			g[step] = through_here
			came_from[step] = current
			frontier.append(step)
