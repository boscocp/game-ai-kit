# T28 in the engine: the published beads load, MENACE plays by them and never
# changes one, perfect play is perfect, and the scene shows the beads before
# MENACE draws.
#
# Whether a person feels the 10-game machine play worse than the 10,000-game
# one is the task's manual check. That the beads differ, and that MENACE
# plays the bead the draw lands on, is held here.
#
# The scene's words are read in English, so each test starts in English
# whatever the machine's locale (the engine starts in the system's, measured
# in docs/godot/localisation.md); the Portuguese ones say so and set it.
extends GdUnitTestSuite

var _locale_before: String = ""


func before() -> void:
	_locale_before = TranslationServer.get_locale()


func before_test() -> void:
	TranslationServer.set_locale("en")


func after() -> void:
	TranslationServer.set_locale(_locale_before)


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
	var counts: Array[int] = [4, 4, 0, 0, 4, 0, 0, 0, 0]

	assert_int(MenacePlayer.draw(counts, 0.0)).is_equal(0)
	assert_int(MenacePlayer.draw(counts, 0.34)).is_equal(1)
	assert_int(MenacePlayer.draw(counts, 0.999)).is_equal(4)
	assert_int(MenacePlayer.draw(MenacePlayer.EMPTY_BOX, 0.5)).is_equal(-1)


func test_perfect_play_draws_the_empty_board_and_takes_a_win_when_there_is_one() -> void:
	assert_int(TicTacToeSolver.value(TicTacToeBoard.START, TicTacToeBoard.CROSS)).is_equal(TicTacToeSolver.DRAW)
	# Crosses on the top left and top edge, noughts below: the top right wins.
	assert_int(TicTacToeSolver.best_square("XX.OO....")).is_equal(2)
	assert_int(TicTacToeSolver.square_values("XX.OO....")[2]).is_equal(TicTacToeSolver.WIN)


func test_the_beads_are_read_only_at_every_level() -> void:
	# The engine's half of invariant 6: a write anywhere is refused. Measured on
	# 4.7.2 -- an index, `+=`, a copy of the reference, a replaced box,
	# `clear()` -- all fail with a script error and change nothing.
	var menace: MenacePlayer = MenacePlayer.load_published()

	assert_bool(menace._snapshots.is_read_only()).is_true()
	for age: int in menace.ages:
		var boxes: Dictionary = menace._snapshots[age]
		assert_bool(boxes.is_read_only()).is_true()
		for box: String in boxes:
			assert_bool((boxes[box] as Array).is_read_only()).override_failure_message(box).is_true()
	assert_bool(menace.beads_for(10, TicTacToeBoard.START).is_read_only()).is_true()


func test_beads_land_on_the_real_squares_of_a_turned_board() -> void:
	# Only the empty board, which is its own box, was tested; a mapping that
	# drew beads on the box's squares instead of the board's survived.
	var menace: MenacePlayer = MenacePlayer.with_box("..O...X..", [2, 1, 0, 1, 3, 0, 0, 0, 0])
	var by_square: Dictionary = {}
	for entry: Dictionary in menace.squares_for(0, "O.......X"):
		by_square[entry["square"]] = entry

	assert_int(by_square[6]["beads"]).is_equal(2)
	assert_int(by_square[3]["beads"]).is_equal(1)
	assert_int(by_square[7]["beads"]).is_equal(1)
	assert_int(by_square[4]["beads"]).is_equal(3)
	assert_bool(by_square[2].has("same_move_as")).is_true()


func test_a_draw_at_the_very_end_takes_the_last_square_with_beads() -> void:
	assert_int(MenacePlayer.draw([1, 0, 0, 0, 2, 0, 0, 0, 0] as Array[int], 1.0)).is_equal(4)


func test_after_the_age_changes_the_last_draw_is_shown_with_the_box_it_came_from() -> void:
	var scene: TicTacToeExample = _mounted()
	scene.menace_moves(0.4)
	var drawn_at_ten: String = str(scene.decision_overlay()["squares"])

	scene._handle_key(KEY_4)

	assert_int(scene.decision_overlay()["age"]).is_equal(10)
	assert_str(str(scene.decision_overlay()["squares"])).is_equal(drawn_at_ten)
	assert_str(_panel(scene)).contains("MENACE AFTER 10 GAMES")


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
	# Every opening square draws: naming one would make MENACE's favourite
	# look wrong when it is not.
	assert_str(_panel(scene)).contains("every move draws for MENACE")


