# The rules `MctsVector` holds a vector to, each with a planted case it must
# refuse, and the planted searches the task asks for: twins whose draws
# differ from the addon's must fail the vectors (T86). Read from spec/, so these break the
# day the vectors move -- which is when they should.
extends GdUnitTestSuite

func test_the_addon_meets_every_claim() -> void:
	for name: String in ["mcts-nim.json", "mcts-dice-race.json"]:
		var vector: Dictionary = _read(name)
		assert_str(MctsVector.why_not_a_vector(vector)).is_empty()
		assert_array(MctsVector.wrong_claims(vector, MctsVector.addon_search())).is_empty()
	assert_array(MctsVector.wrong_draws(_read("xorshift.json"))).is_empty()


func test_a_search_with_a_spare_draw_fails_both_games() -> void:
	var planted: Callable = func(game: GakAdversarialGame, state: RefCounted, from_seed: int,
			exploration: float, limit: int) -> MonteCarloSearch:
		return SpareDraw.new(game, state, from_seed, exploration, limit)
	for name: String in ["mcts-nim.json", "mcts-dice-race.json"]:
		assert_array(MctsVector.wrong_claims(_read(name), planted)).is_not_empty()


func test_a_search_with_the_same_draws_read_differently_fails_both_games() -> void:
	var planted: Callable = func(game: GakAdversarialGame, state: RefCounted, from_seed: int,
			exploration: float, limit: int) -> MonteCarloSearch:
		return MirroredExpansion.new(game, state, from_seed, exploration, limit)
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


## A planted search with a spare draw: its playout draws an outcome's number
## before every move, even when the move turns out to have one outcome. On
## Nim that breaks rule 1 of the vectors' README (a draw only on a real
## choice); on the dice race, rules 1 and 5. A twin that broke rule 5 alone
## cannot be written: whether an outcome is drawn at all depends on the move
## the earlier draw chose, so putting the outcome's draw first changes how
## many draws there are. `MirroredExpansion` keeps the count instead.
class SpareDraw extends MonteCarloSearch:
	func _init(game: GakAdversarialGame, state: RefCounted, from_seed: int, exploration: float,
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


## A planted search with the same draws, in the same order, one of them read
## differently: expansion counts its drawn index from the other end of the
## untried moves -- rule 2 broken, nothing else.
class MirroredExpansion extends MonteCarloSearch:
	func _init(game: GakAdversarialGame, state: RefCounted, from_seed: int, exploration: float,
			limit: int) -> void:
		super(game, state, from_seed, exploration, limit)

	func _expand(leaf: TreeNode, descent: Descent) -> TreeNode:
		if leaf.terminal:
			return leaf
		var drawn: int = _random.index(leaf.untried.size())
		var index: int = leaf.untried.pop_at(leaf.untried.size() - 1 - drawn)
		var action: Variant = leaf.actions[index]
		var branch := Branch.new(action, leaf.player, _game.outcomes(leaf.state, action))
		leaf.branches[index] = branch
		descent.branches.append(branch)
		var child: TreeNode = _child_by_chance(branch)
		descent.nodes.append(child)
		return child


# T121: each of these, a list given as text in a copy of a real file, was
# a SCRIPT ERROR that skipped the check -- `draws` turned into a string, a
# review showed, let the runner exit 0.
func test_a_vector_of_the_wrong_types_is_refused_before_it_is_read() -> void:
	var vector: Dictionary = VectorShape.read_spec("vectors/adversarial/mcts-dice-race.json")
	var paths: Array = [["cases"], ["cases", 0, "visits"], ["cases", 0, "state", "squares"], ["cases", 0, "steps"]]
	for path: Array in paths:
		var why: String = MctsVector.why_not_a_vector(VectorShape.planted(vector, path, "x"))
		assert_str(why).override_failure_message(str(path)).starts_with("A7")
	var draws: Dictionary = VectorShape.read_spec("vectors/adversarial/xorshift.json")
	assert_str(VectorShape.why_not(draws, MctsVector.DRAWS_SHAPE)).is_empty()
	assert_str(VectorShape.why_not(VectorShape.planted(draws, ["cases", 0, "draws"], "x"), MctsVector.DRAWS_SHAPE)) \
			.is_not_empty()
