# T88: `ExpectiminimaxSearch` on trees small enough to work out by hand,
# chance nodes included; against minimax on a game without chance; and
# stopped and resumed, a position at a time, to the same answer.
extends GdUnitTestSuite

const MAX: int = 0
const MIN: int = 1
const NIM: Script = preload("res://test/ai_adversarial/nim_example.gd")
const DICE_RACE: Script = preload("res://test/ai_adversarial/dice_race.gd")

## AIMA 4th ed., section 5.5.1: MAX's two moves each lead to the dice, 0.9
## and 0.1. With leaves 2, 3 and 1, 4, the first move is worth 2.1 and the
## second 1.3. The same leaves in the same order, but 20, 30 and 1, 400,
## make the second worth more: an evaluation for a game of chance has to be
## right in its scale, not only in its order.
const BOOK: Dictionary = {"player": MAX, "moves": [
	{"chance": [[0.9, 2.0], [0.1, 3.0]]},
	{"chance": [[0.9, 1.0], [0.1, 4.0]]},
]}
const BOOK_RESCALED: Dictionary = {"player": MAX, "moves": [
	{"chance": [[0.9, 20.0], [0.1, 30.0]]},
	{"chance": [[0.9, 1.0], [0.1, 400.0]]},
]}
## MAX: `a` throws a coin, and on each side MIN chooses; `b` is a sure 0.8.
## `a` is 0.5 x 3 + 0.5 x -1 = 1, so MAX throws. Seen one ply deep, MIN's
## positions are not worked out (an unfinished position is worth 0 here),
## and the sure 0.8 wins: the answer changes with the depth.
const COIN: Dictionary = {"player": MAX, "moves": [
	{"chance": [[0.5, {"player": MIN, "moves": [3.0, 5.0]}], [0.5, {"player": MIN, "moves": [-1.0, 7.0]}]]},
	0.8,
]}

## A position that is not over and has no move, breaking the interface's
## promise: scored by `evaluate` (its estimate, 0.3), as at the cutoff, in
## both languages -- so `a` beats `b`'s 0.2.
const STUCK: Dictionary = {"player": MAX, "moves": [{"player": MIN, "moves": [], "estimate": 0.3}, 0.2]}


func test_a_position_with_no_move_is_scored_not_searched() -> void:
	var game := ChanceTree.new(STUCK)
	var found: AdversarialResult = ExpectiminimaxSearch.new(game, game.root()).search_to(3)
	assert_int(found.action).is_equal(0)
	assert_float(found.value).is_equal(0.3)


func test_the_books_example_takes_the_higher_expected_value() -> void:
	var game := ChanceTree.new(BOOK)
	var found: AdversarialResult = ExpectiminimaxSearch.new(game, game.root()).search_to(2)
	assert_int(found.action).is_equal(0)
	assert_float(found.considered[0]["value"]).is_equal_approx(2.1, 1e-12)
	assert_float(found.considered[1]["value"]).is_equal_approx(1.3, 1e-12)


func test_rescaling_the_leaves_without_reordering_them_changes_the_move() -> void:
	var game := ChanceTree.new(BOOK_RESCALED)
	var found: AdversarialResult = ExpectiminimaxSearch.new(game, game.root()).search_to(2)
	assert_int(found.action).is_equal(1)
	assert_float(found.value).is_equal_approx(40.9, 1e-12)


func test_min_chooses_under_each_outcome_and_the_outcomes_are_summed() -> void:
	var game := ChanceTree.new(COIN)
	var found: AdversarialResult = ExpectiminimaxSearch.new(game, game.root()).search_to(2)
	assert_int(found.action).is_equal(0)
	assert_float(found.value).is_equal(1.0)
	assert_array(found.considered[0]["outcomes"]).is_equal([
		{"probability": 0.5, "value": 3.0}, {"probability": 0.5, "value": -1.0}])
	assert_array(found.considered[1]["outcomes"]).is_equal([{"probability": 1.0, "value": 0.8}])
	assert_int(found.depth).is_equal(2)


func test_one_ply_deep_the_sure_thing_wins_and_two_plies_deep_the_coin() -> void:
	var game := ChanceTree.new(COIN)
	var search := ExpectiminimaxSearch.new(game, game.root())
	var shallow: AdversarialResult = null
	while shallow == null or shallow.depth < 1:
		shallow = search.step(1)
	assert_int(shallow.depth).is_equal(1)
	assert_int(shallow.action).is_equal(1)
	assert_int(search.search_to(2).action).is_equal(0)


func test_without_chance_it_is_minimax_value_for_value_and_position_for_position() -> void:
	var nim: GakAdversarialGame = NIM.new()
	var pile: RefCounted = NIM.Pile.new(7, 0)
	for depth: int in range(1, 6):
		var expected: AdversarialResult = MinimaxSearch.new().search(nim, pile, depth)
		var found: AdversarialResult = ExpectiminimaxSearch.new(nim, pile).search_to(depth)
		assert_int(found.action).is_equal(expected.action)
		assert_int(found.positions).is_equal(expected.positions)
		assert_array(_values(found)).is_equal(_values(expected))


