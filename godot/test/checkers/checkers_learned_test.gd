# T32: the game reads the learned weights Python published, switches white
# between them and the hand-written ones, and shows what each count adds to
# the score -- so a person can see why the two choose differently.
extends GdUnitTestSuite

# These tests read the English words. The engine starts in the system's
# locale, so on a Portuguese system they would read the pt-BR ones (T78);
# the Portuguese screen is test/locale's. The locale found is put back.
var _locale_before: String


func before() -> void:
	_locale_before = TranslationServer.get_locale()
	TranslationServer.set_locale("en")


func after() -> void:
	TranslationServer.set_locale(_locale_before)


func test_the_published_weights_are_the_ones_read() -> void:
	var published: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CheckersWeights.PATH))
	var learned: Array[float] = CheckersWeights.learned()
	assert_int(learned.size()).is_equal(CheckersEvaluation.FEATURES.size())
	assert_array(learned).is_equal(published["learned"]["weights"])


# Three numbers multiplied against the wrong counts would still play; so a
# file naming other features, or another order, is not read at all.
func test_a_file_naming_other_features_is_refused() -> void:
	var path: String = "user://planted_checkers_weights.json"
	var planted: Dictionary = {"features": ["kings", "men", "advancement"], "learned": {"weights": [1.0, 2.0, 3.0]}}
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(planted))
	assert_dict(CheckersWeights.read(path)).is_empty()
	planted["features"] = CheckersEvaluation.FEATURES
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(planted))
	assert_dict(CheckersWeights.read(path)).is_not_empty()
	planted["learned"]["weights"] = [1.0, 2.0]
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(planted))
	assert_dict(CheckersWeights.read(path)).is_empty()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_the_contributions_add_up_to_the_score() -> void:
	var board: CheckersBoard = CheckersBoard.from_rows([
		". w . . . . . .", ". . . . . . . .", ". . . W . . . .", ". . . . . . . .",
		"r . . . . . . .", ". . . . . . . .", ". . r . . . . .", ". . . . . . . .",
	] as Array[String], CheckersBoard.RED)
	var weights: Array[float] = [0.5, -2.0, 0.25]
	var parts: Array[float] = CheckersEvaluation.contributions(board, CheckersBoard.RED, weights)
	assert_array(parts).is_equal([0.5, 2.0, 1.0])
	assert_float(CheckersEvaluation.weighted(board, CheckersBoard.RED, weights)).is_equal_approx(3.5, 1e-9)


func test_the_game_searches_with_the_weights_it_was_made_with() -> void:
	var learned: Array[float] = CheckersWeights.learned()
	assert_array(CheckersGame.new().weights).is_equal(CheckersEvaluation.HAND_WEIGHTS)
	assert_array(CheckersGame.new(learned).weights).is_equal(learned)


func test_e_switches_white_to_the_learned_weights_and_it_thinks_again() -> void:
	var scene: CheckersExample = _mounted_after_red_s_first_move()
	assert_str(scene.decision_overlay()["evaluation"]).is_equal("hand-written")

	scene.use_learned(true)

	var overlay: Dictionary = scene.decision_overlay()
	assert_str(overlay["evaluation"]).is_equal("learned")
	assert_array(scene._game.weights).is_equal(CheckersWeights.learned())
	assert_bool(overlay["pending"]).is_true()
	assert_str(_panel(scene)).contains("▶ learned")
	scene.use_learned(false)
	assert_array(scene._game.weights).is_equal(CheckersEvaluation.HAND_WEIGHTS)


# The breakdown is of the position the chosen move's value comes from: the
# end of the line white expects, counted for white.
func test_the_why_is_the_end_of_the_line_white_expects() -> void:
	var scene: CheckersExample = _mounted_after_red_s_first_move()
	var board: CheckersBoard = scene._board
	for move: CheckersMove in scene._expected:
		board = CheckersRules.play(board, move)

	var why: Dictionary = scene.decision_overlay()["why"]

	assert_array(why["counts"]).is_equal(CheckersEvaluation.features(board, CheckersBoard.WHITE))
	assert_array(why["hand"]).is_equal(
			CheckersEvaluation.contributions(board, CheckersBoard.WHITE, CheckersEvaluation.HAND_WEIGHTS))
	assert_array(why["learned"]).is_equal(
			CheckersEvaluation.contributions(board, CheckersBoard.WHITE, CheckersWeights.learned()))


# The manual check asks a person to see the two choose differently, so there
# must be a position where they do: in the first plies of a quiet game, at
# depth 2, the learned weights -- which count a man's advance against it --
# hold back where the hand pushes on.
func test_somewhere_in_an_opening_the_two_evaluations_choose_differently() -> void:
	var search := AlphaBetaSearch.new()
	var hand := CheckersGame.new()
	var learned := CheckersGame.new(CheckersWeights.learned())
	var board: CheckersBoard = CheckersBoard.starting()
	for ply: int in range(12):
		var by_hand: CheckersMove = search.search(hand, board, 2).action
		if by_hand.notation() != search.search(learned, board, 2).action.notation():
			return
		board = CheckersRules.play(board, by_hand)
	fail("hand and learned chose the same move for twelve plies")


func _mounted_after_red_s_first_move() -> CheckersExample:
	var scene: CheckersExample = auto_free(load("res://game/checkers/checkers.tscn").instantiate())
	add_child(scene)
	scene.click_square(Vector2i(2, 5))
	scene.click_square(Vector2i(3, 4))
	return scene


func _panel(scene: CheckersExample) -> String:
	return (scene.get_node("Interface/Decision") as Label).text


# --- the wave 33 review ----------------------------------------------------

# Once space plays the move, the breakdown is still of the line white chose
# from the position it chose in -- not of a line replayed from the board after.
func test_the_why_stays_with_the_decision_after_it_is_played() -> void:
	# White's line opens with a capture, so replaying it from the board after
	# the capture -- with the jumped man already gone -- counts differently.
	var scene: CheckersExample = auto_free(load("res://game/checkers/checkers.tscn").instantiate())
	add_child(scene)
	scene.depth = 2
	scene._board = CheckersBoard.from_rows([
		". . . . . . . .", ". . . . . . . .", ". . . . . . . .", ". . w . . . . .",
		". . . r . . . .", ". . . . . . . .", ". . . . . . . .", ". . . . . . r .",
	] as Array[String], CheckersBoard.WHITE)
	scene._think()
	var decided_on: CheckersBoard = scene._board
	scene.step_decision()
	var board: CheckersBoard = decided_on
	for move: CheckersMove in scene._expected:
		board = CheckersRules.play(board, move)
	assert_array(scene.why()["counts"]).is_equal(CheckersEvaluation.features(board, CheckersBoard.WHITE))


func test_a_file_with_weights_that_are_not_numbers_or_odd_shapes_is_refused() -> void:
	var path: String = "user://planted_checkers_weights.json"
	for planted: Variant in [
		{"features": CheckersEvaluation.FEATURES, "learned": {"weights": ["1", 2.0, 3.0]}},
		{"features": CheckersEvaluation.FEATURES, "learned": 3},
		{"features": "men", "learned": {"weights": [1.0, 2.0, 3.0]}},
		[1, 2, 3],
	]:
		FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(planted))
		assert_dict(CheckersWeights.read(path)).override_failure_message(str(planted)).is_empty()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
