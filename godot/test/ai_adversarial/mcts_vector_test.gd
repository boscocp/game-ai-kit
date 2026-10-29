# The rules `MctsVector` holds a vector to, each with a planted case it must
# refuse, and the planted search the task asks for: a twin with one draw out
# of order must fail the vectors (T86). Read from spec/, so these break the
# day the vectors move -- which is when they should.
extends GdUnitTestSuite

func test_the_addon_meets_every_claim() -> void:
	for name: String in ["mcts-nim.json", "mcts-dice-race.json"]:
		var vector: Dictionary = _read(name)
		assert_str(MctsVector.why_not_a_vector(vector)).is_empty()
		assert_array(MctsVector.wrong_claims(vector, MctsVector.addon_search())).is_empty()
	assert_array(MctsVector.wrong_draws(_read("xorshift.json"))).is_empty()


func test_a_search_with_one_draw_out_of_order_fails_both_games() -> void:
	var planted: Callable = func(game: AdversarialGame, state: RefCounted, from_seed: int,
			exploration: float, limit: int) -> MonteCarloSearch:
		return OutOfOrder.new(game, state, from_seed, exploration, limit)
	for name: String in ["mcts-nim.json", "mcts-dice-race.json"]:
		assert_array(MctsVector.wrong_claims(_read(name), planted)).is_not_empty()


func test_a_generator_that_drew_differently_fails_the_draws() -> void:
	var vector: Dictionary = _read("xorshift.json")
	var case: Dictionary = (vector["cases"][0] as Dictionary).duplicate()
	case["draws"] = [270369, 67634689, 1]
	assert_array(MctsVector.wrong_draws({"cases": [case]})).is_not_empty()


func test_a_broken_vector_is_refused() -> void:
	var vector: Dictionary = _read("mcts-nim.json")
	var first: Dictionary = vector["cases"][0]
	var without_game: Dictionary = vector.duplicate()
	without_game.erase("game")
	assert_str(MctsVector.why_not_a_vector(without_game)).starts_with("A1")
	assert_str(MctsVector.why_not_a_vector(_with(vector, "game", "checkers"))).starts_with("A2")
	assert_str(MctsVector.why_not_a_vector(_with(vector, "cases", []))).starts_with("A3")
	assert_str(MctsVector.why_not_a_vector(_with(vector, "cases", [_with(first, "seeds", 1)]))).starts_with("A4")
	assert_str(MctsVector.why_not_a_vector(_with(vector, "cases", [_with(first, "means", [])]))).starts_with("A5")
	assert_str(MctsVector.why_not_a_vector(_with(vector, "cases", [_with(first, "steps", [4])]))).starts_with("A6")


func test_a_wrong_mean_or_move_is_caught_even_when_the_visits_agree() -> void:
	var vector: Dictionary = _read("mcts-nim.json")
	var first: Dictionary = vector["cases"][0]
	assert_array(MctsVector.wrong_claims(_with(vector, "cases", [_with(first, "means", [0.5])]),
			MctsVector.addon_search())).is_not_empty()
	assert_array(MctsVector.wrong_claims(_with(vector, "cases", [_with(first, "action", 2.0)]),
			MctsVector.addon_search())).is_not_empty()


func _read(name: String) -> Dictionary:
	var path: String = ProjectSettings.globalize_path("res://").path_join("../spec/vectors/adversarial").path_join(name)
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _with(dictionary: Dictionary, key: String, value: Variant) -> Dictionary:
	var changed: Dictionary = dictionary.duplicate()
	changed[key] = value
	return changed


## A planted search: its playout draws the outcome's number before the move.
## The same draws, one of them out of place -- the mistake a port makes when
## it reads the pseudocode instead of the other file.
class OutOfOrder extends MonteCarloSearch:
	func _init(game: AdversarialGame, state: RefCounted, from_seed: int, exploration: float,
			limit: int) -> void:
		super(game, state, from_seed, exploration, limit)

	func _simulate(state: RefCounted) -> RefCounted:
		var played: int = 0
		while played < _playout_limit and not _game.is_terminal(state):
			var early: float = _random.uniform()
			var actions: Array = _game.actions(state)
			var outcomes: Array = _game.outcomes(state, actions[_random.index(actions.size())])
			state = outcomes[_face(outcomes, early)]["state"]
			played += 1
		return state

	func _face(outcomes: Array, drawn: float) -> int:
		var reached: float = 0.0
		for index: int in range(outcomes.size()):
			reached += float(outcomes[index]["probability"])
			if drawn < reached:
				return index
		return outcomes.size() - 1