func test_a_position_at_a_time_reaches_the_same_answer_as_all_at_once() -> void:
	var race: GakAdversarialGame = DICE_RACE.new()
	var start: RefCounted = DICE_RACE.Race.new([1, 2] as Array[int], 0)
	var whole: AdversarialResult = ExpectiminimaxSearch.new(race, start).search_to(3)
	var stepped := ExpectiminimaxSearch.new(race, start, 3)
	var depths: Array[int] = []
	var by_depth: Dictionary = {}
	while not stepped.is_complete():
		var found: AdversarialResult = stepped.step(1)
		# At every step, the answer is a finished depth's, whole: never the
		# partial answer of the depth under way, whatever its label.
		if found.depth > 0 and not by_depth.has(found.depth):
			by_depth[found.depth] = ExpectiminimaxSearch.new(race, start).search_to(found.depth)
		if found.depth > 0:
			assert_array(_values(found)).is_equal(_values(by_depth[found.depth]))
		if depths.is_empty() or depths.back() != found.depth:
			depths.append(found.depth)
	assert_array(depths).is_equal([0, 1, 2, 3])
	assert_array(_values(stepped.result())).is_equal(_values(whole))
	assert_int(stepped.result().positions).is_equal(whole.positions)


func test_a_roll_is_worth_its_three_faces_by_their_chances() -> void:
	var race: GakAdversarialGame = DICE_RACE.new()
	var found: AdversarialResult = ExpectiminimaxSearch.new(race, DICE_RACE.Race.new([4, 5] as Array[int], 0)).search_to(2)
	var roll: Dictionary = found.considered[1]
	var chances: Array = roll["outcomes"].map(func(outcome: Dictionary) -> float: return outcome["probability"])
	assert_array(chances).is_equal([0.5, 0.25, 0.25])
	var summed: float = 0.0
	for outcome: Dictionary in roll["outcomes"]:
		summed += outcome["probability"] * outcome["value"]
	assert_float(roll["value"]).is_equal(summed)


func test_it_stops_deepening_once_every_line_has_ended() -> void:
	var nim: GakAdversarialGame = NIM.new()
	var search := ExpectiminimaxSearch.new(nim, NIM.Pile.new(3, 0))
	var found: AdversarialResult = search.step(100000)
	assert_bool(search.is_complete()).is_true()
	assert_int(found.depth).is_equal(3)
	assert_int(found.action).is_equal(3)
	assert_float(found.value).is_equal(1.0)


func test_before_depth_one_there_is_no_answer_and_a_finished_game_has_none() -> void:
	var game := ChanceTree.new(COIN)
	var fresh := ExpectiminimaxSearch.new(game, game.root())
	assert_object(fresh.result().action).is_null()
	assert_int(fresh.result().depth).is_equal(0)
	var nim: GakAdversarialGame = NIM.new()
	var over := ExpectiminimaxSearch.new(nim, NIM.Pile.new(0, 0))
	assert_bool(over.is_complete()).is_true()
	assert_object(over.step(10).action).is_null()
	assert_float(over.result().value).is_equal(-1.0)


func test_the_work_counts_every_depth_and_the_result_only_its_own() -> void:
	var race: GakAdversarialGame = DICE_RACE.new()
	var search := ExpectiminimaxSearch.new(race, DICE_RACE.Race.new([0, 0] as Array[int], 0), 2)
	var found: AdversarialResult = search.step(100000)
	var one_deep: int = ExpectiminimaxSearch.new(race, DICE_RACE.Race.new([0, 0] as Array[int], 0)).search_to(1).positions
	assert_int(search.positions_visited()).is_equal(one_deep + found.positions)


static func _values(found: AdversarialResult) -> Array:
	return found.considered.map(func(entry: Dictionary) -> float: return entry["value"])


## A tree written out: a position is `{"player", "moves"}`; a move is a
## position, a number -- a leaf, worth that to MAX and its opposite to MIN
## -- or `{"chance": [[probability, what it leads to], ...]}`. Above the
## leaves a position is worth 0, so a search cut short sees nothing there.
class ChanceTree extends GakAdversarialGame:
	var tree: Dictionary

	func _init(written: Dictionary) -> void:
		tree = written

	## The empty path.
	func root() -> RefCounted:
		return Steps.new([])

	## Whoever the position names.
	func to_move(state: RefCounted) -> int:
		var here: Variant = _node(state)
		return here["player"] if here is Dictionary else MAX

	## One action per move.
	func actions(state: RefCounted) -> Array:
		var here: Variant = _node(state)
		return range((here["moves"] as Array).size()) if here is Dictionary else []

	## The first outcome, for a search with no dice.
	func result(state: RefCounted, action: Variant) -> RefCounted:
		return outcomes(state, action)[0]["state"]

	## Each side of the dice, or the one certain position.
	func outcomes(state: RefCounted, action: Variant) -> Array:
		var move: Variant = _node(state)["moves"][action]
		var path: Array = (state as Steps).taken
		if move is Dictionary and move.has("chance"):
			var found: Array = []
			for index: int in range((move["chance"] as Array).size()):
				found.append({"probability": move["chance"][index][0], "state": Steps.new(path + [[action, index]])})
			return found
		return [{"probability": 1.0, "state": Steps.new(path + [[action, -1]])}]

	## Over at a number.
	func is_terminal(state: RefCounted) -> bool:
		return not (_node(state) is Dictionary)

	## The leaf's number for MAX, its opposite for MIN; above the leaves,
	## the position's `estimate`, or 0.
	func evaluate(state: RefCounted, player: int) -> float:
		var here: Variant = _node(state)
		var for_max: float = float(here.get("estimate", 0.0)) if here is Dictionary else float(here)
		return for_max if player == MAX else -for_max

	func _node(state: RefCounted) -> Variant:
		var here: Variant = tree
		for taken: Array in (state as Steps).taken:
			here = here["moves"][taken[0]]
			if taken[1] >= 0:
				here = here["chance"][taken[1]][1]
		return here


## The moves made and the sides the dice fell on, which is all a position
## of the tree is: `[move, outcome]` each, the outcome -1 for a sure move.
class Steps extends RefCounted:
	var taken: Array = []

	func _init(made: Array) -> void:
		taken = made
