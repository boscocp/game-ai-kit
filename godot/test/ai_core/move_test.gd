# A Move is the type every addon in this kit produces, so the two things it
# promises are worth asserting directly rather than through the board.
#
# Both tests here exist because deleting the rule they cover left the suite
# green: `why_refused` rejects a blocked step before it ever asks what the walk
# costs, so `cost_on`'s own answer for a blocked cell was never looked at, and
# nothing had ever handed a Move an array and then changed it.
extends GdUnitTestSuite


func test_a_path_through_a_blocked_cell_is_not_merely_expensive() -> void:
	var graph := GridGraph.new(4, 2)
	graph.block(Vector2i(2, 0))
	var path: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]

	# Not "two plus a wall plus one". There is no number that means impossible,
	# which is why BLOCKED is not a large cost.
	assert_int(Move.new(1, path).cost_on(graph)).is_equal(GridGraph.BLOCKED)


func test_terrain_is_summed_over_the_cells_entered() -> void:
	var graph := GridGraph.new(4, 2)
	graph.set_cost(Vector2i(2, 0), 3)
	var path: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 0)]

	assert_int(Move.new(1, path).cost_on(graph)).is_equal(4)


func test_an_empty_path_costs_nothing_and_goes_nowhere() -> void:
	var graph := GridGraph.new(4, 2)
	var hold := Move.new(1, [] as Array[Vector2i])

	assert_int(hold.cost_on(graph)).is_equal(0)
	assert_vector(hold.destination(Vector2i(3, 1))).is_equal(Vector2i(3, 1))


func test_a_move_does_not_alias_the_path_it_was_given() -> void:
	var given: Array[Vector2i] = [Vector2i(1, 0)]
	var move := Move.new(1, given)

	given.append(Vector2i(2, 0))

	assert_int(move.path.size()).is_equal(1)
	assert_vector(move.destination(Vector2i(0, 0))).is_equal(Vector2i(1, 0))
