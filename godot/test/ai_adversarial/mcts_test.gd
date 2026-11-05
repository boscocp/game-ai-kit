# What `MonteCarloSearch` must do apart from agreeing with Python (T86).
#
# The vectors hold the two languages to one another, and would pass two
# searches wrong the same way. These hold the search to the games: the dice
# race's obvious choices at the end, the tree's shape under chance, anytime
# steps, and the bound T87 will draw. Nim's winning play is
# `nim_example_test.gd`'s; a step's cost is `make test-mcts-budget`'s, apart,
# because a clock flakes under load.
extends GdUnitTestSuite

const DICE_RACE: Script = preload("res://test/ai_adversarial/dice_race.gd")
const EXAMPLE_NIM: Script = preload("res://test/ai_adversarial/nim_example.gd")
## The seed whose first draw is exactly 2^31, found by running the three
## steps of `Xorshift.next` backwards from it.
const BOUNDARY_SEED: int = 2281717760


## A coin that lands heads one time in five, and then one move: "a" after
## heads, "b" after tails. Its only use is a line that must follow the
## outcome drawn most, which a game without chance cannot tell apart from
## the first outcome.
class Coin extends GakAdversarialGame:
	class Spot extends RefCounted:
		var at: String
		func _init(where: String) -> void:
			at = where

	func to_move(_state: RefCounted) -> int:
		return 0

	func actions(state: RefCounted) -> Array:
		match (state as Spot).at:
			"start":
				return ["flip"]
			"heads":
				return ["a"]
			"tails":
				return ["b"]
		return []

	func result(state: RefCounted, _action: Variant) -> RefCounted:
		return Spot.new("tails" if (state as Spot).at == "start" else "end")

	func outcomes(state: RefCounted, action: Variant) -> Array:
		if (state as Spot).at != "start":
			return super.outcomes(state, action)
		return [{"probability": 0.2, "state": Spot.new("heads")}, {"probability": 0.8, "state": Spot.new("tails")}]

	func is_terminal(state: RefCounted) -> bool:
		return (state as Spot).at == "end"

	func evaluate(_state: RefCounted, _player: int) -> float:
		return 0.0


func test_stopped_in_two_steps_it_is_the_search_run_in_one() -> void:
	var sliced := MonteCarloSearch.new(DICE_RACE.new(), _race(0, 0, 0), 4)
	sliced.step(70)
	var twice: MctsResult = sliced.step(130)
	var once: MctsResult = MonteCarloSearch.new(DICE_RACE.new(), _race(0, 0, 0), 4).step(200)
	assert_array(twice.considered).is_equal(once.considered)
	assert_int(twice.iterations).is_equal(200)


func test_it_has_an_answer_at_once_and_of_equal_visits_the_first() -> void:
	# Anytime: before any iteration, and after one iteration per move, every
	# move is tied, and the answer is the first the game listed.
	var search := MonteCarloSearch.new(EXAMPLE_NIM.new(), EXAMPLE_NIM.Pile.new(10, 0), 1)
	assert_int(search.result().action).is_equal(1)
	var found: MctsResult = search.step(3)
	assert_int(found.action).is_equal(1)
	assert_array(found.considered.map(func(entry: Dictionary) -> int: return entry["visits"])).is_equal([1, 1, 1])


func test_one_square_from_home_it_walks_and_behind_it_rolls() -> void:
	assert_str(MonteCarloSearch.new(DICE_RACE.new(), _race(5, 0, 0), 2).step(300).action).is_equal("walk")
	# Walking to 5 hands the opponent, also on 5, a certain win; a roll wins
	# half the time.
	assert_str(MonteCarloSearch.new(DICE_RACE.new(), _race(4, 5, 0), 2).step(300).action).is_equal("roll")


