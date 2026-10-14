# T28 in the engine: the published beads load, MENACE plays by them and never
# changes one, perfect play is perfect, and the scene shows the beads before
# MENACE draws.
#
# Whether a person feels the 10-game machine play worse than the 10,000-game
# one is the task's manual check. That the beads differ, and that MENACE
# plays the bead the draw lands on, is held here.
extends GdUnitTestSuite


func test_the_published_file_holds_four_ages_of_304_boxes() -> void:
	var menace: MenacePlayer = MenacePlayer.load_published()

	assert_array(menace.ages).is_equal([10, 100, 1000, 10000])
	for age: int in menace.ages:
		assert_int((menace._snapshots[age] as Dictionary).size()).is_equal(304)


func test_on_the_empty_board_three_squares_hold_beads_and_the_rest_are_turns_of_them() -> void:
	var menace: MenacePlayer = MenacePlayer.load_published()

	var squares: Array[Dictionary] = menace.squares_for(10, TicTacToeBoard.START)
	var playable: Array = squares.filter(func(entry: Dictionary) -> bool: return not entry.has("same_move_as"))
	assert_int(squares.size()).is_equal(9)
	assert_array(playable.map(func(entry: Dictionary) -> int: return entry["square"])).contains_exactly([0, 1, 4])
	var total: float = 0.0
	for entry: Dictionary in squares:
		total += entry["probability"]
	assert_float(total).is_equal_approx(1.0, 0.000001)


func test_every_turn_of_a_board_folds_into_the_same_box() -> void:
	for board: String in ["X...O....", "XO..X...O", "O.......X", ".X.O.X.O."]:
		var box: String = TicTacToeBoard.canonical(board)[0]
		for symmetry: int in range(8):
			assert_str(TicTacToeBoard.canonical(TicTacToeBoard.turned(board, symmetry))[0]).is_equal(box)


func test_a_square_of_the_box_lands_on_the_square_the_turn_put_there() -> void:
	var board: String = "O.......X"
	var box: String = TicTacToeBoard.canonical(board)[0]
	for square: int in range(9):
		assert_str(box[square]).is_equal(board[TicTacToeBoard.real_square(board, square)])


func test_the_draw_lands_on_the_bead_it_points_at() -> void:
	var counts := PackedInt32Array([4, 4, 0, 0, 4, 0, 0, 0, 0])

	assert_int(MenacePlayer.draw(counts, 0.0)).is_equal(0)
	assert_int(MenacePlayer.draw(counts, 0.34)).is_equal(1)
	assert_int(MenacePlayer.draw(counts, 0.999)).is_equal(4)
	assert_int(MenacePlayer.draw(PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0]), 0.5)).is_equal(-1)


func test_perfect_play_draws_the_empty_board_and_takes_a_win_when_there_is_one() -> void:
	assert_int(TicTacToeSolver.value(TicTacToeBoard.START, TicTacToeBoard.CROSS)).is_equal(TicTacToeSolver.DRAW)
	# Crosses on the top left and top edge, noughts below: the top right wins.
	assert_int(TicTacToeSolver.best_square("XX.OO....")).is_equal(2)
	assert_int(TicTacToeSolver.square_values("XX.OO....")[2]).is_equal(TicTacToeSolver.WIN)


func test_playing_whole_games_changes_no_bead() -> void:
	# Invariant 6 at run time: MENACE draws and draws, and the beads it draws
	# from are what the file said. N5 holds the code; this holds the play.
	var scene: TicTacToeExample = _mounted()
	var before: String = str(scene._menace._snapshots)
	for _step: int in range(60):
		scene.step_decision()

	assert_str(str(scene._menace._snapshots)).is_equal(before)


func test_menace_moves_first_and_its_beads_are_on_show_before_it_draws() -> void:
	var scene: TicTacToeExample = _mounted()

	var overlay: Dictionary = scene.decision_overlay()
	assert_bool(overlay["pending"]).is_true()
	assert_int((overlay["squares"] as Array).size()).is_equal(9)
	assert_str(_status(scene)).contains("space shakes the box")
	assert_str(_panel(scene)).contains("MENACE AFTER 10 GAMES")


func test_menace_plays_the_square_its_draw_lands_on() -> void:
	var scene: TicTacToeExample = _mounted()
	var expected: int = scene._menace.move_for(10, TicTacToeBoard.START, 0.4)

	scene.menace_moves(0.4)

	assert_str(scene._board[expected]).is_equal(TicTacToeBoard.CROSS)
	assert_int(scene.decision_overlay()["chosen"]).is_equal(expected)
	assert_str(_status(scene)).contains("your turn")


func test_a_taken_square_or_the_wrong_turn_is_refused_in_words() -> void:
	var scene: TicTacToeExample = _mounted()
	scene.click_square(4)
	assert_str(_status(scene)).contains("MENACE's turn")

	scene.menace_moves(0.4)
	var taken: int = scene.decision_overlay()["chosen"]
	scene.click_square(taken)
	assert_str(_status(scene)).contains("that square is taken")


func test_an_older_machine_has_different_beads_in_the_same_box() -> void:
	var scene: TicTacToeExample = _mounted()
	var young: Array = scene.decision_overlay()["squares"]

	scene._handle_key(KEY_4)

	assert_int(scene.age()).is_equal(10000)
	assert_str(str(scene.decision_overlay()["squares"])).is_not_equal(str(young))


func test_an_empty_box_resigns_and_says_why() -> void:
	var scene: TicTacToeExample = _mounted()
	scene._menace = MenacePlayer.with_box(TicTacToeBoard.START, [0, 0, 0, 0, 0, 0, 0, 0, 0])
	scene.age_index = 0

	scene.menace_moves(0.5)

	assert_str(scene._board).is_equal(TicTacToeBoard.START)
	assert_str(_status(scene)).contains("MENACE resigns")


func test_m_shows_what_perfect_play_would_take() -> void:
	var scene: TicTacToeExample = _mounted()

	scene._handle_key(KEY_M)

	assert_bool(scene.show_minimax).is_true()
	assert_str(_status(scene)).contains("perfect play on")
	assert_str(_panel(scene)).contains("perfect play would take the top left")


func test_the_panel_ends_above_the_status_line_with_seven_moves_and_a_draw_shown() -> void:
	# The widest the panel gets: seven empty squares, all different, a draw
	# to report and perfect play on.
	var scene: TicTacToeExample = _mounted()
	scene._board = "OX......."
	scene._last_draw = {"chance": 0.4, "square": 1, "board": TicTacToeBoard.START, "age": 10}
	scene._handle_key(KEY_4)
	scene._handle_key(KEY_M)

	var panel: Label = scene.get_node("Interface/Decision")
	var status: Label = scene.get_node("Interface/Status")
	assert_float(panel.position.y + float(panel.get_line_count() * panel.get_line_height())).is_less_equal(status.position.y)


func _mounted() -> TicTacToeExample:
	var scene: TicTacToeExample = auto_free(load("res://game/tictactoe/tictactoe.tscn").instantiate())
	add_child(scene)
	return scene


func _status(scene: TicTacToeExample) -> String:
	return (scene.get_node("Interface/Status") as Label).text


func _panel(scene: TicTacToeExample) -> String:
	return (scene.get_node("Interface/Decision") as Label).text
