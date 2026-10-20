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
	# Refused, so not picked up: no yellow ring on a piece that cannot move.
	assert_bool(scene._marks().has("selected")).is_false()


func test_a_multi_jump_can_be_played_one_hop_at_a_time() -> void:
	var scene: CheckersExample = _mounted()
	scene._board = CheckersBoard.from_rows([
		". . . . . . . .", ". . . . . . . .", ". . . . . . . .", ". . . . w . . .",
		". . . . . . . .", ". . w . . . . .", ". r . . . . . .", ". . . . . . . .",
	] as Array[String], CheckersBoard.RED)
	scene._refresh()

	scene.click_square(Vector2i(1, 6))
	assert_array(scene._marks()["targets"]).contains_exactly([Vector2i(3, 4)])
	scene.click_square(Vector2i(3, 4))
	assert_int(scene._board.to_move).is_equal(CheckersBoard.RED)
	assert_array(scene._marks()["targets"]).contains_exactly([Vector2i(5, 2)])
	scene.click_square(Vector2i(0, 0))
	assert_str(_status(scene)).contains("the jump is not finished")
	scene.click_square(Vector2i(5, 2))
	assert_str(scene._last.notation()).is_equal("b2xd4xf6")


func test_either_of_two_jumps_to_the_same_square_can_be_chosen() -> void:
	# e1xc3xe5 and e1xg3xe5 both end on e5. Clicking e5 straight away plays
	# the first; going by c3 or by g3 is how a person chooses -- the rules'
	# free choice among captures, which a click on the last square alone took
	# away.
	for via: Vector2i in [Vector2i(2, 5), Vector2i(6, 5)]:
		var scene: CheckersExample = _mounted()
		scene._board = CheckersBoard.from_rows([
			". . . . . . . .", ". . . . . . . .", ". . . . . . . .", ". . . . . . . .",
			". . . w . w . .", ". . . . . . . .", ". . . w . w . .", ". . . . r . . .",
		] as Array[String], CheckersBoard.RED)
		scene._refresh()

		scene.click_square(Vector2i(4, 7))
		scene.click_square(via)
		scene.click_square(Vector2i(4, 3))

		assert_object(scene._last).is_not_null()
		assert_bool(scene._last.path.has(via)).is_true()


func test_a_king_s_capture_back_to_its_own_square_can_be_played() -> void:
	# The review found this locked the game: the last click lands on the
	# king's own square, which used to pick the king up again.
	var scene: CheckersExample = _mounted()
	scene._board = CheckersBoard.from_rows([
		". . . . . . . .", ". . . . . . . .", ". . . . . . . .", ". . w . w . . .",
		". R . . . . . .", ". . w . w . . .", ". . . . . . . .", ". . . . . . W .",
	] as Array[String], CheckersBoard.RED)
	scene._refresh()

	scene.click_square(Vector2i(1, 4))
	scene.click_square(Vector2i(1, 4))
	assert_object(scene._last).is_null()
	for hop: Vector2i in [Vector2i(3, 2), Vector2i(5, 4), Vector2i(3, 6), Vector2i(1, 4)]:
		scene.click_square(hop)

	assert_str(scene._last.notation()).is_equal("b4xd6xf4xd2xb4")
	assert_int(scene._board.squares_of(CheckersBoard.WHITE).size()).is_equal(1)


func test_a_bound_at_a_win_is_not_written_as_a_win() -> void:
	# After a winning move, alpha is a win, and a later move cut short comes
	# back as "at most a win" -- which says nothing about it.
	assert_str(CheckersView.value_words(CheckersGame.WIN, true)).is_equal("wins")
	assert_str(CheckersView.value_words(CheckersGame.WIN, false)).starts_with("≤")


func test_a_click_on_white_or_on_nothing_says_what_to_click_instead() -> void:
	var scene: CheckersExample = _mounted()

	scene.click_square(Vector2i(1, 0))
	assert_str(_status(scene)).contains("one of white's pieces")
	scene.click_square(Vector2i(3, 4))
	assert_str(_status(scene)).contains("click one of your red pieces first")


func test_the_panel_spells_out_the_line_white_expects() -> void:
	var scene: CheckersExample = _mounted()
	scene.click_square(Vector2i(2, 5))
	scene.click_square(Vector2i(3, 4))

	var expects: Array = scene.decision_overlay()["expects"]
	assert_int(expects.size()).is_equal(scene.depth)
	assert_str(expects[0]).is_equal(scene.decision_overlay()["chosen"])
	assert_str(_panel(scene)).contains("the line it expects")
	assert_str(_panel(scene)).contains("red " + str(expects[1]))


func test_a_value_a_hair_below_zero_is_not_written_as_minus_zero() -> void:
	assert_str(CheckersView.value_words(-0.0000001, true)).is_equal("+0.00")
	assert_str(CheckersView.value_words(-0.05, false)).is_equal("≤ -0.05")


func test_a_new_depth_searches_the_same_position_again() -> void:
	var scene: CheckersExample = _mounted()
	scene.click_square(Vector2i(2, 5))
	scene.click_square(Vector2i(3, 4))
	var at_four: int = scene.decision_overlay()["positions"]

	scene.set_depth(2)

	assert_int(scene.decision_overlay()["depth"]).is_equal(2)
	assert_int(scene.decision_overlay()["positions"]).is_less(at_four)
	assert_bool(scene.decision_overlay()["pending"]).is_true()


func test_the_panel_fits_its_box_with_many_moves_a_deep_line_and_every_footnote() -> void:
	# The play review found the footnote under the status bar, and off the
	# window with ten moves listed. Four white kings in the open, at depth 6.
	var scene: CheckersExample = _mounted()
	scene.depth = 6
	scene._board = CheckersBoard.from_rows([
		". . . . . . . .", ". . W . . . W .", ". . . . . . . .", ". . W . . . W .",
		". . . . . . . .", ". . . . . . . .", ". r . r . r . .", "r . . . . . . .",
	] as Array[String], CheckersBoard.WHITE)
	scene._think()
	scene._refresh()

	var panel: Label = scene.get_node("Interface/Decision")
	assert_int(scene.decision_overlay()["moves"].size()).is_greater(CheckersPanel.MOST_MOVES_LISTED)
	var status: Label = scene.get_node("Interface/Status")
	# Measured against the status line below it, not against the label's own
	# size: a Label grows to fit its text, so that comparison always passes.
	assert_float(_bottom_of(panel)).is_less_equal(status.position.y)
	scene._message = "a capture is compulsory, and this piece cannot capture: the ringed pieces can"
	scene._refresh()
	assert_float(_bottom_of(status)).is_less_equal(720.0)


# Where a label's text actually ends: its top, plus a line height per line.
func _bottom_of(label: Label) -> float:
	return label.position.y + float(label.get_line_count() * label.get_line_height())


func _mounted() -> CheckersExample:
	var scene: CheckersExample = auto_free(load("res://game/checkers/checkers.tscn").instantiate())
	add_child(scene)
	return scene


func _status(scene: CheckersExample) -> String:
	return (scene.get_node("Interface/Status") as Label).text


func _panel(scene: CheckersExample) -> String:
	return (scene.get_node("Interface/Decision") as Label).text
