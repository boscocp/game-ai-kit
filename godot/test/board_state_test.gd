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


func test_a_move_naming_a_unit_that_is_not_there_is_refused() -> void:
	var state: BoardState = _two_unit_board()

	assert_str(state.why_refused(Move.new(99, _walk_east(Vector2i(1, 1), 1)))).contains(
		"no unit with id 99"
	)
	assert_object(state.apply(Move.new(99, _walk_east(Vector2i(1, 1), 1)))).is_null()


func test_applying_a_move_keeps_whose_turn_it_is_and_the_turn_number() -> void:
	# The copy used to be built without either, and nothing noticed: a search
	# one move deep would have handed the turn to faction 0 and reset the
	# episode counter.
	# Blue's turn, deliberately: the first version of this test ran two turns
	# and ended back on faction 0, so a copy that hardcoded 0 passed it. A test
	# whose expected value is also the broken value is measuring nothing.
	var state: BoardState = _two_unit_board().end_turn()
	assert_int(state.current_faction).is_equal(BLUE)

	var next: BoardState = state.apply(Move.new(2, _walk_east(Vector2i(4, 1), 1)))

	assert_int(next.current_faction).is_equal(BLUE)
	assert_int(next.turn_number).is_equal(state.turn_number)
	assert_int(next.turn_number).is_equal(1)


func test_end_turn_leaves_the_original_state_untouched() -> void:
	# Immutability was tested for apply and not for end_turn, so end_turn could
	# have been rewriting the state a search was still holding.
	var state: BoardState = _two_unit_board()
	var after: BoardState = state.end_turn()

	assert_int(state.current_faction).is_equal(RED)
	assert_int(state.turn_number).is_equal(0)
	assert_int(after.current_faction).is_equal(BLUE)


func test_end_turn_honours_the_faction_count_and_the_points_it_is_given() -> void:
	# Both arguments had defaults, no caller in a test, and no assertion.
	var state: BoardState = _two_unit_board()
	var three_sided: BoardState = state.end_turn(3, 7)

	assert_int(three_sided.current_faction).is_equal(1)
	assert_int(three_sided.unit_by_id(2).movement_points).is_equal(7)
	assert_int(three_sided.end_turn(3, 7).current_faction).is_equal(2)
	assert_int(three_sided.end_turn(3, 7).end_turn(3, 7).current_faction).is_equal(0)


func test_end_turn_with_no_factions_does_not_divide_by_zero() -> void:
	# `% 0` is an engine error that returned null from the one type whose apply
	# argues that refusing with an error in the log is worse than refusing with
	# a value.
	var after: BoardState = _two_unit_board().end_turn(0)

	assert_object(after).is_not_null()
	assert_int(after.current_faction).is_equal(0)


func test_a_unit_may_walk_back_over_its_own_starting_cell() -> void:
	# The exemption that allows this is what makes a loop legal, and nothing
	# was testing it.
	var state: BoardState = _two_unit_board()
	var loop: Array[Vector2i] = [Vector2i(2, 1), Vector2i(1, 1)]

	assert_str(state.why_refused(Move.new(1, loop))).is_equal(BoardState.LEGAL)
	assert_vector(state.apply(Move.new(1, loop)).unit_by_id(1).cell).is_equal(Vector2i(1, 1))


func test_two_units_sharing_an_id_cannot_walk_through_each_other() -> void:
	# They could, and they stacked on one cell: the occupancy rule exempted
	# "the same unit" by comparing ids rather than identity.
	var graph := GridGraph.new(6, 3)
	var twins: Array[Unit] = [
		Unit.new(1, RED, Vector2i(1, 1)),
		Unit.new(1, RED, Vector2i(3, 1)),
	]
	var state := BoardState.new(graph, twins, RED)

	assert_str(state.why_refused(Move.new(1, _walk_east(Vector2i(1, 1), 2)))).contains(
		"occupied"
	)


func test_a_cheap_cell_cannot_refund_movement() -> void:
	var state: BoardState = _two_unit_board()
	state.graph.set_cost(Vector2i(2, 1), -5)
	var before: int = state.unit_by_id(1).movement_points

	var next: BoardState = state.apply(Move.new(1, _walk_east(Vector2i(1, 1), 1)))

	assert_int(next.unit_by_id(1).movement_points).is_less(before)


func test_neither_faction_may_move_out_of_turn() -> void:
	# Only one direction was tested, so the faction check could be loosened
	# from "not equal" to "greater than" with the suite still green.
	var red_to_move: BoardState = _two_unit_board()
	var blue_to_move: BoardState = red_to_move.end_turn()

	assert_str(red_to_move.why_refused(Move.new(2, _walk_east(Vector2i(4, 1), 1)))).contains(
		"faction"
	)
	assert_str(blue_to_move.why_refused(Move.new(1, _walk_east(Vector2i(1, 1), 1)))).contains(
		"faction"
	)


func test_the_route_is_judged_before_the_bill() -> void:
	# A move that is both impossible and unaffordable reports the wall, not the
	# price: "there is a wall there" is what a player can act on. Which of the
	# two wins was a consequence of statement order and nothing held it.
	var state: BoardState = _two_unit_board()
	state.graph.block(Vector2i(2, 1))
	var far: Array[Vector2i] = [
		Vector2i(2, 1), Vector2i(3, 1), Vector2i(3, 0), Vector2i(2, 0),
	]

	assert_str(state.why_refused(Move.new(1, far))).contains("blocked")


