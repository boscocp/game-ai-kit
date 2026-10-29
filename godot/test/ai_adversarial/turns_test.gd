# T86: `AdversarialGame` no longer promises that the players alternate.
# Minimax and alpha-beta read `to_move` at every position instead, and a
# game without chance never has to write `outcomes`.
#
# The tree below is built so that a search assuming alternation gets it
# wrong. MAX plays `a` or `b`. After `a` it is MAX's turn *again*, between
# leaves worth 1 and 5, so `a` is worth 5. After `b`, MIN chooses between 4
# and 6, so `b` is worth 4. MAX plays `a`, worth 5. A search that took the
# second turn for MIN's would value `a` at 1 and play `b`.
extends GdUnitTestSuite

const MAX: int = 0
const MIN: int = 1
## Leaves as `[MAX's value, MIN's value]`: the two do not add up to zero.
const SHARED: Dictionary = {"player": MAX, "children": [
	{"player": MIN, "children": [[1.0, 1.0], [0.0, 0.0]]},
	[0.5, 0.5],
]}
const TWICE: Dictionary = {"player": MAX, "children": [
	{"player": MAX, "children": [1.0, 5.0]},
	{"player": MIN, "children": [4.0, 6.0]},
]}


func test_minimax_lets_a_side_move_twice_and_finds_five() -> void:
	var game := TurnTree.new(TWICE)
	var found: AdversarialResult = MinimaxSearch.new().search(game, game.root(), 3)
	assert_float(found.value).is_equal(5.0)
	assert_int(found.action).is_equal(0)
	assert_array(found.considered.map(func(entry: Dictionary) -> float: return entry["value"])).is_equal([5.0, 4.0])


func test_alpha_beta_agrees_when_a_side_moves_twice() -> void:
	var game := TurnTree.new(TWICE)
	var found: AdversarialResult = AlphaBetaSearch.new().search(game, game.root(), 3)
	assert_float(found.value).is_equal(5.0)
	assert_int(found.action).is_equal(0)


func test_mcts_also_credits_the_second_move_to_the_side_that_made_it() -> void:
	var game := TurnTree.new(TWICE)
	var found: MctsResult = MonteCarloSearch.new(game, game.root(), 3).step(200)
	assert_int(found.action).is_equal(0)


func test_mcts_credits_each_chooser_with_its_own_value_not_the_opposite() -> void:
	# Not zero-sum: after `a`, MIN picks between a leaf worth 1 to both and
	# one worth 0 to both, and takes the 1, so `a` is worth 1 to MAX -- more
	# than `b`'s 0.5. A search that gave MIN the negation of MAX's value
	# would take the 0, and play `b`.
	var game := TurnTree.new(SHARED)
	assert_int(MonteCarloSearch.new(game, game.root(), 3).step(300).action).is_equal(0)


func test_a_game_without_chance_has_one_certain_outcome() -> void:
	var game := TurnTree.new(TWICE)
	var outcomes: Array = game.outcomes(game.root(), 1)
	assert_int(outcomes.size()).is_equal(1)
	assert_float(outcomes[0]["probability"]).is_equal(1.0)
	assert_array((outcomes[0]["state"] as Path).moves).is_equal([1])


## A tree whose positions say who moves: `{"player", "children"}`, or a
## number for a leaf, worth that much to MAX and its opposite to MIN, or a
## pair, each player's own value.
class TurnTree extends AdversarialGame:
	var tree: Dictionary

	func _init(written: Dictionary) -> void:
		tree = written

	## The empty path.
	func root() -> RefCounted:
		return Path.new([])

	## Whoever the position names.
	func to_move(state: RefCounted) -> int:
		var here: Variant = _node(state)
		return here["player"] if here is Dictionary else MAX

	## One action per child.
	func actions(state: RefCounted) -> Array:
		var here: Variant = _node(state)
		return range((here["children"] as Array).size()) if here is Dictionary else []

	## The path one step longer.
	func result(state: RefCounted, action: Variant) -> RefCounted:
		return Path.new((state as Path).moves + [action])

	## Over at a number.
	func is_terminal(state: RefCounted) -> bool:
		return not (_node(state) is Dictionary)

	## The leaf's number for MAX, its opposite for MIN, or the pair's own
	## value; 0 above the leaves.
	func evaluate(state: RefCounted, player: int) -> float:
		var here: Variant = _node(state)
		if here is Array:
			return float(here[player])
		var for_max: float = 0.0 if here is Dictionary else float(here)
		return for_max if player == MAX else -for_max

	func _node(state: RefCounted) -> Variant:
		var here: Variant = tree
		for move: int in (state as Path).moves:
			here = here["children"][move]
		return here


## The moves made so far, which is all a position of the tree is.
class Path extends RefCounted:
	var moves: Array = []

	func _init(made: Array) -> void:
		moves = made
