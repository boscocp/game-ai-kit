# The four searches on a graph that is not a grid: the port's planted case.
#
# A handful of waypoints joined by roads, where the route with the fewest hops
# is not the cheapest. If a search quietly counted hops instead of cost, or A*
# were handed a guess that overshoots, these fail -- and the last test shows
# the second failure happening, so this file is known to be able to see it.
#
#        B(1,1) - C(2,2) - D(3,1)
#       /                       \
#   A(0,0) ----- M(2,0) ----- G(4,0)
#
# M is a ford that costs 9 to enter, every other waypoint 1. Across M is two
# hops and costs 10; round the top is four hops and costs 4.
extends GdUnitTestSuite

const START: Vector2i = Vector2i(0, 0)
const FORD: Vector2i = Vector2i(2, 0)
const GOAL: Vector2i = Vector2i(4, 0)
const ROUND_THE_TOP: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 1), GOAL]


func test_breadth_first_takes_the_fewest_hops_across_the_ford() -> void:
	var result: SearchResult = BreadthFirstSearch.new().search(_Waypoints.new(), START, GOAL)

	assert_array(result.path).is_equal([FORD, GOAL])
	assert_int(result.cost).is_equal(10)


func test_dijkstra_and_astar_go_round_the_top_because_it_is_cheaper() -> void:
	for search: GakSearch in [DijkstraSearch.new(), AStarSearch.new()] as Array[GakSearch]:
		var result: SearchResult = search.search(_Waypoints.new(), START, GOAL)

		assert_array(result.path).override_failure_message(
			"%s took %s" % [search, result.path]
		).is_equal(ROUND_THE_TOP)
		assert_int(result.cost).is_equal(4)


func test_astar_costs_what_dijkstra_costs_with_a_consistent_guess() -> void:
	var graph := _Waypoints.new()

	var dijkstra: SearchResult = DijkstraSearch.new().search(graph, START, GOAL)
	var astar: SearchResult = AStarSearch.new().search(graph, START, GOAL)

	assert_int(astar.cost).is_equal(dijkstra.cost)
	assert_bool(astar.expanded.size() <= dijkstra.expanded.size()).is_true()


func test_every_search_walks_roads_that_exist() -> void:
	# Depth-first is allowed any route; none is allowed one off the map.
	var graph := _Waypoints.new()
	for search: GakSearch in _all_searches():
		var result: SearchResult = search.search(graph, START, GOAL)

		assert_bool(result.reached).is_true()
		assert_str(_why_not_a_route(graph, result.path)).is_equal("")


func test_a_start_that_is_not_a_waypoint_finds_nothing() -> void:
	for search: GakSearch in _all_searches():
		var result: SearchResult = search.search(_Waypoints.new(), Vector2i(1, 0), GOAL)

		assert_bool(result.reached).is_false()
		assert_int(result.cost).is_equal(SearchResult.NO_ROUTE)


func test_a_guess_that_overshoots_makes_astar_quietly_dearer() -> void:
	# The failure the promise on `GakSearchGraph.estimate` exists to prevent, shown
	# rather than described: the guess calls the top route dear, A* believes it,
	# and comes back fast with the ford. If this ever matched Dijkstra, the test
	# above it could no longer tell a good guess from a bad one.
	var honest: SearchResult = DijkstraSearch.new().search(_Waypoints.new(), START, GOAL)
	var misled: SearchResult = AStarSearch.new().search(_Overshoots.new(), START, GOAL)

	assert_bool(misled.reached).is_true()
	assert_int(misled.cost).is_greater(honest.cost)


func test_a_guess_that_never_overshoots_can_still_mislead_this_astar() -> void:
	# Admissible is not enough here. On `_Admissible` the guess at the
	# shortcut is exactly what is left from it, never more -- and A*, which
	# never expands a node twice, still pays 8 where Dijkstra pays 7. The
	# guess drops by 6 across a step that costs 1, so it is not consistent:
	# the junction is reached first the dear way, by the detour, and is never
	# looked at again. That is why the promise
	# on `GakSearchGraph.estimate` says consistent.
	var graph := _Admissible.new()

	var honest: SearchResult = DijkstraSearch.new().search(graph, _Admissible.SOURCE, _Admissible.TARGET)
	var misled: SearchResult = AStarSearch.new().search(graph, _Admissible.SOURCE, _Admissible.TARGET)

	assert_int(honest.cost).is_equal(7)
	assert_int(misled.cost).is_equal(8)


func _all_searches() -> Array[GakSearch]:
	return [
		BreadthFirstSearch.new(),
		DepthFirstSearch.new(),
		DijkstraSearch.new(),
		AStarSearch.new(),
	] as Array[GakSearch]