func test_a_roll_keeps_one_child_per_face_and_a_walk_one() -> void:
	var search := MonteCarloSearch.new(DICE_RACE.new(), _race(0, 0, 0), 6)
	search.step(300)
	var walk: MonteCarloSearch.Branch = search._root.branches[0]
	var roll: MonteCarloSearch.Branch = search._root.branches[1]
	assert_int(walk.children.filter(func(child: Variant) -> bool: return child != null).size()).is_equal(1)
	assert_int(roll.children.filter(func(child: Variant) -> bool: return child != null).size()).is_equal(3)
	var under_roll: int = 0
	for child: MonteCarloSearch.TreeNode in roll.children:
		under_roll += child.visits
	assert_int(roll.visits).is_equal(under_roll)
	# A four plays again: that child is still the same runner's turn.
	assert_int((roll.children[2] as MonteCarloSearch.TreeNode).player).is_equal(0)
	assert_int((roll.children[0] as MonteCarloSearch.TreeNode).player).is_equal(1)


func test_every_root_move_is_reported_and_one_never_tried_is_unbounded() -> void:
	var found: MctsResult = MonteCarloSearch.new(EXAMPLE_NIM.new(), EXAMPLE_NIM.Pile.new(10, 0), 1).step(2)
	assert_int(found.considered.size()).is_equal(3)
	var never_tried: Array = found.considered.filter(func(entry: Dictionary) -> bool: return entry["visits"] == 0)
	assert_int(never_tried.size()).is_equal(1)
	assert_float(never_tried[0]["bound"]).is_equal(INF)


func test_a_finished_game_is_not_searched() -> void:
	var found: MctsResult = MonteCarloSearch.new(EXAMPLE_NIM.new(), EXAMPLE_NIM.Pile.new(0, 1), 1).step(50)
	assert_that(found.action).is_null()
	assert_int(found.considered.size()).is_equal(0)
	assert_int(found.iterations).is_equal(0)


func test_a_visited_root_move_reports_its_ucb1_bound() -> void:
	# The bound is what T87 draws: mean + C * sqrt(ln(root visits) / visits),
	# the root visited once an iteration.
	var found: MctsResult = MonteCarloSearch.new(DICE_RACE.new(), _race(0, 0, 0), 2).step(150)
	var spread: float = log(float(found.iterations))
	for entry: Dictionary in found.considered:
		var bonus: float = MonteCarloSearch.EXPLORATION * sqrt(spread / entry["visits"])
		assert_float(entry["bound"]).is_equal_approx(entry["mean"] + bonus, 1e-12)


func test_a_drawn_number_on_a_boundary_falls_in_the_next_outcome() -> void:
	# BOUNDARY_SEED draws exactly 2^31 first, so the uniform is exactly
	# 0.5: not below the first outcome's 0.5, below the running 0.75.
	assert_int(Xorshift.new(BOUNDARY_SEED).next()).is_equal(2147483648)
	var search := MonteCarloSearch.new(DICE_RACE.new(), _race(0, 0, 0), BOUNDARY_SEED)
	var faces: Array = DICE_RACE.new().outcomes(_race(0, 0, 0), "roll")
	assert_int(search._draw_outcome(faces)).is_equal(1)


func _race(first: int, second: int, player: int) -> RefCounted:
	var squares: Array[int] = [first, second]
	return DICE_RACE.Race.new(squares, player)


func test_the_principal_line_follows_the_outcome_drawn_most_not_the_first() -> void:
	var search := MonteCarloSearch.new(Coin.new(), Coin.Spot.new("start"), 3)
	search.step(200)
	assert_array(search.principal_line()).is_equal(["flip", "b"])


func test_the_principal_line_starts_with_the_answer_and_follows_the_most_visited() -> void:
	var search := MonteCarloSearch.new(EXAMPLE_NIM.new(), EXAMPLE_NIM.Pile.new(7, 0), 1)
	assert_array(search.principal_line()).is_empty()
	var found: MctsResult = search.step(1000)
	var line: Array = search.principal_line(3)
	assert_int(line.size()).is_equal(3)
	assert_int(line[0]).is_equal(found.action)
	var root: MonteCarloSearch.TreeNode = search._root
	var first: MonteCarloSearch.Branch = root.branches[found.action - 1]
	var after: MonteCarloSearch.TreeNode = first.children[0]
	var most: int = 0
	for branch: Variant in after.branches:
		most = maxi(most, branch.visits if branch != null else 0)
	assert_int((after.branches[line[1] - 1] as MonteCarloSearch.Branch).visits).is_equal(most)
