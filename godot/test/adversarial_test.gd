# What T27 asks of `ai_adversarial`: alpha-beta is minimax with a shortcut, and
# the shortcut changes the work and nothing else.
#
# Two kinds of position. The book's own tree first, whose answer is printed in
# Russell & Norvig (figure 5.2 gives the tree, worth 3 at the root; figure 5.5
# traces alpha-beta over it, never looking at two of the leaves), so the search
# is held to a number somebody else worked out. Then real checkers positions, from a fixed seed, which is
# where a bug that only shows with captures and kings would hide.
extends GdUnitTestSuite

const SEED: int = 27
const POSITIONS: int = 40
const DEPTH: int = 4


func test_the_book_tree_is_worth_3_to_both_searches() -> void:
	var game := TreeGame.new(TreeGame.BOOK)

	var minimax: AdversarialResult = MinimaxSearch.new().search(game, game.root(), 2)
	var alpha_beta: AdversarialResult = AlphaBetaSearch.new().search(game, game.root(), 2)

	assert_float(minimax.value).is_equal(3.0)
	assert_float(alpha_beta.value).is_equal(3.0)
	# a1, the first of MAX's three moves.
	assert_int(minimax.action).is_equal(0)
	assert_int(alpha_beta.action).is_equal(0)


func test_on_the_book_tree_alpha_beta_skips_the_two_leaves_the_book_skips() -> void:
	# Thirteen positions: the root, three replies, nine leaves. Alpha-beta
	# leaves out the second and third leaf under a2, because its first leaf, 2,
	# already makes a2 worse than the 3 in hand. Under a3 it has to look at all
	# three: 14 and 5 do not settle it, and the cut on the last leaf skips
	# nothing.
	var game := TreeGame.new(TreeGame.BOOK)

	assert_int(MinimaxSearch.new().search(game, game.root(), 2).positions).is_equal(13)
	var alpha_beta: AdversarialResult = AlphaBetaSearch.new().search(game, game.root(), 2)
	assert_int(alpha_beta.positions).is_equal(11)
	assert_int(alpha_beta.pruned).is_equal(2)


func test_a_cut_at_a_max_position_is_counted_too() -> void:
	# The book's tree only cuts at MIN positions. One ply deeper: under MIN's
	# first reply, MAX's first leaf, 6, already settles it; under the second,
	# MAX's first leaf, 7, is more than the 6 MIN has in hand, so MIN will
	# never go there and the 4 and the 5 beside it are skipped.
	var game := TreeGame.new([[[5.0, 6.0], [7.0, 4.0, 5.0]], [[3.0]]])

	var alpha_beta: AdversarialResult = AlphaBetaSearch.new().search(game, game.root(), 3)

	assert_float(alpha_beta.value).is_equal(6.0)
	assert_int(alpha_beta.pruned).is_equal(2)
	assert_int(alpha_beta.positions).is_equal(10)
	assert_int(MinimaxSearch.new().search(game, game.root(), 3).positions).is_equal(12)


func test_a_pruned_root_move_is_marked_as_a_bound_and_not_a_value() -> void:
	var game := TreeGame.new(TreeGame.BOOK)

	var alpha_beta: AdversarialResult = AlphaBetaSearch.new().search(game, game.root(), 2)

	# a2 is cut after its first leaf, so 2 is only "at most 2". a3 is looked
	# at to its last leaf, so its 2 is exact even though it is no better.
	var exact: Array = alpha_beta.considered.map(func(entry: Dictionary) -> bool: return entry["exact"])
	assert_array(exact).is_equal([true, false, true])
	assert_float(alpha_beta.considered[1]["value"]).is_equal(2.0)


func test_at_depth_one_nothing_is_cut_so_every_root_value_is_exact() -> void:
	# Every child of the root is a leaf: there is nothing below it to skip,
	# and a value marked "at most" there would be a lie the board then draws.
	var found: AdversarialResult = AlphaBetaSearch.new().search(CheckersGame.new(), CheckersBoard.starting(), 1)

	assert_int(found.pruned).is_equal(0)
	for entry: Dictionary in found.considered:
		assert_bool(entry["exact"]).is_true()


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


## A game tree written out as nested lists: a list is a position whose moves
## are its indexes, a number is a finished game worth that much to MAX. MAX
## moves at the root and the players alternate. A state is the moves made.
class TreeGame extends AdversarialGame:
	## Figure 5.2 of Russell & Norvig: MAX chooses among a1, a2, a3, and MIN
	## among three leaves under each.
	const BOOK: Array = [[3.0, 12.0, 8.0], [2.0, 4.0, 6.0], [14.0, 5.0, 2.0]]

	var tree: Array = []

	func _init(written: Array) -> void:
		tree = written

	## The empty history.
	func root() -> RefCounted:
		return History.new([])

	## MAX at the root, MIN below it, and so on.
	func to_move(state: RefCounted) -> int:
		return (state as History).moves.size() % 2

	## One move per branch under this position.
	func actions(state: RefCounted) -> Array:
		var here: Variant = _node(state)
		return range((here as Array).size()) if here is Array else []

	## The history with one more move.
	func result(state: RefCounted, action: Variant) -> RefCounted:
		return History.new((state as History).moves + [action])

	## Over at a number.
	func is_terminal(state: RefCounted) -> bool:
		return not (_node(state) is Array)

	## The leaf's number, for MAX; never asked for anything but a leaf here.
	func evaluate(state: RefCounted, _player: int) -> float:
		var here: Variant = _node(state)
		return 0.0 if here is Array else float(here)

	func _node(state: RefCounted) -> Variant:
		var here: Variant = tree
		for move: int in (state as History).moves:
			here = here[move]
		return here


## The moves made so far, which is all a state of the tree is.
class History extends RefCounted:
	var moves: Array = []

	func _init(made: Array) -> void:
		moves = made
