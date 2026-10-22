# What the four searches promise, and the one place they differ.
#
# Most of these run against all four, because the contract they share is the
# same for all four and a contract tested on one implementation is a contract
# tested nowhere. The tests that single one out are the lessons: breadth-first
# cannot see cost, Dijkstra can, A* agrees with Dijkstra and looks at less.
extends GdUnitTestSuite


func test_every_search_finds_a_route_across_an_open_board() -> void:
	for search: Search in _all_searches():
		var result: SearchResult = search.search(
			GridSearchGraph.new(GridGraph.new(6, 4)), Vector2i(0, 0), Vector2i(5, 3)
		)

		assert_bool(result.reached).override_failure_message(
			"%s did not reach the goal" % search
		).is_true()
		assert_vector(result.path[result.path.size() - 1]).is_equal(Vector2i(5, 3))


func test_no_search_puts_the_starting_cell_in_the_path() -> void:
	# The contract in Pathfinder, and what Move.cost_on depends on: you never
	# pay to stand where you already are.
	for search: Search in _all_searches():
		var result: SearchResult = search.search(
			GridSearchGraph.new(GridGraph.new(5, 3)), Vector2i(1, 1), Vector2i(3, 1)
		)

		assert_bool(result.path.has(Vector2i(1, 1))).is_false()


func test_every_path_is_one_a_unit_could_actually_walk() -> void:
	var graph: GridGraph = _board_with_a_wall()
	for search: Search in _all_searches():
		var result: SearchResult = search.search(GridSearchGraph.new(graph), Vector2i(0, 2), Vector2i(4, 2))

		assert_str(_why_unwalkable(graph, Vector2i(0, 2), result.path)).is_equal("")


func test_a_goal_behind_a_wall_is_reported_as_unreachable() -> void:
	var graph := GridGraph.new(5, 3)
	for row: int in range(3):
		graph.block(Vector2i(2, row))

	for search: Search in _all_searches():
		var result: SearchResult = search.search(GridSearchGraph.new(graph), Vector2i(0, 1), Vector2i(4, 1))

		assert_bool(result.reached).is_false()
		assert_int(result.path.size()).is_equal(0)
		assert_int(result.cost).is_equal(SearchResult.NO_ROUTE)
		# The work is still on show: that expansion is the picture of the
		# region that *is* reachable, which is how you see it was walled off
		# rather than that the search broke.
		assert_bool(result.expanded.size() > 0).is_true()


func test_starting_on_the_goal_reaches_it_with_an_empty_path() -> void:
	for search: Search in _all_searches():
		var result: SearchResult = search.search(
			GridSearchGraph.new(GridGraph.new(4, 4)), Vector2i(2, 2), Vector2i(2, 2)
		)

		# Empty, like a failed search -- and `reached` is what tells them apart.
		assert_int(result.path.size()).is_equal(0)
		assert_bool(result.reached).is_true()
		assert_int(result.cost).is_equal(0)


func test_breadth_first_cannot_see_cost_and_dijkstra_can() -> void:
	# Two routes of the same length, one of them through mud. This is the
	# whole reason Dijkstra exists, in one assertion.
	var graph: GridGraph = _board_with_mud()

	var blind: SearchResult = BreadthFirstSearch.new().search(
		GridSearchGraph.new(graph), Vector2i(0, 1), Vector2i(4, 1)
	)
	var costed: SearchResult = DijkstraSearch.new().search(
		GridSearchGraph.new(graph), Vector2i(0, 1), Vector2i(4, 1)
	)

	assert_int(costed.cost).is_less(blind.cost)
	assert_int(blind.path.size()).is_equal(costed.path.size() - 2)


func test_astar_agrees_with_dijkstra_and_looks_at_less() -> void:
	var graph: GridGraph = _board_with_mud()
	var dijkstra: SearchResult = DijkstraSearch.new().search(
		GridSearchGraph.new(graph), Vector2i(0, 1), Vector2i(4, 1)
	)
	var astar: SearchResult = AStarSearch.new().search(GridSearchGraph.new(graph), Vector2i(0, 1), Vector2i(4, 1))

	# Same cost is the guarantee an admissible heuristic buys. Fewer expansions
	# is why anybody bothers.
	assert_int(astar.cost).is_equal(dijkstra.cost)
	assert_bool(astar.expanded.size() <= dijkstra.expanded.size()).is_true()