func test_no_panel_line_runs_off_the_window() -> void:
	# Four squares as good as each other once ran the perfect-play line past
	# the right edge.
	var scene: TicTacToeExample = _mounted()
	scene.menace_moves(0.4)
	scene._handle_key(KEY_M)
	var panel: Label = scene.get_node("Interface/Decision")
	var font: Font = panel.get_theme_font("font")
	var size: int = panel.get_theme_font_size("font_size")

	for line: String in panel.text.split("\n"):
		var right: float = panel.position.x + font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
		assert_float(right).override_failure_message("\"%s\" ends at %.0f" % [line, right]).is_less_equal(1280.0)


func test_no_panel_line_runs_off_the_window_in_portuguese() -> void:
	# A Portuguese line is longer (T79): the same widest panel, in pt-BR.
	TranslationServer.set_locale("pt_BR")
	var scene: TicTacToeExample = _mounted()
	scene.menace_moves(0.4)
	scene._handle_key(KEY_M)
	var panel: Label = scene.get_node("Interface/Decision")
	var font: Font = panel.get_theme_font("font")
	var size: int = panel.get_theme_font_size("font_size")

	assert_str(panel.text).contains("PARTIDAS")
	for line: String in panel.text.split("\n"):
		var right: float = panel.position.x + font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
		assert_float(right).override_failure_message("\"%s\" ends at %.0f" % [line, right]).is_less_equal(1280.0)


func test_the_legend_ends_above_the_panel() -> void:
	var scene: TicTacToeExample = _mounted()
	var legend: Legend = scene.get_node("Interface/Legend")
	var panel: Label = scene.get_node("Interface/Decision")

	assert_float(legend.position.y + legend.entries.size() * Legend.LINE).is_less_equal(panel.position.y)


func test_the_panel_ends_above_the_status_line_with_seven_moves_and_a_draw_shown() -> void:
	# The widest the panel gets: seven empty squares, all different, a draw
	# to report and perfect play on -- in English and in Portuguese, whose
	# lines are longer (T79).
	for locale: String in ["en", "pt_BR"]:
		TranslationServer.set_locale(locale)
		var scene: TicTacToeExample = _widest_panel()
		var panel: Label = scene.get_node("Interface/Decision")
		var status: Label = scene.get_node("Interface/Status")

		assert_float(panel.position.y + float(panel.get_line_count() * panel.get_line_height())).is_less_equal(status.position.y)
		for line: String in panel.text.split("\n"):
			_assert_fits(panel, line, locale)


# The scene with the most the panel ever says.
func _widest_panel() -> TicTacToeExample:
	var scene: TicTacToeExample = _mounted()
	scene._board = "OX......."
	scene._last_draw = {"chance": 0.4, "square": 1, "board": TicTacToeBoard.START, "age": 10,
			"forced": false, "total": 26, "bead": 11}
	scene._handle_key(KEY_4)
	scene._handle_key(KEY_M)
	return scene


# The panel's `line` ends inside the 1280-pixel window.
func _assert_fits(panel: Label, line: String, locale: String) -> void:
	var font: Font = panel.get_theme_font("font")
	var size: int = panel.get_theme_font_size("font_size")
	var right: float = panel.position.x + font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	assert_float(right).override_failure_message("%s: \"%s\" ends at %.0f" % [locale, line, right]).is_less_equal(1280.0)


func test_the_bead_drawn_can_be_found_in_the_panel_s_list() -> void:
	# The play review could not check "drew 0.70 of the way" against a list
	# sorted best first. The list is now in the order the beads are counted
	# out, with each move's run of bead numbers.
	for chance: float in [0.0, 0.3, 0.5, 0.7, 0.999]:
		var scene: TicTacToeExample = _mounted()
		scene.menace_moves(chance)
		var overlay: Dictionary = scene.decision_overlay()
		var square: String = TicTacToeView.square_name(overlay["chosen"])
		var line: String = _panel_line_for(_panel(scene), square)
		assert_str(_panel(scene)).contains("it drew bead %d of %d" % [overlay["bead"], overlay["total"]])
		assert_bool(_run_contains(line, overlay["bead"])).override_failure_message(
			"bead %d is not in \"%s\"" % [overlay["bead"], line]).is_true()


