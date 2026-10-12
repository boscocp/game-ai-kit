# What a turn-based board has to get right before any AI is allowed near it.
#
# Every test here is about a rule the later addons will lean on: that applying a
# move does not disturb the state a search is still exploring, that terrain is
# paid for on entry, and that an illegal move is refused with a reason rather
# than half-applied.
extends GdUnitTestSuite

const RED: int = 0
const BLUE: int = 1


func test_turns_alternate() -> void:
	var state: BoardState = _two_unit_board()
	assert_int(state.current_faction).is_equal(RED)

	var after_red: BoardState = state.end_turn()
	assert_int(after_red.current_faction).is_equal(BLUE)

	var after_blue: BoardState = after_red.end_turn()
	assert_int(after_blue.current_faction).is_equal(RED)
	assert_int(after_blue.turn_number).is_equal(2)


func test_a_move_beyond_movement_points_is_refused() -> void:
	var state: BoardState = _two_unit_board()
	# Three movement points, four cells of flat ground. The route turns north
	# rather than running straight east, because straight east walks into the
	# other unit and would be refused for a different reason -- which is what
	# the first version of this test actually asserted.
	var path: Array[Vector2i] = [
		Vector2i(2, 1), Vector2i(3, 1), Vector2i(3, 0), Vector2i(2, 0),
	]
	var move := Move.new(1, path)

	assert_str(state.why_refused(move)).contains("movement left")
	assert_object(state.apply(move)).is_null()


func test_terrain_cost_changes_what_a_move_costs() -> void:
	var state: BoardState = _two_unit_board()
	# Three cells, round the top of the board and clear of the other unit.
	var route: Array[Vector2i] = [Vector2i(2, 1), Vector2i(2, 0), Vector2i(3, 0)]
	var walk := Move.new(1, route)
	assert_int(walk.cost_on(state.graph)).is_equal(3)
	assert_str(state.why_refused(walk)).is_equal(BoardState.LEGAL)

	# Mud on the last cell of the same route: same cells, same distance, and
	# now the unit cannot afford it.
	state.graph.set_cost(Vector2i(3, 0), 3)
	assert_int(walk.cost_on(state.graph)).is_equal(5)
	assert_str(state.why_refused(walk)).contains("costs 5")


func test_applying_a_move_leaves_the_original_state_untouched() -> void:
	var state: BoardState = _two_unit_board()
	var move := Move.new(1, _walk_east(Vector2i(1, 1), 2))

	var next: BoardState = state.apply(move)
	assert_object(next).is_not_null()
	assert_vector(next.unit_by_id(1).cell).is_equal(Vector2i(3, 1))
	assert_int(next.unit_by_id(1).movement_points).is_equal(1)

	# The state a search is still holding must not have moved under it.
	assert_vector(state.unit_by_id(1).cell).is_equal(Vector2i(1, 1))
	assert_int(state.unit_by_id(1).movement_points).is_equal(3)


func test_a_blocked_cell_is_refused() -> void:
	var state: BoardState = _two_unit_board()
	state.graph.block(Vector2i(2, 1))
	var move := Move.new(1, _walk_east(Vector2i(1, 1), 1))

	assert_str(state.why_refused(move)).contains("blocked")


func test_a_step_off_the_board_says_so_rather_than_saying_blocked() -> void:
	var state: BoardState = _two_unit_board()
	# West twice from (1, 1) leaves the board. Off-board is *also* blocked, so
	# without this the "is it on the board" rule could be deleted outright and
	# nothing noticed: the blocked rule caught every case and only the message
	# changed. A message is the whole value of that rule.
	var path: Array[Vector2i] = [Vector2i(0, 1), Vector2i(-1, 1)]

	assert_str(state.why_refused(Move.new(1, path))).contains("off the board")


func test_a_diagonal_step_is_refused() -> void:
	var state: BoardState = _two_unit_board()
	var path: Array[Vector2i] = [Vector2i(2, 2)]
	var move := Move.new(1, path)

	assert_str(state.why_refused(move)).contains("no diagonals")


func test_a_cell_held_by_another_unit_is_refused() -> void:
	var state: BoardState = _two_unit_board()
	# Unit 2 stands at (4, 1); walking three cells east lands on it. The cost
	# is three and the unit has three, so occupancy is the only thing refusing.
	var onto_unit := Move.new(1, _walk_east(Vector2i(1, 1), 3))

	assert_str(state.why_refused(onto_unit)).contains("occupied by unit 2")
	assert_object(state.apply(onto_unit)).is_null()


