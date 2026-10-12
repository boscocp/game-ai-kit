## What the four searches in this addon share, and nothing more.
##
## Each algorithm answers one question -- which cell to take off the frontier
## next -- and everything else about them is the same: start somewhere, expand,
## remember where you came from, walk the chain back. That shared part lives
## here so that each algorithm file is the part that differs, read beside the
## pseudocode in the book without ceremony around it.
##
## `find_path` is the `Pathfinder` contract and is a one-liner on top of
## `search`, so the game can hold any of these as a `Pathfinder` and the demo
## can hold the same object and ask for the expansion as well.
##
## When not to use any of them: when you need throughput. `AStarGrid2D` is
## engine core, written in C++, with four heuristics and four diagonal modes,
## and it will beat everything here. These are written to be read.
@abstract
class_name Search
extends Pathfinder

## Where a search starts: the cell it came from is itself, which is what ends
## the walk back along the chain.
const NO_PARENT: Vector2i = Vector2i(-1, -1)


## The whole result: the route, what was expanded, and what was still waiting.
##
## The start is checked here rather than in each algorithm, because it is the
## same check four times and none of them had it. Measured before this existed:
## `from = (-1, 2)` on a 5x5 board came back `reached`, with a path that walked
## in from nowhere -- and the conformance runner's own walkability check
## accepted it, because every *step* was legal.
##
## A start that is merely **blocked** is allowed through: a unit can be standing
## in a wall because something put it there, and cost is paid on entering a
## cell, never on leaving one. A start that is not on the board at all is not a
## cell, and there is nothing to search from.
func search(graph: GridGraph, from: Vector2i, to: Vector2i) -> SearchResult:
	if not graph.contains(from):
		return SearchResult.nothing_found([] as Array[Vector2i], [] as Array[Vector2i])
	return _explore(graph, from, to)


## The `Pathfinder` contract, which is this one's answer with the work thrown
## away.
func find_path(graph: GridGraph, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	return search(graph, from, to).path


# One algorithm, on a start already known to be on the board. This is the part
# that differs between the four files, and it is the only part they implement.
@abstract func _explore(graph: GridGraph, from: Vector2i, to: Vector2i) -> SearchResult


# Walk the chain of parents back from the goal, then turn it round.
#
# The result excludes `from` and includes `to`, which is what `Pathfinder`
# promises and what `Move` expects: cost is paid on entering a cell, and you
# never pay to stand where you already are.
static func _rebuild(came_from: Dictionary, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var backwards: Array[Vector2i] = []
	var cell: Vector2i = to
	while cell != from:
		backwards.append(cell)
		cell = came_from[cell]
	backwards.reverse()
	return backwards


# Every neighbour not seen before goes on the frontier, remembering where it
# was reached from.
#
# Breadth-first and depth-first share this exactly: neither looks at cost, so
# neither ever revisits a cell. Dijkstra and A* cannot use it, because the
# whole point of a cost is that a cell seen already may still be worth
# improving -- each of those files carries its own version, which is the line
# worth reading them for.
static func _enqueue_unseen(graph: GridGraph, current: Vector2i,
		came_from: Dictionary, frontier: Array[Vector2i]) -> void:
	for step: Vector2i in graph.neighbours(current):
		if not came_from.has(step):
			came_from[step] = current
			frontier.append(step)


# The index of the cell in `frontier` carrying the lowest number.
#
# A linear scan, not a binary heap. On the boards this kit uses the frontier is
# tens of cells and the scan does not show up; a heap is forty lines that would
# sit between the reader and the algorithm, and the moment you genuinely need
# one you need `AStarGrid2D`, which is C++ and already has it. That is the
# benchmark this exception would need, and nobody has had to run it.
static func _cheapest(frontier: Array[Vector2i], priority: Dictionary) -> int:
	var best: int = 0
	for index: int in range(1, frontier.size()):
		if priority[frontier[index]] < priority[frontier[best]]:
			best = index
	return best


# What a route costs on this graph: the sum of entering each cell on it.
static func _cost_of(graph: GridGraph, path: Array[Vector2i]) -> int:
	var total: int = 0
	for cell: Vector2i in path:
		total += graph.cost_at(cell)
	return total


# The result of a search that reached its goal.
static func _reached(graph: GridGraph, came_from: Dictionary, from: Vector2i,
		to: Vector2i, expanded: Array[Vector2i],
		frontier: Array[Vector2i]) -> SearchResult:
	var path: Array[Vector2i] = _rebuild(came_from, from, to)
	return SearchResult.new(path, expanded, frontier, _cost_of(graph, path), true)
