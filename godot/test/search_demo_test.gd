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


func test_the_status_says_breadth_first_never_looks_at_cost() -> void:
	# T41: the owner read breadth-first's route through the mud as Dijkstra's.
	var demo: SearchDemo = _mounted_demo()

	assert_str(_status_of(demo)).contains("breadth-first (fewest steps, blind to what a cell costs)")
	demo.choose_search(DIJKSTRA)
	assert_str(_status_of(demo)).contains("dijkstra (the cheapest route)")


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
		var result: SearchResult = results[index]
		var count: String = "%s %d cells, cost %d" % [SearchDemo.NAMES[index], result.expanded.size(), result.cost]
		assert_str(_status_of(demo)).contains(count)


# --- T29: a board you can edit ---------------------------------------------

const WALL_AND_MUD: int = 0
const MAZE: int = 1
const OPEN_FIELD: int = 2
const DEPTH_FIRST_TRAP: int = 3

# The only gap in the wall-and-mud board's wall, at its foot.
const GAP: Array[Vector2i] = [Vector2i(8, 9), Vector2i(8, 10)]


func test_walling_the_only_gap_makes_every_search_report_no_route() -> void:
	var demo: SearchDemo = _mounted_demo()
	demo.choose_brush(SearchDemo.Brush.WALL)

	for cell: Vector2i in GAP:
		demo.paint(cell)

	for index: int in range(4):
		demo.choose_search(index)
		assert_bool(demo._result.reached).is_false()
		# A result, not a crash: the work is still there to look at.
		assert_array(demo._result.expanded).is_not_empty()
	assert_str(_status_of(demo)).contains("no route")
	assert_int(demo.expansion_counts().count("no route")).is_equal(4)


func test_no_route_finishes_with_a_route_field_that_says_so() -> void:
	var demo: SearchDemo = _mounted_demo()
	for cell: Vector2i in GAP:
		demo.paint(cell)

	demo.step(100000)

	assert_str(str(demo.decision_overlay()["route"])).contains("no route")


func test_one_open_cell_in_the_gap_is_enough_for_a_route() -> void:
	# The other half of the case above: walling one cell of two must not cut
	# the board, or "no route" could be coming from somewhere else.
	var demo: SearchDemo = _mounted_demo()
	demo.paint(GAP[0])

	assert_bool(demo._result.reached).is_true()


func test_moving_the_goal_searches_again() -> void:
	var demo: SearchDemo = _mounted_demo()
	demo.choose_search(ASTAR)
	demo.step(4)
	var before: SearchResult = demo._result
	var new_goal := Vector2i(2, 2)

	assert_bool(demo.move_goal(new_goal)).is_true()

	assert_object(demo._result).is_not_same(before)
	assert_that(demo._result.path.back()).is_equal(new_goal)
	assert_str(_status_of(demo)).contains("a*")
	assert_str(_status_of(demo)).contains("expanded 0 of")


func test_moving_the_start_searches_again_from_there() -> void:
	var demo: SearchDemo = _mounted_demo()
	var new_start := Vector2i(12, 2)

	assert_bool(demo.move_start(new_start)).is_true()

	assert_that(demo._result.expanded[0]).is_equal(new_start)


func test_the_start_and_the_goal_only_go_to_open_cells() -> void:
	var demo: SearchDemo = _mounted_demo()
	var goal: Vector2i = demo._to

	assert_bool(demo.move_goal(Vector2i(8, 0))).is_false()   # a wall
	assert_bool(demo.move_goal(Vector2i(-1, 3))).is_false()  # off the board
	assert_bool(demo.move_goal(demo._from)).is_false()       # the start
	assert_that(demo._to).is_equal(goal)
	var start: Vector2i = demo._from
	assert_bool(demo.move_start(demo._to)).is_false()       # the goal
	assert_bool(demo.move_start(Vector2i(8, 0))).is_false()  # a wall
	assert_that(demo._from).is_equal(start)


func test_the_start_and_the_goal_are_never_painted_over() -> void:
	var demo: SearchDemo = _mounted_demo()

	demo.paint(demo._from)
	demo.paint(demo._to)

	assert_bool(demo._graph.is_blocked(demo._from)).is_false()
	assert_bool(demo._graph.is_blocked(demo._to)).is_false()


func test_erasing_a_painted_cell_makes_it_open_ground() -> void:
	var demo: SearchDemo = _mounted_demo()
	var cell := Vector2i(3, 2)
	demo.choose_brush(SearchDemo.Brush.WALL)
	demo.paint(cell)
	assert_bool(demo._graph.is_blocked(cell)).is_true()

	demo.erase(cell)

	assert_int(demo._graph.cost_at(cell)).is_equal(GridGraph.DEFAULT_COST)


