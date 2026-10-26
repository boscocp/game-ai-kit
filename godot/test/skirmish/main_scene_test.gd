# The playable half of T2, which had no automated check at all.
#
# project_settings_test.gd asserted that the string `res://game/main.tscn`
# appears in project.godot -- which a scene that cannot instantiate passes
# perfectly well. These tests load the scene, put it in the tree, and click on
# it, so that main.gd and unit_view.gd stop resting entirely on a person
# remembering to look.
#
# What a person still has to judge is whether the board is *legible*. That is
# the `## Manual check` in T2 and no test here replaces it.
extends GdUnitTestSuite


# These tests read the English words. The engine starts in the system's
# locale, so on a Portuguese system they would read the pt-BR ones (T79);
# the Portuguese screen is test/locale's. The locale found is put back.
var _locale_before: String


func before() -> void:
	_locale_before = TranslationServer.get_locale()
	TranslationServer.set_locale("en")


func after() -> void:
	TranslationServer.set_locale(_locale_before)


func test_the_scene_comes_up_with_a_board_and_a_side_to_move() -> void:
	var main: BoardGame = _mounted_scene()
	var board: BoardView = main.get_node("BoardView")

	assert_str(_status_of(main)).contains("red to move")
	assert_int(board.get_used_cells().size()).is_equal(main.COLUMNS * main.ROWS)


func test_a_side_starts_its_turn_with_one_of_its_units_in_hand() -> void:
	# So the first click of a turn does something, rather than teaching the
	# player that nothing was selected.
	var main: BoardGame = _mounted_scene()

	assert_str(_status_of(main)).contains("movement left: %d" % main.POINTS_PER_TURN)


func test_the_status_says_what_is_in_hand_what_is_left_and_what_to_do() -> void:
	# T8: the owner ran the board and could not tell what to do with it. A
	# first-time player needs the unit, the movement left, and a sentence.
	var main: BoardGame = _mounted_scene()

	assert_str(_status_of(main)).contains("unit 1 in hand")
	assert_str(_status_of(main)).contains("movement left: %d" % main.POINTS_PER_TURN)
	assert_str(_status_of(main)).contains("click one of your units, then a highlighted cell")


func test_on_blue_s_turn_the_status_says_which_unit_decides_and_what_space_does() -> void:
	var main: BoardGame = _mounted_scene()

	main._end_turn()

	assert_str(_status_of(main)).contains("blue's unit %d is deciding" % main._plan.unit_id)
	assert_str(_status_of(main)).contains("space plays the move")


func test_on_blue_s_turn_nothing_of_blue_s_is_marked_as_yours() -> void:
	# The ring and the reachable tint mean "the unit in hand", and blue's turn
	# used to show them on its first unit while the status named the second.
	var main: BoardGame = _mounted_scene()
	var board: BoardView = main.get_node("BoardView")
	main._end_turn()
	main.step_decision()

	assert_int(main._selected_id).is_equal(-1)
	assert_array(board.marks()["reachable"]).is_empty()
	assert_str(_status_of(main)).contains("blue's unit %d is deciding" % main._plan.unit_id)


func test_a_spent_unit_is_not_told_to_click_a_highlighted_cell() -> void:
	var main: BoardGame = _mounted_scene()
	# North up column 1 is open ground all the way: one point a step.
	for row: int in range(3, 3 - main.POINTS_PER_TURN, -1):
		main._click_cell(Vector2i(1, row))

	assert_str(_status_of(main)).contains("movement left: 0")
	assert_str(_status_of(main)).contains("cannot step anywhere")
	assert_str(_status_of(main)).not_contains("then a highlighted cell")


