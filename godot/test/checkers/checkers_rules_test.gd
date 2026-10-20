# The rules of English draughts as `CheckersRules` plays them, one rule per
# test, each on a position drawn so the rule is the only thing in it.
#
# Rows are drawn top first. Red (r, R) moves up the page and white (w, W)
# down; capitals are kings. The lookahead test at the end is the one T27 asks
# for that only a search can pass.
extends GdUnitTestSuite


func test_the_opening_has_twelve_men_each_and_red_moves_first_with_seven_steps() -> void:
	var board: CheckersBoard = CheckersBoard.starting()

	assert_int(board.squares_of(CheckersBoard.RED).size()).is_equal(12)
	assert_int(board.squares_of(CheckersBoard.WHITE).size()).is_equal(12)
	assert_int(board.to_move).is_equal(CheckersBoard.RED)
	assert_int(CheckersRules.legal_moves(board).size()).is_equal(7)


func test_a_man_steps_diagonally_forward_and_never_back() -> void:
	var board: CheckersBoard = _board([
		". . . . . . . .",
		". . . . . . . .",
		". . . . . . . .",
		". . . . . . . .",
		". . . r . . . .",
		". . . . . . . .",
		". . . . . . . .",
		"w . . . . . . .",
	], CheckersBoard.RED)

	assert_array(_names(CheckersRules.legal_moves(board))).contains_exactly(["d4-c5", "d4-e5"])
	assert_str(CheckersRules.why_refused(board, Vector2i(3, 4), Vector2i(2, 5))).contains("only forward")


func test_a_king_steps_both_ways() -> void:
	var board: CheckersBoard = _board([
		". . . . . . . .",
		". . . . . . . .",
		". . . . . . . .",
		". . . . . . . .",
		". . . R . . . .",
		". . . . . . . .",
		". . . . . . . .",
		"w . . . . . . .",
	], CheckersBoard.RED)

	assert_int(CheckersRules.legal_moves(board).size()).is_equal(4)


func test_when_a_capture_exists_only_captures_are_legal() -> void:
	var board: CheckersBoard = _board([
		". . . . . . . .",
		". . . . . . . .",
		". . . . . . . .",
		". . w . . . . .",
		". . . r . . . .",
		". . . . . . r .",
		". . . . . . . .",
		". . . . . . . .",
	], CheckersBoard.RED)

	var moves: Array = CheckersRules.legal_moves(board)
	assert_array(_names(moves)).contains_exactly(["d4xb6"])
	assert_str(CheckersRules.why_refused(board, Vector2i(6, 5), Vector2i(5, 4))).contains("compulsory")
	assert_str(CheckersRules.why_refused(board, Vector2i(3, 4), Vector2i(4, 3))).contains("compulsory")


func test_with_two_captures_either_may_be_played() -> void:
	# No majority rule: the single jump is as legal as the double one.
	var board: CheckersBoard = _board([
		". . . . . . . .",
		". . . . . . . .",
		". . . . . w . .",
		". . . . . . . .",
		". . . w . w . .",
		". . . . r . . .",
		". . . . . . . .",
		". . . . . . . .",
	], CheckersBoard.RED)

	var moves: Array = CheckersRules.legal_moves(board)
	assert_array(_names(moves)).contains_exactly(["e3xc5", "e3xg5xe7"])
	for move: CheckersMove in moves:
		assert_str(CheckersRules.why_refused(board, move.from(), move.to())).is_equal("")


func test_a_multi_jump_is_one_move_and_is_completed() -> void:
	var board: CheckersBoard = _board([
		". . . . . . . .",
		". . . . . . . .",
		". . . . . . . .",
		". . . . w . . .",
		". . . . . . . .",
		". . w . . . . .",
		". r . . . . . .",
		". . . . . . . .",
	], CheckersBoard.RED)

	var moves: Array = CheckersRules.legal_moves(board)
	assert_array(_names(moves)).contains_exactly(["b2xd4xf6"])
	var after: CheckersBoard = CheckersRules.play(board, moves[0])
	assert_int(after.squares_of(CheckersBoard.WHITE).size()).is_equal(0)
	assert_int(after.to_move).is_equal(CheckersBoard.WHITE)
	# Stopping halfway is refused: the sequence, once begun, is finished.
	assert_str(CheckersRules.why_refused(board, Vector2i(1, 6), Vector2i(3, 4))).contains("finish every jump")


