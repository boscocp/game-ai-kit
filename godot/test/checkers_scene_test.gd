# The playable half of T27: the scene comes up, a click picks up a piece and
# lights its moves, a refused move says why, and the computer shows its
# decision before it plays it.
#
# Clicks go through `click_square`, which is what the mouse handler calls,
# because gdUnit4 under --headless does not deliver input events. Whether a
# person can read the screen is the task's manual check.
extends GdUnitTestSuite


func test_the_game_opens_with_red_to_move_and_says_what_to_do() -> void:
	var scene: CheckersExample = _mounted()

	assert_str(_status(scene)).contains("your move: click a red piece")
	assert_dict(scene.decision_overlay()).is_empty()


func test_clicking_a_piece_lights_the_squares_it_can_reach() -> void:
	var scene: CheckersExample = _mounted()

	scene.click_square(Vector2i(2, 5))

	assert_array(scene._marks()["targets"]).contains_exactly([Vector2i(1, 4), Vector2i(3, 4)])


func test_a_move_that_is_not_allowed_is_refused_with_the_reason() -> void:
	var scene: CheckersExample = _mounted()

	scene.click_square(Vector2i(2, 5))
	scene.click_square(Vector2i(2, 4))

	assert_int(scene._board.to_move).is_equal(CheckersBoard.RED)
	assert_str(_status(scene)).contains("pieces move only to an empty dark square")


func test_after_your_move_the_computer_shows_its_decision_and_waits() -> void:
	var scene: CheckersExample = _mounted()

	scene.click_square(Vector2i(2, 5))
	scene.click_square(Vector2i(3, 4))

	var overlay: Dictionary = scene.decision_overlay()
	assert_bool(overlay["pending"]).is_true()
	assert_int((overlay["moves"] as Array).size()).is_equal(7)
	assert_int(scene._board.to_move).is_equal(CheckersBoard.WHITE)
	assert_str(_status(scene)).contains("space plays it")
	assert_str(_panel(scene)).contains("WHITE IS ABOUT TO MOVE")
	assert_str(_panel(scene)).contains(overlay["chosen"])


func test_stepping_plays_the_move_on_show_and_hands_the_turn_back() -> void:
	var scene: CheckersExample = _mounted()
	scene.click_square(Vector2i(2, 5))
	scene.click_square(Vector2i(3, 4))
	var chosen: String = scene.decision_overlay()["chosen"]

	scene.step_decision()

	assert_int(scene._board.to_move).is_equal(CheckersBoard.RED)
	assert_str(scene._last.notation()).is_equal(chosen)
	assert_bool(scene.decision_overlay()["pending"]).is_false()


func test_a_compulsory_capture_rings_the_pieces_that_can_take() -> void:
	var scene: CheckersExample = _mounted()
	scene._board = CheckersBoard.from_rows([
		". . . . . . . .", ". . . . . . . .", ". . . . . . . .", ". . w . . . . .",
		". . . r . . . .", ". . . . . . r .", ". . . . . . . .", ". . . . . . . .",
	] as Array[String], CheckersBoard.RED)
	scene._refresh()

	assert_array(scene._marks()["must_capture"]).contains_exactly([Vector2i(3, 4)])
	assert_str(_status(scene)).contains("you must capture")
	scene.click_square(Vector2i(6, 5))
	assert_str(_status(scene)).contains("compulsory")


func test_a_new_depth_searches_the_same_position_again() -> void:
	var scene: CheckersExample = _mounted()
	scene.click_square(Vector2i(2, 5))
	scene.click_square(Vector2i(3, 4))
	var at_four: int = scene.decision_overlay()["positions"]

	scene.set_depth(2)

	assert_int(scene.decision_overlay()["depth"]).is_equal(2)
	assert_int(scene.decision_overlay()["positions"]).is_less(at_four)
	assert_bool(scene.decision_overlay()["pending"]).is_true()


func _mounted() -> CheckersExample:
	var scene: CheckersExample = auto_free(load("res://game/checkers/checkers.tscn").instantiate())
	add_child(scene)
	return scene


func _status(scene: CheckersExample) -> String:
	return (scene.get_node("Interface/Status") as Label).text


func _panel(scene: CheckersExample) -> String:
	return (scene.get_node("Interface/Decision") as Label).text
