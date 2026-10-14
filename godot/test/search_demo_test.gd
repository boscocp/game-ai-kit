# The demo is the part of T3 whose real check is a person looking at it. These
# tests hold the half that is not a matter of taste: that it loads, that each
# algorithm can be chosen, that stepping replays the expansion rather than
# searching again, and that the board it builds actually makes the four differ.
#
# Without that last one the demo could come up green forever on a board where
# every search agrees, and the lesson it exists for would be invisible while
# everything passed.
extends GdUnitTestSuite

const BREADTH_FIRST: int = 0
const DEPTH_FIRST: int = 1
const DIJKSTRA: int = 2
const ASTAR: int = 3


func test_the_demo_comes_up_on_breadth_first_with_nothing_revealed() -> void:
	var demo: SearchDemo = _mounted_demo()

	assert_str(_status_of(demo)).contains("breadth-first")
	assert_str(_status_of(demo)).contains("expanded 0 of")


func test_stepping_reveals_one_cell_at_a_time_and_stops_at_the_end() -> void:
	var demo: SearchDemo = _mounted_demo()

	demo.step(1)
	assert_str(_status_of(demo)).contains("expanded 1 of")

	# Stepping past the end is an ordinary thing to do with a key held down.
	demo.step(100000)
	var total: int = demo._result.expanded.size()
	assert_str(_status_of(demo)).contains("expanded %d of %d" % [total, total])


func test_choosing_an_algorithm_restarts_the_replay() -> void:
	var demo: SearchDemo = _mounted_demo()
	demo.step(5)

	demo.choose_search(ASTAR)

	assert_str(_status_of(demo)).contains("a*")
	assert_str(_status_of(demo)).contains("expanded 0 of")


func test_choosing_out_of_range_lands_on_a_real_algorithm() -> void:
	var demo: SearchDemo = _mounted_demo()

	demo.choose_search(99)

	assert_str(_status_of(demo)).contains("a*")


func test_the_demo_board_actually_makes_the_four_disagree() -> void:
	# The point of the demo, asserted. On a board where every search returns
	# the same work, the demo shows nothing and nothing goes red.
	var demo: SearchDemo = _mounted_demo()
	var results: Array[SearchResult] = _all_results(demo)

	# Breadth-first walks the mud; Dijkstra pays less for a longer route.
	assert_int(results[DIJKSTRA].cost).is_less(results[BREADTH_FIRST].cost)
	# A* agrees with Dijkstra and looks at less of the board.
	assert_int(results[ASTAR].cost).is_equal(results[DIJKSTRA].cost)
	assert_bool(results[ASTAR].expanded.size() < results[DIJKSTRA].expanded.size()).is_true()
	# Depth-first gets there, by a route nobody would choose.
	assert_bool(results[DEPTH_FIRST].reached).is_true()
	assert_int(results[DEPTH_FIRST].cost).is_greater(results[DIJKSTRA].cost)


func _all_results(demo: SearchDemo) -> Array[SearchResult]:
	var found: Array[SearchResult] = []
	for index: int in range(4):
		demo.choose_search(index)
		found.append(demo._result)
	return found


func _mounted_demo() -> SearchDemo:
	var scene: PackedScene = load("res://demos/search/search_demo.tscn")
	var demo: SearchDemo = scene.instantiate()
	add_child(demo)
	return auto_free(demo)


func _status_of(demo: SearchDemo) -> String:
	var label: Label = demo.get_node("Interface/Status")
	return label.text


func test_the_replayed_frontier_ends_as_the_real_one_for_all_four() -> void:
	# `frontier_after` derives the frontier at each step from the expansion,
	# because the result keeps only the last one. At the last step the
	# derivation must equal what each search actually left, or the frontier
	# drawn while stepping is invented.
	var demo: SearchDemo = _mounted_demo()
	for index: int in range(4):
		demo.choose_search(index)
		var derived: Array[Vector2i] = demo.frontier_after(demo._result.expanded.size())
		var real: Array[Vector2i] = demo._result.frontier
		assert_array(derived).contains_exactly_in_any_order(real)


func test_the_frontier_is_drawn_while_stepping() -> void:
	var demo: SearchDemo = _mounted_demo()
	demo.step(3)
	assert_array(demo.decision_overlay()["frontier"]).is_not_empty()
	assert_that(demo.decision_overlay()["about_to_expand"]).is_equal(demo._result.expanded[3])


func test_the_status_compares_all_four_without_switching() -> void:
	# T8: the comparison was only visible by pressing 1 to 4 and remembering
	# the numbers. Every algorithm's count is on the screen at once now.
	var demo: SearchDemo = _mounted_demo()
	var results: Array[SearchResult] = _all_results(demo)

	for index: int in range(4):
		var count: String = "%s %d" % [SearchDemo.NAMES[index], results[index].expanded.size()]
		assert_str(_status_of(demo)).contains(count)