# Why this path is not a walk along the roads from START, or "" when it is.
func _why_not_a_route(graph: _Waypoints, path: Array[Vector2i]) -> String:
	var previous: Vector2i = START
	for node: Vector2i in path:
		if not graph.neighbours(previous).has(node):
			return "no road from %s to %s" % [previous, node]
		previous = node
	return ""


# The waypoints in the picture above, as a `GakSearchGraph`.
class _Waypoints extends GakSearchGraph:
	const ROADS: Dictionary = {
		Vector2i(0, 0): [Vector2i(2, 0), Vector2i(1, 1)],
		Vector2i(2, 0): [Vector2i(0, 0), Vector2i(4, 0)],
		Vector2i(1, 1): [Vector2i(0, 0), Vector2i(2, 2)],
		Vector2i(2, 2): [Vector2i(1, 1), Vector2i(3, 1)],
		Vector2i(3, 1): [Vector2i(2, 2), Vector2i(4, 0)],
		Vector2i(4, 0): [Vector2i(2, 0), Vector2i(3, 1)],
	}
	const CHEAPEST: int = 1

	func contains(node: Vector2i) -> bool:
		return ROADS.has(node)

	func neighbours(node: Vector2i) -> Array[Vector2i]:
		var found: Array[Vector2i] = []
		found.assign(ROADS.get(node, []))
		return found

	func cost_at(node: Vector2i) -> int:
		return 9 if node == Vector2i(2, 0) else CHEAPEST

	# The fewest hops left, times the cheapest a hop can cost. Consistent for
	# the same reason Manhattan distance is on a grid: one hop changes the hop
	# count by at most one, and no hop costs less than CHEAPEST.
	func estimate(node: Vector2i, goal: Vector2i) -> int:
		return CHEAPEST * _hops(node, goal)

	# Breadth-first from `node`, counting rings until `goal` turns up.
	func _hops(node: Vector2i, goal: Vector2i) -> int:
		var distance: Dictionary = {node: 0}
		var queue: Array[Vector2i] = [node]
		while not queue.is_empty():
			var current: Vector2i = queue.pop_front()
			if current == goal:
				return distance[current]
			_ring(current, distance, queue)
		return 0

	# Every neighbour of `current` not yet counted, one hop further out.
	func _ring(current: Vector2i, distance: Dictionary, queue: Array[Vector2i]) -> void:
		for next: Vector2i in neighbours(current):
			if not distance.has(next):
				distance[next] = distance[current] + 1
				queue.append(next)


# The same waypoints, with a guess that calls the top route far dearer than
# it is.
class _Overshoots extends _Waypoints:
	func estimate(node: Vector2i, goal: Vector2i) -> int:
		return 100 if ROUND_THE_TOP.has(node) and node != goal else super.estimate(node, goal)


# Three ways from the source to the target, priced by what each waypoint
# costs to enter: detour 3, shortcut 1, junction 1, side road 3, target 5.
# By the shortcut and the junction is cheapest, 7; the side road costs 8; the
# detour and the junction 9. The guess at the shortcut is 6, exactly what is
# left from it (the junction, then the target), and zero everywhere else.
class _Admissible extends GakSearchGraph:
	const SOURCE: Vector2i = Vector2i(0, 0)
	const DETOUR: Vector2i = Vector2i(1, -1)
	const SHORTCUT: Vector2i = Vector2i(1, 1)
	const JUNCTION: Vector2i = Vector2i(2, 0)
	const SIDE_ROAD: Vector2i = Vector2i(2, 2)
	const TARGET: Vector2i = Vector2i(3, 0)
	const ROADS: Dictionary = {
		SOURCE: [DETOUR, SHORTCUT, SIDE_ROAD],
		DETOUR: [SOURCE, JUNCTION],
		SHORTCUT: [SOURCE, JUNCTION],
		JUNCTION: [DETOUR, SHORTCUT, TARGET],
		SIDE_ROAD: [SOURCE, TARGET],
		TARGET: [JUNCTION, SIDE_ROAD],
	}
	const COSTS: Dictionary = {SOURCE: 1, DETOUR: 3, SHORTCUT: 1, JUNCTION: 1, SIDE_ROAD: 3, TARGET: 5}

	func contains(node: Vector2i) -> bool:
		return ROADS.has(node)

	func neighbours(node: Vector2i) -> Array[Vector2i]:
		var found: Array[Vector2i] = []
		found.assign(ROADS.get(node, []))
		return found

	func cost_at(node: Vector2i) -> int:
		return COSTS[node]

	func estimate(node: Vector2i, _goal: Vector2i) -> int:
		return 6 if node == SHORTCUT else 0