func test_an_astar_with_a_zero_heuristic_is_dijkstra() -> void:
	# Not a curiosity: it is the clearest statement of what the heuristic does.
	# The guess belongs to the graph now, so the blind A* is an ordinary A*
	# handed a graph that guesses nothing.
	var graph: GridGraph = _board_with_mud()

	var guided: SearchResult = DijkstraSearch.new().search(
		GridSearchGraph.new(graph), Vector2i(0, 1), Vector2i(4, 1)
	)
	var unguided: SearchResult = AStarSearch.new().search(
		_GuessesNothing.new(graph), Vector2i(0, 1), Vector2i(4, 1)
	)

	assert_int(unguided.cost).is_equal(guided.cost)
	assert_int(unguided.expanded.size()).is_equal(guided.expanded.size())


func test_depth_first_is_allowed_to_be_bad_but_not_wrong() -> void:
	var graph: GridGraph = _board_with_a_wall()
	var result: SearchResult = DepthFirstSearch.new().search(
		GridSearchGraph.new(graph), Vector2i(0, 2), Vector2i(4, 2)
	)

	assert_bool(result.reached).is_true()
	assert_str(_why_unwalkable(graph, Vector2i(0, 2), result.path)).is_equal("")


func test_no_search_expands_the_same_cell_twice() -> void:
	# A cell improved after it was queued is queued again, so the frontier can
	# hold it twice. Expanding the stale copy changes no answer and costs an
	# expansion -- and it made `expanded` a count of pops rather than of cells,
	# which is what the demo draws and what A* is judged on.
	# This board is not decorative and was not invented: it was searched for.
	# The first version of this test used the mud board, where the rule never
	# fires -- deleting the guard left the suite green. These costs are the
	# first 4x4 board found on which A* reaches a cell by a dear route, improves
	# it later, and would take it off the frontier twice.
	var graph: GridGraph = _board_from([
		5, 4, 1, 8,
		9, 4, 8, 8,
		4, 1, 5, 2,
		4, 6, 1, 9,
	])
	for search: Search in _all_searches():
		var result: SearchResult = search.search(GridSearchGraph.new(graph), Vector2i(0, 0), Vector2i(3, 3))

		assert_vector(_first_repeat(result.expanded)).override_failure_message(
			"%s expanded a cell twice" % search
		).is_equal(Search.NO_PARENT)


func test_the_frontier_is_empty_when_a_search_exhausts_the_map() -> void:
	var graph := GridGraph.new(3, 3)
	graph.block(Vector2i(1, 0))
	graph.block(Vector2i(1, 1))
	graph.block(Vector2i(1, 2))

	var result: SearchResult = BreadthFirstSearch.new().search(
		GridSearchGraph.new(graph), Vector2i(0, 0), Vector2i(2, 2)
	)

	assert_int(result.frontier.size()).is_equal(0)


func test_depth_first_is_not_breadth_first() -> void:
	# Turning `pop_back` into `pop_front` makes depth-first *be* breadth-first,
	# and nothing in the suite noticed: the demo's entire lesson was ungated.
	var graph := GridGraph.new(6, 6)
	var breadth: SearchResult = BreadthFirstSearch.new().search(
		GridSearchGraph.new(graph), Vector2i(0, 0), Vector2i(3, 0)
	)
	var depth: SearchResult = DepthFirstSearch.new().search(
		GridSearchGraph.new(graph), Vector2i(0, 0), Vector2i(3, 0)
	)

	assert_int(breadth.path.size()).is_equal(3)
	assert_bool(depth.path.size() > breadth.path.size()).override_failure_message(
		"depth-first found a path of %d, breadth-first %d -- it is behaving like a queue"
		% [depth.path.size(), breadth.path.size()]
	).is_true()


func test_the_cost_counts_every_cell_entered_including_the_first() -> void:
	# `_cost_of` skipping the first cell of the path left `make test-godot`
	# green: every cost this suite checked was either zero or compared against
	# another search. Only the conformance vectors caught it, and a unit test
	# should not need them to.
	var graph := GridGraph.new(4, 1)
	graph.set_cost(Vector2i(1, 0), 5)

	var result: SearchResult = DijkstraSearch.new().search(
		GridSearchGraph.new(graph), Vector2i(0, 0), Vector2i(3, 0)
	)

	assert_int(result.path.size()).is_equal(3)
	assert_int(result.cost).is_equal(7)