func test_a_unit_of_the_other_faction_may_not_move() -> void:
	var state: BoardState = _two_unit_board()
	var move := Move.new(2, _walk_east(Vector2i(4, 1), 1))

	assert_str(state.why_refused(move)).contains("faction")
	assert_object(state.apply(move)).is_null()


func test_an_empty_path_is_a_legal_hold() -> void:
	var state: BoardState = _two_unit_board()
	var hold := Move.new(1, [] as Array[Vector2i])

	assert_str(state.why_refused(hold)).is_equal(BoardState.LEGAL)
	var next: BoardState = state.apply(hold)
	assert_vector(next.unit_by_id(1).cell).is_equal(Vector2i(1, 1))


func test_end_turn_restores_movement_only_for_the_side_about_to_move() -> void:
	var state: BoardState = _two_unit_board()
	var spent: BoardState = state.apply(Move.new(1, _walk_east(Vector2i(1, 1), 2)))
	assert_int(spent.unit_by_id(1).movement_points).is_equal(1)

	var blue_turn: BoardState = spent.end_turn()
	# Blue is about to move and is topped up; red's spent points stay spent,
	# because what red has left is information blue is entitled to.
	assert_int(blue_turn.unit_by_id(2).movement_points).is_equal(3)
	assert_int(blue_turn.unit_by_id(1).movement_points).is_equal(1)


func test_a_dead_unit_never_reaches_the_board() -> void:
	var graph := GridGraph.new(6, 3)
	var given: Array[Unit] = [
		Unit.new(1, RED, Vector2i(1, 1)),
		Unit.new(2, BLUE, Vector2i(4, 1), 0),
	]
	var state := BoardState.new(graph, given, RED)

	# One rule, and every view of the board agrees with it. Letting a corpse in
	# made four of them disagree: it blocked a cell, was invisible to units_of,
	# and collected fresh movement at the start of its side's turn.
	assert_int(state.units.size()).is_equal(1)
	assert_object(state.unit_by_id(2)).is_null()
	assert_object(state.unit_at(Vector2i(4, 1))).is_null()
	assert_int(state.units_of(BLUE).size()).is_equal(0)
	assert_int(state.end_turn().units_of(BLUE).size()).is_equal(0)


func test_the_cell_a_dead_unit_stood_on_is_not_blocked() -> void:
	var graph := GridGraph.new(6, 3)
	var given: Array[Unit] = [
		Unit.new(1, RED, Vector2i(1, 1)),
		Unit.new(2, BLUE, Vector2i(4, 1), 0),
	]
	var state := BoardState.new(graph, given, RED)

	assert_str(state.why_refused(Move.new(1, _walk_east(Vector2i(1, 1), 3)))).is_equal(
		BoardState.LEGAL
	)


func test_the_state_does_not_alias_the_units_it_was_given() -> void:
	var graph := GridGraph.new(6, 3)
	var mine := Unit.new(1, RED, Vector2i(1, 1))
	var given: Array[Unit] = [mine]
	var state := BoardState.new(graph, given, RED)

	# Whoever built the state kept a reference to the unit. The state must not
	# move when they do, or the immutability every search depends on is a
	# comment rather than a property.
	mine.cell = Vector2i(5, 2)
	given.append(Unit.new(9, BLUE, Vector2i(0, 0)))

	assert_vector(state.unit_by_id(1).cell).is_equal(Vector2i(1, 1))
	assert_int(state.units.size()).is_equal(1)


# A 6x3 board of flat ground, red's unit 1 at (1, 1) and blue's unit 2 at (4, 1).
func _two_unit_board() -> BoardState:
	var graph := GridGraph.new(6, 3)
	var units: Array[Unit] = [
		Unit.new(1, RED, Vector2i(1, 1)),
		Unit.new(2, BLUE, Vector2i(4, 1)),
	]
	return BoardState.new(graph, units, RED)


# The cells entered by walking `steps` cells east from `start`.
func _walk_east(start: Vector2i, steps: int) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	for index: int in range(steps):
		path.append(start + Vector2i(index + 1, 0))
	return path
