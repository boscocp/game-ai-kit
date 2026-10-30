## Breadth-first search: the shortest route when every step costs the same.
##
## Expands in rings. Every cell one step away, then every cell two steps away,
## and so on -- so the first time it touches the goal, it got there in the
## fewest *steps* that exist. That is not the same as the cheapest route, and
## the difference is the whole reason Dijkstra is the next file.
##
## Complexity: O(V + E). On a grid that is four edges per cell, so O(cells).
## Memory is the frontier, which on an open map is the ring, and a ring grows.
##
## When not to use it: when terrain costs differ. BFS cannot see cost, so it
## will walk a unit through three cells of mud rather than four of road and
## report it as the shortest path. It is right, and it answered a different
## question than the one you asked.
class_name BreadthFirstSearch
extends GakSearch


# The route with the fewest steps, ignoring what a step costs.
func _explore(graph: GakSearchGraph, from: Vector2i, to: Vector2i) -> SearchResult:
	var frontier: Array[Vector2i] = [from]
	var came_from: Dictionary = {from: NO_PARENT}
	var expanded: Array[Vector2i] = []

	while not frontier.is_empty():
		# The front of the queue: the oldest cell, which is what makes this
		# breadth-first. `pop_back` instead of `pop_front` -- a queue instead
		# of a stack -- is depth-first, and that one call is the whole
		# difference between the two files.
		var current: Vector2i = frontier.pop_front()
		expanded.append(current)
		if current == to:
			return _reached(graph, came_from, from, to, expanded, frontier)

		_enqueue_unseen(graph, current, came_from, frontier)

	return SearchResult.nothing_found(expanded, frontier)
