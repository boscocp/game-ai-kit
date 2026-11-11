# The graph every search in this kit walks. If these are wrong, every lesson
# after them is wrong in a way that looks like a bug in the algorithm.
extends GdUnitTestSuite


func test_a_new_graph_costs_one_everywhere() -> void:
	var graph := GakGridGraph.new(3, 2)
	assert_int(graph.cost_at(Vector2i(0, 0))).is_equal(GakGridGraph.DEFAULT_COST)
	assert_int(graph.cost_at(Vector2i(2, 1))).is_equal(GakGridGraph.DEFAULT_COST)


func test_a_cell_off_the_board_is_blocked_rather_than_an_error() -> void:
	var graph := GakGridGraph.new(3, 2)
	assert_bool(graph.contains(Vector2i(3, 0))).is_false()
	assert_bool(graph.is_blocked(Vector2i(3, 0))).is_true()
	assert_bool(graph.is_blocked(Vector2i(-1, 0))).is_true()


func test_neighbours_drop_the_blocked_and_the_off_board() -> void:
	var graph := GakGridGraph.new(3, 3)
	# A corner has two neighbours on the board, and one of them is walled off.
	graph.block(Vector2i(1, 0))
	var found: Array[Vector2i] = graph.neighbours(Vector2i(0, 0))

	assert_int(found.size()).is_equal(1)
	assert_vector(found[0]).is_equal(Vector2i(0, 1))


func test_blocked_is_not_merely_expensive() -> void:
	var graph := GakGridGraph.new(2, 2)
	graph.set_cost(Vector2i(1, 1), 99)
	assert_bool(graph.is_blocked(Vector2i(1, 1))).is_false()

	graph.block(Vector2i(1, 1))
	assert_int(graph.cost_at(Vector2i(1, 1))).is_equal(GakGridGraph.BLOCKED)


func test_a_negative_dimension_gives_an_empty_board_and_no_engine_error() -> void:
	# Passing the negative straight to resize logged an engine error and left a
	# graph claiming `width = -2`: broken, and quiet about it.
	var graph := GakGridGraph.new(-2, 3)

	assert_int(graph.width).is_equal(0)
	assert_bool(graph.contains(Vector2i(0, 0))).is_false()
	assert_int(graph.cost_at(Vector2i(0, 0))).is_equal(GakGridGraph.BLOCKED)
	assert_int(graph.neighbours(Vector2i(0, 0)).size()).is_equal(0)


func test_a_duplicate_does_not_share_terrain() -> void:
	var graph := GakGridGraph.new(2, 2)
	var copy: GakGridGraph = graph.duplicate_graph()
	copy.block(Vector2i(0, 0))

	assert_bool(graph.is_blocked(Vector2i(0, 0))).is_false()
	assert_bool(copy.is_blocked(Vector2i(0, 0))).is_true()

func test_a_cost_below_one_is_clamped_and_blocked_stays_blocked() -> void:
	# A negative cost used to be accepted, and a move across it refunded
	# movement: a unit with three points finished a move with eight.
	var graph := GakGridGraph.new(3, 3)
	graph.set_cost(Vector2i(1, 1), -5)
	assert_int(graph.cost_at(Vector2i(1, 1))).is_equal(GakGridGraph.DEFAULT_COST)

	graph.set_cost(Vector2i(2, 2), 0)
	assert_int(graph.cost_at(Vector2i(2, 2))).is_equal(GakGridGraph.DEFAULT_COST)

	# BLOCKED is the one value outside the range, and stays itself.
	graph.block(Vector2i(0, 0))
	assert_int(graph.cost_at(Vector2i(0, 0))).is_equal(GakGridGraph.BLOCKED)


func test_the_constructors_cost_reaches_every_cell() -> void:
	# The third parameter had no caller and no test, which is how a parameter
	# quietly stops working.
	var rough := GakGridGraph.new(2, 2, 4)

	assert_int(rough.cost_at(Vector2i(0, 0))).is_equal(4)
	assert_int(rough.cost_at(Vector2i(1, 1))).is_equal(4)


func test_terrain_lands_on_the_cell_it_was_put_on() -> void:
	# The board is row-major, and on a square board a transposed index is
	# invisible: every test passed with the indexing swapped. A board that is
	# not square is what tells them apart.
	var graph := GakGridGraph.new(4, 2)
	graph.set_cost(Vector2i(3, 0), 7)

	assert_int(graph.cost_at(Vector2i(3, 0))).is_equal(7)
	assert_int(graph.cost_at(Vector2i(0, 1))).is_equal(GakGridGraph.DEFAULT_COST)
	assert_bool(graph.contains(Vector2i(3, 1))).is_true()
	assert_bool(graph.contains(Vector2i(0, 2))).is_false()


func test_the_directions_are_the_four_cardinals_in_a_declared_order() -> void:
	# The order is documented as a contract -- a search that breaks ties by
	# insertion order must behave the same on every machine -- and reversing it
	# left every test green.
	assert_int(GakGridGraph.DIRECTIONS.size()).is_equal(4)
	assert_vector(GakGridGraph.DIRECTIONS[0]).is_equal(Vector2i(0, -1))
	assert_vector(GakGridGraph.DIRECTIONS[1]).is_equal(Vector2i(1, 0))
	assert_vector(GakGridGraph.DIRECTIONS[2]).is_equal(Vector2i(0, 1))
	assert_vector(GakGridGraph.DIRECTIONS[3]).is_equal(Vector2i(-1, 0))


func test_neighbours_come_back_in_that_same_order() -> void:
	var found: Array[Vector2i] = GakGridGraph.new(3, 3).neighbours(Vector2i(1, 1))

	assert_vector(found[0]).is_equal(Vector2i(1, 0))
	assert_vector(found[1]).is_equal(Vector2i(2, 1))
	assert_vector(found[2]).is_equal(Vector2i(1, 2))
	assert_vector(found[3]).is_equal(Vector2i(0, 1))


func test_writing_off_the_board_changes_nothing_on_it() -> void:
	var graph := GakGridGraph.new(2, 2)
	graph.set_cost(Vector2i(5, 5), 9)
	graph.set_cost(Vector2i(-1, 0), 9)

	assert_int(graph.cost_at(Vector2i(0, 0))).is_equal(GakGridGraph.DEFAULT_COST)
	assert_int(graph.cost_at(Vector2i(1, 1))).is_equal(GakGridGraph.DEFAULT_COST)


func test_a_negative_height_is_clamped_like_a_negative_width() -> void:
	var graph := GakGridGraph.new(3, -4)

	assert_int(graph.height).is_equal(0)
	assert_bool(graph.contains(Vector2i(0, 0))).is_false()


# A game's board, built with no arguments: the shape that made a bare
# `new(width, height)` in `duplicate_graph` fail (review of wave 176).
class SixColumnBoard extends GakGridGraph:
	func _init() -> void:
		super(6, 2)


func test_a_subclass_s_copy_is_still_a_gak_grid_graph() -> void:
	var board := SixColumnBoard.new()
	board.block(Vector2i(5, 1))
	var copy: GakGridGraph = board.duplicate_graph()

	assert_object(copy).is_not_null()
	assert_bool(copy.get_script() == GakGridGraph).is_true()
	assert_int(copy.width).is_equal(6)
	assert_bool(copy.is_blocked(Vector2i(5, 1))).is_true()
