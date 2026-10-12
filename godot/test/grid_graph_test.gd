# The graph every search in this kit walks. If these are wrong, every lesson
# after them is wrong in a way that looks like a bug in the algorithm.
extends GdUnitTestSuite


func test_a_new_graph_costs_one_everywhere() -> void:
	var graph := GridGraph.new(3, 2)
	assert_int(graph.cost_at(Vector2i(0, 0))).is_equal(GridGraph.DEFAULT_COST)
	assert_int(graph.cost_at(Vector2i(2, 1))).is_equal(GridGraph.DEFAULT_COST)


func test_a_cell_off_the_board_is_blocked_rather_than_an_error() -> void:
	var graph := GridGraph.new(3, 2)
	assert_bool(graph.contains(Vector2i(3, 0))).is_false()
	assert_bool(graph.is_blocked(Vector2i(3, 0))).is_true()
	assert_bool(graph.is_blocked(Vector2i(-1, 0))).is_true()


func test_neighbours_drop_the_blocked_and_the_off_board() -> void:
	var graph := GridGraph.new(3, 3)
	# A corner has two neighbours on the board, and one of them is walled off.
	graph.block(Vector2i(1, 0))
	var found: Array[Vector2i] = graph.neighbours(Vector2i(0, 0))

	assert_int(found.size()).is_equal(1)
	assert_vector(found[0]).is_equal(Vector2i(0, 1))


func test_blocked_is_not_merely_expensive() -> void:
	var graph := GridGraph.new(2, 2)
	graph.set_cost(Vector2i(1, 1), 99)
	assert_bool(graph.is_blocked(Vector2i(1, 1))).is_false()

	graph.block(Vector2i(1, 1))
	assert_int(graph.cost_at(Vector2i(1, 1))).is_equal(GridGraph.BLOCKED)


func test_a_negative_dimension_gives_an_empty_board_and_no_engine_error() -> void:
	# Passing the negative straight to resize logged an engine error and left a
	# graph claiming `width = -2`: broken, and quiet about it.
	var graph := GridGraph.new(-2, 3)

	assert_int(graph.width).is_equal(0)
	assert_bool(graph.contains(Vector2i(0, 0))).is_false()
	assert_int(graph.cost_at(Vector2i(0, 0))).is_equal(GridGraph.BLOCKED)
	assert_int(graph.neighbours(Vector2i(0, 0)).size()).is_equal(0)


func test_a_duplicate_does_not_share_terrain() -> void:
	var graph := GridGraph.new(2, 2)
	var copy: GridGraph = graph.duplicate_graph()
	copy.block(Vector2i(0, 0))

	assert_bool(graph.is_blocked(Vector2i(0, 0))).is_false()
	assert_bool(copy.is_blocked(Vector2i(0, 0))).is_true()