func test_a_man_reaching_the_far_row_is_crowned() -> void:
	var board: CheckersBoard = _board([
		". . . . . . . .",
		". . r . . . . .",
		". . . . . . . .",
		". . . . . . . .",
		". . . . . . . .",
		". . . . . . . .",
		". . . . . . . .",
		"w . . . . . . .",
	], CheckersBoard.RED)

	var move: CheckersMove = CheckersRules.legal_moves(board)[0]
	var after: CheckersBoard = CheckersRules.play(board, move)

	assert_bool(move.crowns).is_true()
	assert_int(after.piece_at(move.to())).is_equal(CheckersBoard.RED_KING)


func test_crowning_ends_the_move_even_in_the_middle_of_a_jump() -> void:
	# The man jumps e7 and lands on d8, the far row. As a king it could jump on
	# over c7 to b6 -- and it may not: crowning ends the move, and c7 stands.
	var board: CheckersBoard = _board([
		". . . . . . . .",
		". . w . w . . .",
		". . . . . r . .",
		". . . . . . . .",
		". . . . . . . .",
		". . . . . . . .",
		". . . . . . . .",
		". . . . . . . .",
	], CheckersBoard.RED)

	var moves: Array = CheckersRules.legal_moves(board)
	assert_array(_names(moves)).contains_exactly(["f6xd8"])
	var after: CheckersBoard = CheckersRules.play(board, moves[0])
	assert_bool((moves[0] as CheckersMove).crowns).is_true()
	assert_int(after.piece_at(Vector2i(3, 0))).is_equal(CheckersBoard.RED_KING)
	assert_int(after.piece_at(Vector2i(2, 1))).is_equal(CheckersBoard.WHITE_MAN)


func test_a_side_with_no_legal_move_has_lost() -> void:
	# Red's only man is on a1, and the one square ahead of it is held by a
	# white man that cannot be jumped, because b2's far side is held too.
	var board: CheckersBoard = _board([
		". . . . . . . .",
		". . . . . . . .",
		". . . . . . . .",
		". . . . . . . .",
		". . . . . . . .",
		". . w . . . . .",
		". w . . . . . .",
		"r . . . . . . .",
	], CheckersBoard.RED)

	assert_int(CheckersRules.legal_moves(board).size()).is_equal(0)
	assert_int(CheckersRules.winner(board)).is_equal(CheckersBoard.WHITE)
	assert_bool(CheckersRules.is_over(board)).is_true()


func test_forty_moves_each_by_kings_alone_without_a_capture_is_a_draw() -> void:
	# Red is a king up, so the draw scoring 0 is the rule and not the material.
	var board: CheckersBoard = _board([
		". R . . . . . .",
		". . . . . . . .",
		". . . . . . . .",
		". . . . . . . .",
		". . . . . R . .",
		". . . . . . . .",
		". . . . . . . .",
		". . . . . . W .",
	], CheckersBoard.RED)

	# Forty moves by each side, written out: the constant cannot quietly drift.
	assert_int(CheckersBoard.QUIET_PLIES_TO_DRAW).is_equal(80)
	# Each king steps out and back, so nothing but the count changes.
	var red_squares: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0)]
	var white_squares: Array[Vector2i] = [Vector2i(7, 6), Vector2i(6, 7)]
	for ply: int in range(80):
		assert_bool(CheckersRules.is_draw(board)).override_failure_message(
			"drawn after only %d plies" % ply).is_false()
		var targets: Array[Vector2i] = red_squares if board.to_move == CheckersBoard.RED else white_squares
		board = CheckersRules.play(board, _move_to(board, targets[(ply / 2) % 2]))

	assert_bool(CheckersRules.is_draw(board)).is_true()
	assert_bool(CheckersRules.is_over(board)).is_true()
	assert_float(CheckersGame.new().evaluate(board, CheckersBoard.RED)).is_equal(0.0)


