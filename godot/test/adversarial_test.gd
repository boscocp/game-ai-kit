# What T27 asks of `ai_adversarial`: alpha-beta is minimax with a shortcut, and
# the shortcut changes the work and nothing else.
#
# Two kinds of position. The book's own tree first, whose answer is printed in
# Russell & Norvig (figure 5.2: the root is worth 3, and alpha-beta never
# looks at two of the leaves), so the search is held to a number somebody
# else worked out. Then real checkers positions, from a fixed seed, which is
# where a bug that only shows with captures and kings would hide.
extends GdUnitTestSuite

const SEED: int = 27
const POSITIONS: int = 40
const DEPTH: int = 4


func test_the_book_tree_is_worth_3_to_both_searches() -> void:
	var game := TreeGame.new()

	var minimax: AdversarialResult = MinimaxSearch.new().search(game, game.root(), 2)
	var alpha_beta: AdversarialResult = AlphaBetaSearch.new().search(game, game.root(), 2)

	assert_float(minimax.value).is_equal(3.0)
	assert_float(alpha_beta.value).is_equal(3.0)
	assert_str(str(minimax.action)).is_equal("a1")
	assert_str(str(alpha_beta.action)).is_equal("a1")


func test_on_the_book_tree_alpha_beta_skips_the_two_leaves_the_book_skips() -> void:
	# Thirteen positions: the root, three replies, nine leaves. Alpha-beta
	# leaves out the second and third leaf under a2, because its first leaf, 2,
	# already makes a2 worse than the 3 in hand. Under a3 it has to look at all
	# three: 14 and 5 do not settle it, and the cut on the last leaf skips
	# nothing.
	var game := TreeGame.new()

	assert_int(MinimaxSearch.new().search(game, game.root(), 2).positions).is_equal(13)
	var alpha_beta: AdversarialResult = AlphaBetaSearch.new().search(game, game.root(), 2)
	assert_int(alpha_beta.positions).is_equal(11)
	assert_int(alpha_beta.pruned).is_equal(2)


func test_a_pruned_root_move_is_marked_as_a_bound_and_not_a_value() -> void:
	var game := TreeGame.new()

	var alpha_beta: AdversarialResult = AlphaBetaSearch.new().search(game, game.root(), 2)

	var exact: Array = alpha_beta.considered.map(func(entry: Dictionary) -> bool: return entry["exact"])
	assert_array(exact).is_equal([true, false, false])
	assert_float(alpha_beta.considered[1]["value"]).is_equal(2.0)


func test_minimax_and_alpha_beta_agree_on_value_and_move_over_many_positions() -> void:
	var game := CheckersGame.new()
	for board: CheckersBoard in _positions():
		var minimax: AdversarialResult = MinimaxSearch.new().search(game, board, DEPTH)
		var alpha_beta: AdversarialResult = AlphaBetaSearch.new().search(game, board, DEPTH)

		assert_float(alpha_beta.value).is_equal_approx(minimax.value, 0.000001)
		assert_object(alpha_beta.action).is_same(minimax.action)


func test_alpha_beta_never_searches_more_and_searches_fewer_in_total() -> void:
	var game := CheckersGame.new()
	var minimax_total: int = 0
	var alpha_beta_total: int = 0
	for board: CheckersBoard in _positions():
		var minimax: int = MinimaxSearch.new().search(game, board, DEPTH).positions
		var alpha_beta: int = AlphaBetaSearch.new().search(game, board, DEPTH).positions
		assert_int(alpha_beta).is_less_equal(minimax)
		minimax_total += minimax
		alpha_beta_total += alpha_beta

	assert_int(alpha_beta_total).is_less(minimax_total)


func test_every_exact_root_value_is_the_minimax_value_and_every_bound_is_above_it() -> void:
	var game := CheckersGame.new()
	for board: CheckersBoard in _positions():
		var minimax: AdversarialResult = MinimaxSearch.new().search(game, board, DEPTH)
		var alpha_beta: AdversarialResult = AlphaBetaSearch.new().search(game, board, DEPTH)
		for index: int in range(minimax.considered.size()):
			_assert_shown_value_is_honest(alpha_beta.considered[index], minimax.considered[index]["value"])


func test_a_position_with_no_move_returns_no_move_and_its_outcome() -> void:
	var board: CheckersBoard = CheckersBoard.from_rows([
		". . . . . . . .",
		". . . . . . . .",
		". . . . . . . .",
		". . . . . . . .",
		". . . . . . . .",
		". . . . . . . .",
		". . . . . . . .",
		"r . . . . . . .",
	] as Array[String], CheckersBoard.WHITE)

	var found: AdversarialResult = AlphaBetaSearch.new().search(CheckersGame.new(), board, 3)

	assert_object(found.action).is_null()
	assert_float(found.value).is_equal(-CheckersGame.WIN)


# An exact value is the minimax value; a bound is never below it, because it
# says "at most this".
func _assert_shown_value_is_honest(shown: Dictionary, truth: float) -> void:
	if shown["exact"]:
		assert_float(shown["value"]).is_equal_approx(truth, 0.000001)
	else:
		assert_float(shown["value"]).is_greater_equal(truth - 0.000001)


# Positions from real play: the opening, then each move of a game where both
# sides pick uniformly from their legal moves, from a fixed seed. Captures,
# multi-jumps and kings all turn up, which a hand-picked set would miss.
func _positions() -> Array[CheckersBoard]:
	var random := RandomNumberGenerator.new()
	random.seed = SEED
	var found: Array[CheckersBoard] = []
	var board: CheckersBoard = CheckersBoard.starting()
	while found.size() < POSITIONS:
		if CheckersRules.is_over(board):
			board = CheckersBoard.starting()
		found.append(board)
		var moves: Array = CheckersRules.legal_moves(board)
		board = CheckersRules.play(board, moves[random.randi_range(0, moves.size() - 1)])
	return found


## Figure 5.2 of Russell & Norvig: MAX chooses among a1, a2, a3; MIN then
## chooses among three leaves under each. A state is the list of moves made.
class TreeGame extends AdversarialGame:
	const LEAVES: Dictionary = {
		"a1": [3.0, 12.0, 8.0], "a2": [2.0, 4.0, 6.0], "a3": [14.0, 5.0, 2.0],
	}

	## The empty history.
	func root() -> RefCounted:
		return History.new([])

	## MAX at the root, MIN below it.
	func to_move(state: RefCounted) -> int:
		return (state as History).moves.size() % 2

	## Three moves at each of the first two levels.
	func actions(state: RefCounted) -> Array:
		var moves: Array = (state as History).moves
		if moves.is_empty():
			return ["a1", "a2", "a3"]
		return [0, 1, 2] if moves.size() == 1 else []

	## The history with one more move.
	func result(state: RefCounted, action: Variant) -> RefCounted:
		return History.new((state as History).moves + [action])

	## Over after two moves.
	func is_terminal(state: RefCounted) -> bool:
		return (state as History).moves.size() == 2

	## The leaf's number, for MAX; never asked for anything but a leaf here.
	func evaluate(state: RefCounted, _player: int) -> float:
		var moves: Array = (state as History).moves
		return LEAVES[moves[0]][moves[1]] if moves.size() == 2 else 0.0


## The moves made so far, which is all a state of the tree is.
class History extends RefCounted:
	var moves: Array = []

	func _init(made: Array) -> void:
		moves = made