func test_the_last_square_is_forced_and_says_so() -> void:
	var scene: TicTacToeExample = _mounted()
	scene._board = "XOXXOOO.X"
	scene._refresh()

	assert_str(_status(scene)).contains("the move is forced")
	assert_str(_panel(scene)).contains("no box for it")
	scene.menace_moves(0.5)
	assert_str(scene._board).is_equal("XOXXOOOXX")
	assert_str(_panel(scene)).contains("forced, the bottom edge")


func test_a_finished_game_shows_the_box_menace_last_drew_from_not_an_empty_one() -> void:
	# You win with three noughts across the middle, and it would be MENACE's
	# turn: the finished board has no box, and used to show one with 0 beads.
	var scene: TicTacToeExample = _mounted()
	scene.menace_moves(0.0)
	scene._board = "XX.OOO.X."
	scene._refresh()

	assert_str(_status(scene)).contains("you win")
	assert_str(scene.decision_overlay()["box"]).is_equal(TicTacToeBoard.START)
	assert_str(_panel(scene)).not_contains("is empty")
	assert_bool(scene.decision_overlay().has("perfect")).is_false()


func test_an_empty_box_warns_before_space_resigns() -> void:
	var scene: TicTacToeExample = _mounted()
	scene._menace = MenacePlayer.with_box(TicTacToeBoard.START, [0, 0, 0, 0, 0, 0, 0, 0, 0])
	scene._refresh()

	assert_str(_status(scene)).contains("its box is empty")


func test_small_chances_and_large_ages_read_as_a_person_writes_them() -> void:
	assert_str(TicTacToePanel.percent(0.003)).is_equal("<1%")
	assert_str(TicTacToePanel.percent(0.0)).is_equal("0%")
	assert_str(TicTacToePanel.games(10000)).is_equal("10,000")
	assert_str(TicTacToePanel.games(100)).is_equal("100")
	TranslationServer.set_locale("pt_BR")
	assert_str(TicTacToePanel.games(10000)).is_equal("10.000")


# The panel line naming `square`, or "".
func _panel_line_for(panel: String, square: String) -> String:
	for line: String in panel.split("\n"):
		if line.strip_edges().begins_with(square + " ") and "bead" in line:
			return line
	return ""


# True when a line's "bead N" or "beads N-M" includes `bead`.
func _run_contains(line: String, bead: int) -> bool:
	var found := RegEx.create_from_string("beads? (\\d+)(?:-(\\d+))?").search(line)
	if found == null:
		return false
	var last: int = int(found.get_string(2)) if found.get_string(2) != "" else int(found.get_string(1))
	return bead >= int(found.get_string(1)) and bead <= last


func _mounted() -> TicTacToeExample:
	var scene: TicTacToeExample = auto_free(load("res://game/tictactoe/tictactoe.tscn").instantiate())
	add_child(scene)
	return scene


func _status(scene: TicTacToeExample) -> String:
	return (scene.get_node("Interface/Status") as Label).text


func _panel(scene: TicTacToeExample) -> String:
	return (scene.get_node("Interface/Decision") as Label).text


# T121: the MENACE vectors runner refuses a file of the wrong types before
# it reads one. Beads given as text, in a copy of a real file, were a SCRIPT
# ERROR that skipped the check and let the runner exit 0.
func test_a_menace_vector_of_the_wrong_types_is_refused() -> void:
	var runner: GDScript = preload("res://test/tictactoe/menace_vectors_runner.gd")
	var vector: Dictionary = VectorShape.read_spec("vectors/menace/a-turned-board.json")
	assert_str(VectorShape.why_not(vector, runner.SHAPE)).is_empty()
	var paths: Array = [["cases"], ["cases", 0, "beads"], ["cases", 0, "move"]]
	for path: Array in paths:
		var why: String = VectorShape.why_not(VectorShape.planted(vector, path, "x"), runner.SHAPE)
		assert_str(why).override_failure_message(str(path)).is_not_empty()