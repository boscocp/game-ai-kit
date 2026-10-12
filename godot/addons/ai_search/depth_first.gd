## Depth-first search: follow one corridor to its end before trying another.
##
## It is in this kit to be looked at, not to be used. Change `pop_front` to
## `pop_back` in breadth-first and you have it: a stack instead of a queue, one
## call of difference, and a completely different shape on screen. The demo
## draws them one after the other because that is the lesson.
##
## Complexity: O(V + E), the same as breadth-first. Cheap, and cheap is not the
## problem.
##
## When not to use it: whenever you want a route a unit should actually walk.
## The path it finds is *a* path, never the shortest and usually absurd -- it
## will cross the whole map and come back rather than take the cell next door,
## because it committed to a direction and kept going. What it is genuinely
## good for is exhausting a space: flood fill, connectivity, "is any route
## there at all", maze generation.
class_name DepthFirstSearch
extends Search


# Some route to the goal, with no claim about it beyond existing.
func _explore(graph: GridGraph, from: Vector2i, to: Vector2i) -> SearchResult:
	var frontier: Array[Vector2i] = [from]
	var came_from: Dictionary = {from: NO_PARENT}
	var expanded: Array[Vector2i] = []

	while not frontier.is_empty():
		# The back of the stack: the newest cell. Breadth-first takes the
		# oldest one off the front. That is the entire difference, and it is
		# why this file is worth reading beside that one rather than instead
		# of it. (This array was called "the queue" here, which is the one
		# thing it is not.)
		var current: Vector2i = frontier.pop_back()
		expanded.append(current)
		if current == to:
			return _reached(graph, came_from, from, to, expanded, frontier)

		_enqueue_unseen(graph, current, came_from, frontier)

	return SearchResult.nothing_found(expanded, frontier)
