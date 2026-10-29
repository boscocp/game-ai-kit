# What `MonteCarloSearch` must do apart from agreeing with Python (T86).
#
# The vectors hold the two languages to one another, and would pass two
# searches wrong the same way. These hold the search to the games: the dice
# race's obvious choices at the end, the tree's shape under chance, anytime
# steps, and a step's cost. Nim's winning play is `nim_example_test.gd`'s.
extends GdUnitTestSuite

const DICE_RACE: Script = preload("res://test/ai_adversarial/dice_race.gd")
const EXAMPLE_NIM: Script = preload("res://test/ai_adversarial/nim_example.gd")
## A frame at 60 frames a second, in microseconds. The test below asks a
## step of `ITERATIONS_PER_FRAME` to take half of it at most, the share
## `FrameBudget` gives all of an RTS's AI together.
const FRAME_USEC: int = 16667
const ITERATIONS_PER_FRAME: int = 100


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


func test_the_generator_starts_where_marsaglia_starts_and_zero_is_one() -> void:
	assert_int(Xorshift.new(1).next()).is_equal(270369)
	assert_int(Xorshift.new(0).next()).is_equal(270369)
	var drawn := Xorshift.new(9)
	for _forced: int in range(5):
		assert_int(drawn.index(1)).is_equal(0)
	assert_int(drawn.next()).is_equal(Xorshift.new(9).next())


func test_a_frame_of_iterations_fits_in_half_a_frame() -> void:
	# Measured, not assumed: the mean step of ITERATIONS_PER_FRAME on the
	# dice race from the start, over twenty frames of one growing tree.
	var search := MonteCarloSearch.new(DICE_RACE.new(), _race(0, 0, 0), 1)
	var started: int = Time.get_ticks_usec()
	for _frame: int in range(20):
		search.step(ITERATIONS_PER_FRAME)
	var mean_usec: int = (Time.get_ticks_usec() - started) / 20
	assert_int(mean_usec).override_failure_message(
		"a step of %d took %d us on average" % [ITERATIONS_PER_FRAME, mean_usec]).is_less(FRAME_USEC / 2)


func _race(first: int, second: int, player: int) -> RefCounted:
	var squares: Array[int] = [first, second]
	return DICE_RACE.Race.new(squares, player)