func test_erasing_mud_makes_it_open_ground_too() -> void:
	var demo: SearchDemo = _mounted_demo()
	var mud := Vector2i(3, 5)
	assert_int(demo._graph.cost_at(mud)).is_equal(SearchDemo.MUD)

	demo.erase(mud)

	assert_int(demo._graph.cost_at(mud)).is_equal(GridGraph.DEFAULT_COST)


func test_painting_mud_uses_the_price_chosen_for_it() -> void:
	var demo: SearchDemo = _mounted_demo()
	var cell := Vector2i(3, 2)
	demo.choose_brush(SearchDemo.Brush.MUD)
	demo.change_mud_cost(-3)

	demo.paint(cell)

	assert_int(demo._graph.cost_at(cell)).is_equal(SearchDemo.MUD - 3)


func test_changing_the_price_of_mud_changes_the_mud_on_the_board() -> void:
	# Breadth-first ignores cost, so it wades the same mud at any price, and
	# what its route costs falls with the price. Dijkstra still goes round:
	# the wall forces a detour either way, so at 2 the mud is still dearer.
	var demo: SearchDemo = _mounted_demo()
	var dear: int = demo._all[BREADTH_FIRST].cost

	demo.change_mud_cost(-100)

	assert_int(demo._graph.cost_at(Vector2i(3, 5))).is_equal(SearchDemo.CHEAPEST_MUD)
	assert_int(demo._all[BREADTH_FIRST].cost).is_less(dear)
	assert_str(demo.board_name()).is_equal("wall and mud, edited")
	assert_bool(demo.promise_holds()).is_true()


func test_an_edit_that_takes_the_lesson_away_is_said_on_screen() -> void:
	# With the band erased, and the wall cell in it, breadth-first walks the
	# straight line Dijkstra walks too, at the same price, and
	# the board no longer shows what it was chosen for.
	var demo: SearchDemo = _mounted_demo()

	for column: int in range(demo._graph.width):
		demo.erase(Vector2i(column, 5))

	assert_bool(demo.promise_holds()).is_false()
	assert_str(_status_of(demo)).contains("not any more")


func test_the_price_of_mud_stays_a_single_digit() -> void:
	var demo: SearchDemo = _mounted_demo()

	demo.change_mud_cost(100)

	assert_int(demo._graph.cost_at(Vector2i(3, 5))).is_equal(SearchDemo.DEAREST_MUD)


func test_every_named_board_keeps_its_promise() -> void:
	var demo: SearchDemo = _mounted_demo()
	var boards: Array[SearchBoard] = SearchBoard.named()
	assert_int(boards.size()).is_equal(4)

	for index: int in range(boards.size()):
		demo.load_board(index)
		assert_str(demo.board_name()).is_equal(boards[index].name)
		assert_bool(demo.promise_holds()).override_failure_message(
			"%s does not show what it promises: %s" % [boards[index].name, demo.expansion_counts()]
		).is_true()


func test_each_promise_fails_on_a_board_that_does_not_keep_it() -> void:
	# A check that always says yes would pass the test above on any layout.
	# Each one is shown another board's results, where its claim is false.
	var boards: Array[SearchBoard] = SearchBoard.named()
	var wrong_board: Dictionary = {
		WALL_AND_MUD: OPEN_FIELD,   # nothing to go round: every cost is 13
		MAZE: WALL_AND_MUD,         # the four routes cost different amounts
		OPEN_FIELD: MAZE,           # in a corridor A* saves little
		# Depth-first pays more here too (51 against 13), but sweeps no more of
		# the board than Dijkstra: dear, and no trap.
		DEPTH_FIRST_TRAP: OPEN_FIELD,
	}
	for index: int in wrong_board:
		var results: Array[SearchResult] = _results_on(boards[wrong_board[index]])
		assert_bool(boards[index].promise_holds(results)).override_failure_message(
			"%s's promise held on %s" % [boards[index].name, boards[wrong_board[index]].name]
		).is_false()


func test_the_layout_characters_mean_what_the_header_says() -> void:
	assert_int(SearchBoard.cost_of("#")).is_equal(GridGraph.BLOCKED)
	assert_int(SearchBoard.cost_of(".")).is_equal(GridGraph.DEFAULT_COST)
	assert_int(SearchBoard.cost_of("S")).is_equal(GridGraph.DEFAULT_COST)
	assert_int(SearchBoard.cost_of("G")).is_equal(GridGraph.DEFAULT_COST)
	assert_int(SearchBoard.cost_of("5")).is_equal(5)