func test_a_cell_two_units_were_built_on_answers_with_the_first() -> void:
	# They cannot get there legally, but a caller can build it, and which unit
	# this returns decides what a refusal says.
	var stacked: Array[Unit] = [
		Unit.new(7, RED, Vector2i(2, 2)),
		Unit.new(8, BLUE, Vector2i(2, 2)),
	]
	var state := BoardState.new(GridGraph.new(5, 5), stacked, RED)

	assert_int(state.unit_at(Vector2i(2, 2)).id).is_equal(7)


func test_a_copy_keeps_a_units_health() -> void:
	# duplicate_unit's health argument was passed and never checked, and the
	# dead are dropped before any copy happens, so nothing exercised it.
	var wounded: Array[Unit] = [Unit.new(1, RED, Vector2i(1, 1), 4)]
	var state := BoardState.new(GridGraph.new(4, 4), wounded, RED)

	assert_int(state.unit_by_id(1).health).is_equal(4)
	assert_int(state.end_turn().unit_by_id(1).health).is_equal(4)


func test_a_nonsense_faction_count_still_lands_on_a_real_faction() -> void:
	var after: BoardState = _two_unit_board().end_turn(-2)

	assert_int(after.current_faction).is_equal(0)
	assert_bool(after.current_faction >= 0).is_true()


# A 6x3 board of flat ground, red's unit 1 at (1, 1) and blue's unit 2 at (4, 1).
func test_a_unit_walks_on_its_own_type_s_cost_map() -> void:
	# T10: a cell blocked on the board can be open to one mover. The first
	# version checked the step against the board's map and the bill against
	# the unit's, so a boat paid for the water and was refused it anyway.
	var board := GridGraph.new(3, 1)
	board.block(Vector2i(1, 0))
	var open := GridGraph.new(3, 1)
	var boat := UnitType.new("boat", 3, 1, 1, 1)
	boat.mover = "water"
	var state := BoardState.new(board, [Unit.new(1, RED, Vector2i.ZERO, 10, 3, boat)] as Array[Unit])
	state.movement_graphs = {"water": open}
	var into_the_water := Move.new(1, [Vector2i(1, 0)] as Array[Vector2i])

	assert_str(state.why_refused(into_the_water)).is_equal(BoardState.LEGAL)
	assert_object(state.duplicate_state().graph_for(state.units[0])).is_same(open)


func test_an_untyped_unit_walks_on_the_board() -> void:
	var state: BoardState = _two_unit_board()
	state.movement_graphs = {"water": GridGraph.new(1, 1)}

	assert_object(state.graph_for(state.units[0])).is_same(state.graph)


func test_a_typed_unit_gets_its_type_s_movement_each_turn() -> void:
	var fast := UnitType.new("fast", 6, 1, 1, 1)
	var state := BoardState.new(GridGraph.new(4, 4), [Unit.new(1, BLUE, Vector2i.ZERO, 10, 0, fast)] as Array[Unit])

	assert_int(state.end_turn(2, 3).unit_by_id(1).movement_points).is_equal(6)


func test_income_goes_to_the_side_about_to_move() -> void:
	var state: BoardState = _two_unit_board()

	var after: BoardState = state.end_turn(2, 3, 5)

	assert_int(after.funds_of(BLUE)).is_equal(5)
	assert_int(after.funds_of(RED)).is_equal(0)
	assert_int(state.funds_of(BLUE)).is_equal(0)


func test_buying_leaves_the_state_it_was_bought_on_untouched() -> void:
	# The promise `apply` makes, kept by the two new ways a state changes.
	var state: BoardState = _two_unit_board()
	state.funds[RED] = 10

	var bought: BoardState = state.buy(Upgrade.new("forge", 4))

	assert_int(state.funds_of(RED)).is_equal(10)
	assert_bool(state.owns(RED, "forge")).is_false()
	assert_int(bought.funds_of(RED)).is_equal(6)
	assert_str(bought.why_upgrade_refused(Upgrade.new("forge", 4))).contains("already owns")


func test_a_new_unit_gets_an_id_nobody_else_has() -> void:
	var maker := UnitType.new("maker", 0, 0, 1, 0, false)
	var soldier := UnitType.new("soldier", 3, 1, 1, 1)
	maker.produces.assign(["soldier"])
	var units: Array[Unit] = [Unit.new(7, RED, Vector2i(1, 1), 10, 0, maker), Unit.new(3, RED, Vector2i(3, 3))]
	var state := BoardState.new(GridGraph.new(4, 4), units)
	state.funds[RED] = 1

	var built: BoardState = state.produce(ProductionOrder.new(7, soldier, Vector2i(1, 2)))

	assert_int(built.unit_at(Vector2i(1, 2)).id).is_equal(8)


func test_an_order_is_refused_off_the_producer_s_side() -> void:
	var maker := UnitType.new("maker", 0, 0, 1, 0, false)
	var soldier := UnitType.new("soldier", 3, 1, 1, 0)
	maker.produces.assign(["soldier"])
	var state := BoardState.new(GridGraph.new(4, 4), [Unit.new(1, RED, Vector2i(1, 1), 10, 0, maker)] as Array[Unit])

	assert_str(state.why_production_refused(ProductionOrder.new(1, soldier, Vector2i(3, 3)))).contains("not next to")


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