func test_a_king_moving_counts_towards_the_draw_and_a_man_moving_starts_it_again() -> void:
	var board: CheckersBoard = _board([
		". R . . . . . .",
		". . . . . . . .",
		". . . . . . . .",
		". . w . . . . .",
		". . . . . . . .",
		". . . . . . . .",
		". . . . . . . .",
		". . . . . . W .",
	], CheckersBoard.RED)
	board.quiet_plies = 50

	board = CheckersRules.play(board, _move_of(board, Vector2i(1, 0)))
	assert_int(board.quiet_plies).is_equal(51)
	board = CheckersRules.play(board, _move_of(board, Vector2i(2, 3)))
	assert_int(board.quiet_plies).is_equal(0)


func test_crowning_is_a_man_moving_so_it_starts_the_count_again() -> void:
	var board: CheckersBoard = _board([
		". . . . . . . .",
		". . r . . . . .",
		". . . . . . . .",
		". . . . . . . .",
		". . . . . . . .",
		". . . . . . . .",
		". . . . . . . .",
		". . . . . . W .",
	], CheckersBoard.RED)
	board.quiet_plies = 50

	board = CheckersRules.play(board, _move_of(board, Vector2i(2, 1)))

	assert_int(board.quiet_plies).is_equal(0)


func test_a_man_captures_forward_only() -> void:
	# Red's man on d4 has white men ahead of it on c5 and behind it on e3, each
	# with an empty square beyond. Only the one ahead may be taken.
	var board: CheckersBoard = _board([
		". . . . . . . .",
		". . . . . . . .",
		". . . . . . . .",
		". . w . . . . .",
		". . . r . . . .",
		". . . . w . . .",
		". . . . . . . .",
		". . . . . . . .",
	], CheckersBoard.RED)

	assert_array(_names(CheckersRules.legal_moves(board))).contains_exactly(["d4xb6"])


func test_a_king_captures_backwards_too() -> void:
	var board: CheckersBoard = _board([
		". . . . . . . .",
		". . . . . . . .",
		". . . . . . . .",
		". . . . . . . .",
		". . . R . . . .",
		". . . . w . . .",
		". . . . . . . .",
		". . . . . . . .",
	], CheckersBoard.RED)

	assert_array(_names(CheckersRules.legal_moves(board))).contains_exactly(["d4xf2"])


func test_a_king_s_capture_may_end_on_the_square_it_started_from() -> void:
	# Four white men round the red king on b4: the jump goes all the way round
	# and lands back on b4, both ways round, and takes all four.
	var board: CheckersBoard = _board([
		". . . . . . . .",
		". . . . . . . .",
		". . . . . . . .",
		". . w . w . . .",
		". R . . . . . .",
		". . w . w . . .",
		". . . . . . . .",
		". . . . . . W .",
	], CheckersBoard.RED)

	var moves: Array = CheckersRules.legal_moves(board)
	assert_array(_names(moves)).contains_exactly(["b4xd6xf4xd2xb4", "b4xd2xf4xd6xb4"])
	assert_int((moves[0] as CheckersMove).captured.size()).is_equal(4)


func test_no_piece_is_jumped_twice_in_one_move() -> void:
	# A red king and one white man: jumping it back and forth for ever would
	# be a capture sequence that never ends. It is jumped once.
	var board: CheckersBoard = _board([
		". . . . . . . .",
		". . . . . . . .",
		". . . . . . . .",
		". . . . . . . .",
		". . . R . . . .",
		". . . . w . . .",
		". . . . . . . .",
		"w . . . . . . .",
	], CheckersBoard.RED)

	for move: CheckersMove in CheckersRules.legal_moves(board):
		assert_int(move.captured.size()).is_equal(1)