func test_an_edited_board_says_so_and_rebuilding_forgets_the_edit() -> void:
	var demo: SearchDemo = _mounted_demo()
	demo.load_board(MAZE)
	demo.erase(Vector2i(1, 1))
	assert_str(demo.board_name()).is_equal("maze, edited")

	demo._handle(KEY_R)

	assert_str(demo.board_name()).is_equal("maze")
	assert_bool(demo._graph.is_blocked(Vector2i(1, 1))).is_true()


func test_b_steps_through_the_boards_and_wraps() -> void:
	var demo: SearchDemo = _mounted_demo()
	for step_count: int in range(4):
		demo._handle(KEY_B)
	assert_str(demo.board_name()).is_equal(SearchBoard.named()[0].name)


func test_clearing_leaves_open_ground_and_the_two_dots() -> void:
	var demo: SearchDemo = _mounted_demo()
	var start: Vector2i = demo._from

	demo.clear_board()

	assert_str(demo.board_name()).is_equal("blank")
	assert_that(demo._from).is_equal(start)
	for row: int in range(demo._graph.height):
		for column: int in range(demo._graph.width):
			assert_int(demo._graph.cost_at(Vector2i(column, row))).is_equal(GridGraph.DEFAULT_COST)
	assert_bool(demo._result.reached).is_true()


func test_the_screen_says_how_to_edit() -> void:
	var demo: SearchDemo = _mounted_demo()
	var help: Label = demo.get_node("Interface/Help")

	assert_str(help.text).contains("left-drag: paint wall")
	demo._handle(KEY_M)
	assert_str(help.text).contains("left-drag: paint mud")
	assert_str(help.text).contains("right-drag")
	assert_str(help.text).contains("drag a dot")


func _results_on(board: SearchBoard) -> Array[SearchResult]:
	var found: Array[SearchResult] = []
	var graph: GridGraph = board.graph()
	for search: Search in [BreadthFirstSearch.new(), DepthFirstSearch.new(),
			DijkstraSearch.new(), AStarSearch.new()]:
		found.append(search.search(graph, board.start(), board.goal()))
	return found


func test_the_numbers_the_concept_page_quotes() -> void:
	# `docs/concepts/search.md` quotes these. A sentence copied from a
	# measurement is only as true as the measurement, so it is taken again here.
	var boards: Array[SearchBoard] = SearchBoard.named()
	var maze: Array[SearchResult] = _results_on(boards[MAZE])
	var field: Array[SearchResult] = _results_on(boards[OPEN_FIELD])
	var trap: Array[SearchResult] = _results_on(boards[DEPTH_FIRST_TRAP])

	assert_int(maze[DIJKSTRA].cost).is_equal(36)
	assert_int(maze[ASTAR].expanded.size()).is_equal(41)
	assert_int(maze[DIJKSTRA].expanded.size()).is_equal(51)
	assert_int(field[ASTAR].expanded.size()).is_equal(14)
	assert_int(field[DIJKSTRA].expanded.size()).is_equal(130)
	assert_int(trap[DEPTH_FIRST].cost).is_equal(40)
	# And the first board's, quoted in the README as well.
	var first: Array[SearchResult] = _results_on(boards[WALL_AND_MUD])
	assert_int(first[BREADTH_FIRST].cost).is_equal(98)
	assert_int(first[DIJKSTRA].cost).is_equal(21)
	assert_int(first[DIJKSTRA].expanded.size()).is_equal(125)
	assert_int(first[ASTAR].expanded.size()).is_equal(90)



# --- the mouse, driven through `pointer` (wave 28 review) -------------------

const EMPTY := Vector2i(3, 2)


func _press(button: MouseButton, pressed: bool = true) -> InputEventMouseButton:
	var click := InputEventMouseButton.new()
	click.button_index = button
	click.pressed = pressed
	return click


func test_a_left_press_paints_the_brush() -> void:
	var demo: SearchDemo = _mounted_demo()

	demo.pointer(_press(MOUSE_BUTTON_LEFT), EMPTY)

	assert_bool(demo._graph.is_blocked(EMPTY)).is_true()


func test_a_right_press_erases() -> void:
	var demo: SearchDemo = _mounted_demo()
	var mud := Vector2i(3, 5)

	demo.pointer(_press(MOUSE_BUTTON_RIGHT), mud)

	assert_int(demo._graph.cost_at(mud)).is_equal(GridGraph.DEFAULT_COST)