func test_a_start_that_is_not_on_the_board_finds_nothing() -> void:
	# It used to come back `reached`, with a path that walked in from nowhere,
	# and the conformance runner's walkability check accepted it because every
	# individual step was legal.
	for search: Search in _all_searches():
		var result: SearchResult = search.search(
			GridSearchGraph.new(GridGraph.new(5, 5)), Vector2i(-1, 2), Vector2i(3, 2)
		)

		assert_bool(result.reached).is_false()
		assert_int(result.path.size()).is_equal(0)
		assert_int(result.expanded.size()).is_equal(0)


func test_a_start_inside_a_wall_may_still_walk_out_of_it() -> void:
	# Cost is paid on entering a cell, never on leaving one, and something may
	# well have put a unit in a wall. This is the deliberate other half of the
	# rule above, so that "guard the start" does not quietly become "refuse
	# anything awkward".
	var graph := GridGraph.new(5, 5)
	graph.block(Vector2i(1, 2))

	var result: SearchResult = DijkstraSearch.new().search(
		GridSearchGraph.new(graph), Vector2i(1, 2), Vector2i(3, 2)
	)

	assert_bool(result.reached).is_true()
	assert_int(result.cost).is_equal(2)


# A grid whose guess is always zero, which makes A* on it Dijkstra by
# definition.
class _GuessesNothing extends GridSearchGraph:
	func estimate(_node: Vector2i, _goal: Vector2i) -> int:
		return 0


func _all_searches() -> Array[Search]:
	return [
		BreadthFirstSearch.new(),
		DepthFirstSearch.new(),
		DijkstraSearch.new(),
		AStarSearch.new(),
	] as Array[Search]


# A 5x5 board with a wall down the middle and a gap at the bottom.
func _board_with_a_wall() -> GridGraph:
	var graph := GridGraph.new(5, 5)
	for row: int in range(4):
		graph.block(Vector2i(2, row))
	return graph


# A 5x3 board whose middle row is mud, so the straight route is the dear one.
func _board_with_mud() -> GridGraph:
	var graph := GridGraph.new(5, 3)
	for column: int in range(1, 4):
		graph.set_cost(Vector2i(column, 1), 9)
	return graph


# A square board from a row-major list of entry costs.
func _board_from(costs: Array[int]) -> GridGraph:
	var side: int = int(sqrt(float(costs.size())))
	var graph := GridGraph.new(side, side)
	for index: int in range(costs.size()):
		graph.set_cost(Vector2i(index % side, index / side), costs[index])
	return graph


# The first cell that appears twice, or Search.NO_PARENT when none does.
func _first_repeat(cells: Array[Vector2i]) -> Vector2i:
	var seen: Dictionary = {}
	for cell: Vector2i in cells:
		if seen.has(cell):
			return cell
		seen[cell] = true
	return Search.NO_PARENT


# Why this path could not be walked, or "" when it could. Checks the contract
# every search here promises: cardinal steps, nothing blocked, starting from
# the cell the search was given.
func _why_unwalkable(graph: GridGraph, from: Vector2i, path: Array[Vector2i]) -> String:
	var previous: Vector2i = from
	for cell: Vector2i in path:
		if not GridGraph.DIRECTIONS.has(cell - previous):
			return "%s does not follow %s" % [cell, previous]
		if graph.is_blocked(cell):
			return "%s is blocked" % cell
		previous = cell
	return ""


func test_a_flood_goes_round_a_wall_and_stops_at_its_limit() -> void:
	var graph := GridGraph.new(3, 3)
	graph.block(Vector2i(1, 0))
	graph.block(Vector2i(1, 1))
	var reached: Dictionary[Vector2i, int] = CostFlood.within(GridSearchGraph.new(graph), Vector2i(0, 0), 4)
	assert_int(reached[Vector2i(0, 0)]).is_equal(0)
	assert_int(reached[Vector2i(1, 2)]).is_equal(3)
	assert_int(reached[Vector2i(2, 2)]).is_equal(4)
	assert_bool(reached.has(Vector2i(2, 1))).is_false()


func test_a_flood_from_off_the_graph_reaches_nothing() -> void:
	assert_int(CostFlood.within(GridSearchGraph.new(GridGraph.new(2, 2)), Vector2i(5, 5), 9).size()).is_equal(0)