func test_the_evaluation_counts_men_kings_and_advancement() -> void:
	var men: CheckersBoard = _board([
		". . . . . . . .", ". . . . . . . .", ". . . . . . . .", ". . . . . . . .",
		". . . . . . . .", ". . . . . . . .", ". . . . . . . .", "r . . . . . . .",
	], CheckersBoard.RED)
	var advanced: CheckersBoard = _board([
		". . . . . . . .", ". r . . . . . .", ". . . . . . . .", ". . . . . . . .",
		". . . . . . . .", ". . . . . . . .", ". . . . . . . .", ". . . . . . . .",
	], CheckersBoard.RED)
	var king: CheckersBoard = _board([
		". R . . . . . .", ". . . . . . . .", ". . . . . . . .", ". . . . . . . .",
		". . . . . . . .", ". . . . . . . .", ". . . . . . . .", ". . . . . . . .",
	], CheckersBoard.RED)

	assert_float(CheckersEvaluation.score(men, CheckersBoard.RED)).is_equal_approx(1.0, 0.0001)
	assert_float(CheckersEvaluation.score(men, CheckersBoard.WHITE)).is_equal_approx(-1.0, 0.0001)
	assert_float(CheckersEvaluation.score(advanced, CheckersBoard.RED)).is_equal_approx(1.3, 0.0001)
	assert_float(CheckersEvaluation.score(king, CheckersBoard.RED)).is_equal_approx(1.5, 0.0001)


func test_a_win_is_worth_more_than_any_position_can_score() -> void:
	# Twelve kings against nothing is the most the evaluation can say. A win
	# below that would let the search trade a won game for material.
	var most: float = 12 * CheckersEvaluation.KING

	assert_float(CheckersGame.WIN).is_greater(most)


func test_lookahead_avoids_the_capture_that_is_immediately_recaptured() -> void:
	# White, the computer, must capture with its one man on d6, and has two
	# ways. d6xb4 lands where a3 jumps straight back, and white has nothing
	# left. d6xf4 is safe. Each takes one man from the same row, so to the
	# evaluation alone they look the same.
	var board: CheckersBoard = _board([
		". . . . . . . .",
		". . . . . . . .",
		". . . w . . . .",
		". . r . r . . .",
		". . . . . . . .",
		"r . . . . . . .",
		". . . . . . . .",
		". . . . . . . .",
	], CheckersBoard.WHITE)
	var game := CheckersGame.new()
	var search := AlphaBetaSearch.new()

	assert_array(_names(CheckersRules.legal_moves(board))).contains_exactly(["d6xb4", "d6xf4"])
	for depth: int in [2, 3, 4, 5, 6]:
		var chosen: CheckersMove = search.search(game, board, depth).action
		assert_str(chosen.notation()).override_failure_message(
			"at depth %d it took %s" % [depth, chosen.notation()]).is_equal("d6xf4")
	# The test is only worth something if depth 1 gets it wrong. At depth 1
	# the two are worth the same and the first listed is taken -- the one that
	# loses. A position where the evaluation alone picked the safe capture
	# would pass without any lookahead at all.
	var shallow: AdversarialResult = search.search(game, board, 1)
	assert_float(shallow.considered[0]["value"]).is_equal(shallow.considered[1]["value"])
	assert_str((shallow.action as CheckersMove).notation()).is_equal("d6xb4")


# A position drawn as rows of text, top row first.
func _board(rows: Array, side_to_move: int) -> CheckersBoard:
	var typed: Array[String] = []
	typed.assign(rows)
	return CheckersBoard.from_rows(typed, side_to_move)


func _names(moves: Array) -> Array:
	return moves.map(func(move: CheckersMove) -> String: return move.notation())


func _move_to(board: CheckersBoard, square: Vector2i) -> CheckersMove:
	for move: CheckersMove in CheckersRules.legal_moves(board):
		if move.to() == square:
			return move
	return null


func _move_of(board: CheckersBoard, square: Vector2i) -> CheckersMove:
	return CheckersRules.moves_of(board, square)[0]