func test_dragging_with_the_button_down_keeps_painting() -> void:
	var demo: SearchDemo = _mounted_demo()
	demo.pointer(_press(MOUSE_BUTTON_LEFT), Vector2i(2, 1))

	demo.pointer(InputEventMouseMotion.new(), Vector2i(2, 2))

	assert_bool(demo._graph.is_blocked(Vector2i(2, 2))).is_true()


func test_a_fast_drag_leaves_no_gap() -> void:
	# A quick stroke reports cells far apart; the wall between them is what
	# the person drew.
	var demo: SearchDemo = _mounted_demo()
	demo.pointer(_press(MOUSE_BUTTON_LEFT), Vector2i(2, 0))

	demo.pointer(InputEventMouseMotion.new(), Vector2i(2, 4))

	for row: int in range(5):
		assert_bool(demo._graph.is_blocked(Vector2i(2, row))).is_true()


func test_letting_go_stops_painting() -> void:
	var demo: SearchDemo = _mounted_demo()
	demo.pointer(_press(MOUSE_BUTTON_LEFT), Vector2i(2, 1))
	demo.pointer(_press(MOUSE_BUTTON_LEFT, false), Vector2i(2, 1))

	demo.pointer(InputEventMouseMotion.new(), Vector2i(4, 1))

	assert_bool(demo._graph.is_blocked(Vector2i(4, 1))).is_false()


func test_a_press_on_the_goal_picks_it_up_and_a_drag_carries_it() -> void:
	var demo: SearchDemo = _mounted_demo()
	var goal: Vector2i = demo._to

	demo.pointer(_press(MOUSE_BUTTON_LEFT), goal)
	demo.pointer(InputEventMouseMotion.new(), Vector2i(12, 2))

	assert_that(demo._to).is_equal(Vector2i(12, 2))
	assert_bool(demo._graph.is_blocked(goal)).is_false()


func test_a_press_on_the_start_picks_it_up() -> void:
	var demo: SearchDemo = _mounted_demo()

	demo.pointer(_press(MOUSE_BUTTON_LEFT), demo._from)
	demo.pointer(InputEventMouseMotion.new(), Vector2i(2, 2))

	assert_that(demo._from).is_equal(Vector2i(2, 2))


# --- the edits the review found unpinned ------------------------------------

func test_the_open_ground_brush_paints_open_ground() -> void:
	var demo: SearchDemo = _mounted_demo()
	var mud := Vector2i(3, 5)
	demo.choose_brush(SearchDemo.Brush.GROUND)

	demo.paint(mud)

	assert_int(demo._graph.cost_at(mud)).is_equal(GridGraph.DEFAULT_COST)


func test_one_press_of_b_goes_to_the_next_board() -> void:
	var demo: SearchDemo = _mounted_demo()

	demo._handle(KEY_B)

	assert_str(demo.board_name()).is_equal("maze")


func test_r_after_clearing_rebuilds_the_board_it_started_from() -> void:
	var demo: SearchDemo = _mounted_demo()
	demo.load_board(OPEN_FIELD)
	demo.clear_board()

	demo._handle(KEY_R)

	assert_str(demo.board_name()).is_equal("open field")


func test_a_new_board_starts_at_the_usual_price_of_mud() -> void:
	var demo: SearchDemo = _mounted_demo()
	demo.change_mud_cost(-3)

	demo._handle(KEY_B)
	demo.choose_brush(SearchDemo.Brush.MUD)
	demo.paint(Vector2i(1, 1))

	assert_int(demo._graph.cost_at(Vector2i(1, 1))).is_equal(SearchDemo.MUD)


func test_moving_either_dot_marks_the_board_edited() -> void:
	var demo: SearchDemo = _mounted_demo()
	demo.move_start(Vector2i(2, 2))
	assert_str(demo.board_name()).is_equal("wall and mud, edited")

	demo.load_board(WALL_AND_MUD)
	demo.move_goal(Vector2i(12, 2))
	assert_str(demo.board_name()).is_equal("wall and mud, edited")


func test_a_price_for_mud_on_a_board_without_mud_edits_nothing() -> void:
	var demo: SearchDemo = _mounted_demo()
	demo.load_board(OPEN_FIELD)

	demo.change_mud_cost(-1)

	assert_str(demo.board_name()).is_equal("open field")


func test_before_any_step_the_frontier_is_the_start() -> void:
	var demo: SearchDemo = _mounted_demo()

	assert_array(demo.frontier_after(0)).contains_exactly([demo._from])
