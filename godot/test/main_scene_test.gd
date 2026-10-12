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
		main._end_turn()
		main._end_turn()

	main._click_cell(Vector2i(6, 4))

	assert_str(_status_of(main)).contains("blocked")


func test_ending_the_turn_hands_the_board_to_the_other_side() -> void:
	var main: BoardGame = _mounted_scene()

	main._end_turn()

	assert_str(_status_of(main)).contains("blue to move")
	assert_str(_status_of(main)).contains("turn 1")


func _mounted_scene() -> BoardGame:
	var scene: PackedScene = load("res://game/main.tscn")
	var main: BoardGame = scene.instantiate()
	add_child(main)
	return auto_free(main)


func _status_of(main: BoardGame) -> String:
	var label: Label = main.get_node("Interface/Status")
	return label.text
