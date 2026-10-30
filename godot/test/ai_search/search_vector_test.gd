# The conformance runner is a gate, and until now it was a gate with no planted
# cases. A review deleted three of its rules one at a time -- the walkability
# check, the shape check, the empty-expansion check -- and every gate in the
# repository stayed green. `lint-selftests` could not have caught that: it only
# ever looks inside `scripts/`, and this is GDScript.
#
# So the rules moved into SearchVector, and these are the cases it must reject.
extends GdUnitTestSuite


func test_a_good_vector_is_accepted() -> void:
	assert_str(SearchVector.why_not_a_vector(_good())).is_equal("")


func test_a_dictionary_that_is_not_a_vector_is_named_rather_than_crashing() -> void:
	# Pointing the runner at the wrong directory is an ordinary mistake, and it
	# used to end in a stack trace from the board builder.
	assert_str(SearchVector.why_not_a_vector({"hello": 1})).contains("no `costs`")


func test_rows_of_different_lengths_are_refused() -> void:
	# They were padded or truncated in silence, and the vector still conformed.
	var ragged: Dictionary = _good()
	ragged["costs"] = [[1, 1, 1], [1, 1], [1, 1, 1]]

	assert_str(SearchVector.why_not_a_vector(ragged)).contains("row 1 has 2 cells")


func test_a_cost_below_one_is_refused_rather_than_clamped() -> void:
	# GakGridGraph clamps it, so a vector written with a 0 would quietly become a
	# 1 and pass -- pinning an answer nobody wrote down.
	var cheap: Dictionary = _good()
	cheap["costs"] = [[1, 0, 1], [1, 1, 1], [1, 1, 1]]

	assert_str(SearchVector.why_not_a_vector(cheap)).contains("costs 0")


func test_an_end_off_the_board_is_refused() -> void:
	var astray: Dictionary = _good()
	astray["from"] = [0, -1]

	assert_str(SearchVector.why_not_a_vector(astray)).contains("not on a 3x3 board")


func test_a_vector_whose_claim_is_wrong_is_reported() -> void:
	var lying: Dictionary = _good()
	lying["expect"] = {"reached": true, "cheapest_cost": 99}

	var problems: Array[String] = SearchVector.check("lying", lying, _searches())

	assert_int(problems.size()).is_greater(0)
	assert_str(problems[0]).contains("expected the cheapest 99")


func test_a_vector_claiming_the_wrong_reachability_is_reported() -> void:
	var lying: Dictionary = _good()
	lying["expect"] = {"reached": false}

	var problems: Array[String] = SearchVector.check("lying", lying, _searches())

	assert_int(problems.size()).is_equal(4)
	assert_str(problems[0]).contains("reached=true, expected false")


func test_a_good_vector_reports_nothing() -> void:
	assert_int(SearchVector.check("good", _good(), _searches()).size()).is_equal(0)


func test_the_board_is_read_row_major() -> void:
	# A square board cannot tell row-major from transposed, so this one is not
	# square.
	var wide: Dictionary = _good()
	wide["costs"] = [[1, 1, 1, 7], [1, 1, 1, 1]]
	wide["to"] = [3, 1]

	var graph: GakGridGraph = SearchVector.board_of(wide)

	assert_int(graph.width).is_equal(4)
	assert_int(graph.height).is_equal(2)
	assert_int(graph.cost_at(Vector2i(3, 0))).is_equal(7)


# A search that walks one legal step and then claims it arrived. Every rule the
# runner had was about the steps -- each follows the last, each lands on ground
# a unit may enter -- and all of them hold for this. It is the same shape as the
# unvalidated `from` the wave 08 review found, at the other end of the path.
class StrollsOffAndSaysItArrived extends GakSearch:
	func _explore(graph: GakSearchGraph, from: Vector2i, _to: Vector2i) -> SearchResult:
		var step: Array[Vector2i] = [graph.neighbours(from)[0]]
		var looked_at: Array[Vector2i] = [from]
		return SearchResult.new(step, looked_at, [] as Array[Vector2i], 1, true)


func test_a_legal_path_to_the_wrong_cell_is_reported() -> void:
	var problems: Array[String] = SearchVector.check(
		"strolling", _good(), {"liar": StrollsOffAndSaysItArrived.new()}
	)

	assert_int(problems.size()).is_equal(1)
	assert_str(problems[0]).contains("does not arrive")


func test_a_search_that_starts_on_its_goal_arrives_with_no_steps() -> void:
	# The one empty path that is an arrival, and the reason the rule above is
	# not simply "a path must have a last cell".
	var standing: Dictionary = _good()
	standing["to"] = [0, 0]
	standing["expect"] = {"reached": true, "cheapest_cost": 0, "fewest_steps": 0}

	assert_int(SearchVector.check("standing", standing, _searches()).size()).is_equal(0)


# A 3x3 of flat ground, corner to corner: four steps, cost four.
func _good() -> Dictionary:
	return {
		"name": "flat",
		"costs": [[1, 1, 1], [1, 1, 1], [1, 1, 1]],
		"from": [0, 0],
		"to": [2, 2],
		"expect": {"reached": true, "cheapest_cost": 4, "fewest_steps": 4},
	}


func _searches() -> Dictionary:
	return {
		"breadth_first": BreadthFirstSearch.new(),
		"depth_first": DepthFirstSearch.new(),
		"dijkstra": DijkstraSearch.new(),
		"astar": AStarSearch.new(),
	}