func test_the_status_and_legend_sit_beside_the_board_inside_the_window() -> void:
	# T8 measured the status 600 px from the board it described.
	var main: BoardGame = _mounted_scene()
	var window := Rect2(Vector2.ZERO, Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height")))
	var board := Rect2(main.position, BoardView.pixel_size(main._state.graph))

	for name: String in ["Interface/Status", "Interface/Legend"]:
		var panel: Rect2 = (main.get_node(name) as Control).get_rect()
		assert_bool(window.encloses(panel)).override_failure_message(name + " leaves the window").is_true()
		assert_bool(panel.intersects(board)).override_failure_message(name + " covers the board").is_false()
		assert_float(panel.position.y).is_equal(board.position.y)


func test_clicking_a_neighbouring_cell_moves_and_spends_a_point() -> void:
	var main: BoardGame = _mounted_scene()

	main._click_cell(Vector2i(2, 4))

	assert_str(_status_of(main)).contains("movement left: %d" % (main.POINTS_PER_TURN - 1))


func test_clicking_far_away_says_why_instead_of_blaming_diagonals() -> void:
	# The refusal used to read "a step is one cell, no diagonals", which is
	# true of the move the scene built and is not the reason it failed.
	var main: BoardGame = _mounted_scene()

	main._click_cell(Vector2i(9, 7))

	assert_str(_status_of(main)).contains("more than one step away")


func test_a_click_into_the_wall_is_refused_in_the_wall_s_own_words() -> void:
	var main: BoardGame = _mounted_scene()
	# Walk east to meet the wall this scenario builds down column 6.
	for column: int in range(2, 6):
		main._click_cell(Vector2i(column, 4))
		_play_rounds(main, 2)

	main._click_cell(Vector2i(6, 4))

	assert_str(_status_of(main)).contains("blocked")


func test_ending_the_turn_shows_blue_s_first_decision_before_playing_it() -> void:
	# Invariant 13: what the AI is about to do, before it does it. The first
	# version played blue's whole turn on one press, so no frame ever showed a
	# decision that had not already happened.
	var main: BoardGame = _mounted_scene()
	var before: Vector2i = main._state.unit_by_id(3).cell

	main._end_turn()

	assert_str(_status_of(main)).contains("next, not yet played")
	assert_object(main._plan).is_not_null()
	assert_vector(main._state.unit_by_id(3).cell).is_equal(before)


func test_each_press_plays_one_decision_and_shows_the_next() -> void:
	var main: BoardGame = _mounted_scene()
	main._end_turn()
	var first: int = main._plan.unit_id

	main.step_decision()

	assert_int(main._played.size()).is_equal(1)
	assert_int(main._played[0].unit_id).is_equal(first)
	assert_int(main._plan.unit_id).is_not_equal(first)


func test_after_blue_s_last_move_the_board_comes_back() -> void:
	var main: BoardGame = _mounted_scene()

	_play_rounds(main, 1)

	assert_str(_status_of(main)).contains("red to move")
	assert_str(_status_of(main)).contains("turn 2")
	assert_object(main._plan).is_null()


func test_the_player_cannot_click_while_blue_is_deciding() -> void:
	var main: BoardGame = _mounted_scene()
	main._end_turn()
	var planned: LearnedDecision = main._plan

	main._click_cell(main._state.unit_by_id(main._plan.unit_id).cell + Vector2i.LEFT)

	assert_object(main._plan).is_same(planned)
	assert_str(_status_of(main)).contains("blue is deciding")


func test_the_ai_says_what_it_decided_and_the_number_it_decided_on() -> void:
	# Invariant 13: the screen shows the decision, not only its result. A
	# retreat with no probability beside it is indistinguishable from a unit
	# that had nowhere to go.
	var main: BoardGame = _mounted_scene()

	_play_rounds(main, 1)

	assert_str(_status_of(main)).contains("p(win)")
	assert_str(_status_of(main)).contains("retreats from")


func test_the_ai_actually_moves_its_units() -> void:
	var main: BoardGame = _mounted_scene()
	var before: Vector2i = main._state.unit_by_id(4).cell

	_play_rounds(main, 1)

	assert_vector(main._state.unit_by_id(4).cell).is_not_equal(before)


func test_the_player_cannot_move_the_ai_s_units() -> void:
	# The board already refuses it; this is here because the AI side is now
	# played by code and nothing else asserts that the mouse stays off it.
	var main: BoardGame = _mounted_scene()

	main._click_cell(main._state.unit_by_id(3).cell)

	assert_int(main._selected_id).is_not_equal(3)


# Press space until red is to move again, `rounds` times over.
func _play_rounds(main: BoardGame, rounds: int) -> void:
	for _round: int in range(rounds):
		main.step_decision()
		while main._state.current_faction == BoardGame.AI_FACTION:
			main.step_decision()


# T33: the skirmish board's soldiers walk too, red's step and blue's move.
func test_a_red_step_is_walked() -> void:
	var main: BoardGame = _mounted_scene()
	var view: UnitView = main.get_node("UnitView")
	var board: BoardView = main.get_node("BoardView")
	view.set_process(false)
	var unit: Unit = main._state.unit_by_id(main._selected_id)
	var start: Vector2i = unit.cell
	main._click_cell(Vector2i(2, 4))

	view.advance(UnitWalk.SECONDS_PER_CELL / 2.0)

	var halfway: Vector2 = board.centre_of(start).lerp(board.centre_of(Vector2i(2, 4)), 0.5)
	assert_vector(view.position_of(main._state.unit_by_id(unit.id))).is_equal_approx(halfway, Vector2(0.01, 0.01))


func test_a_blue_move_is_walked() -> void:
	var main: BoardGame = _mounted_scene()
	var view: UnitView = main.get_node("UnitView")
	view.set_process(false)
	main._end_turn()
	var deciding: int = main._plan.unit_id

	main.step_decision()

	assert_bool(view.is_walking(deciding)).is_true()


func _mounted_scene() -> BoardGame:
	var scene: PackedScene = load("res://game/main.tscn")
	var main: BoardGame = scene.instantiate()
	add_child(main)
	return auto_free(main)


func _status_of(main: BoardGame) -> String:
	var label: Label = main.get_node("Interface/Status")
	return label.text
