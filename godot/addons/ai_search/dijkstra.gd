## Dijkstra: the cheapest route when steps cost different amounts.
##
## Breadth-first with one change that matters: instead of taking the oldest
## cell off the frontier, take the cheapest-so-far. Mud now costs what mud
## costs, and the route round it wins on its own merits rather than because
## somebody special-cased it.
##
## **It does not revisit a cell, and that is a property of this board's costs
## rather than of Dijkstra.** The textbook version keeps improving cells it has
## already seen, because a long way round can arrive cheaper. Here it cannot:
## a cost belongs to the cell *entered*, so every route into a cell pays the
## same last step, and the first route to reach it came from a cell no dearer
## than any that will be expanded later. Measured over 250 random boards -- 0
## improvements and 0 duplicate expansions, against 165 and 131 for A\* on the
## same boards, which takes cells off in order of `g + h` rather than `g`. So
## the improvement branch and the closed-set guard that A\* needs are not
## written here, because code that cannot execute cannot be read as if it does.
##
## A binary heap does not change that; charging the cost per *edge* does.
## `docs/concepts/cost_models.py` measures both.
##
## Complexity: O(V²), because picking the cheapest is a linear scan of the
## frontier. With a heap it is O(E log V), and on these costs needs no more
## code than this file has. The scan is the readable choice and the kit says so
## out loud in `search.gd`; the version with the heap is called `AStarGrid2D`
## and is already in the engine.
##
## When not to use it: when you know roughly where the goal is. Dijkstra does
## not, so it expands in every direction equally and looks at most of the map.
## A* is the same algorithm with that knowledge added, and it is the next file.
class_name DijkstraSearch
extends GakSearch


# The cheapest route from `from` to `to`, counting what each cell costs to
# enter.
func _explore(graph: GakSearchGraph, from: Vector2i, to: Vector2i) -> SearchResult:
	var frontier: Array[Vector2i] = [from]
	var came_from: Dictionary = {from: NO_PARENT}
	# Cost so far, per cell. `g` is the literature's name for it and renaming
	# it hurts the reader who came from the book.
	var g: Dictionary = {from: 0}
	var expanded: Array[Vector2i] = []

	while not frontier.is_empty():
		# Here is the whole algorithm: take the cell with the smallest `g`.
		# `_cheapest` walks the frontier and returns the index of the lowest
		# number beside it -- that is all it does, and it lives in `search.gd`
		# only because A* needs the same walk with `f`.
		#
		# Because that number is the true cost so far, the cell taken off is
		# the globally cheapest and its cost is already final -- and since no
		# cell is ever improved, no cell is ever queued twice. A* improves
		# cells still waiting and queues them again, which leaves stale copies
		# behind, and that is why it carries a duplicate guard and this file
		# does not.
		var current: Vector2i = frontier.pop_at(_cheapest(frontier, g))
		expanded.append(current)
		if current == to:
			return _reached(graph, came_from, from, to, expanded, frontier)

		_relax(graph, current, came_from, g, frontier)

	return SearchResult.nothing_found(expanded, frontier)


# Record what it costs to reach each neighbour not seen before.
#
# What separates this from breadth-first is not here, it is in the pop: the
# frontier is ordered by cost. The textbook also writes `or through_here <
# g[step]` on the line below, to improve a cell already seen. Instrumented over
# 250 boards, that branch fired **zero** times -- see the header for why -- so
# it is not written here. A* orders by `g + h` instead, where it fires
# constantly, and its version of this function has it.
static func _relax(graph: GakSearchGraph, current: Vector2i, came_from: Dictionary,
		g: Dictionary, frontier: Array[Vector2i]) -> void:
	for step: Vector2i in graph.neighbours(current):
		if g.has(step):
			continue
		g[step] = g[current] + graph.cost_at(step)
		came_from[step] = current
		frontier.append(step)
