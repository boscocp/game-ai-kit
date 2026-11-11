# The rules `ExpectiminimaxVector` holds a vector to, each with a planted
# case it must refuse, and planted searches: one that sees no dice -- it
# reads `result`, as minimax does -- and one a ply short must fail the
# vectors (T88). Read from spec/, so these break the day the vectors move.
extends GdUnitTestSuite

const FILE: String = "expectiminimax-dice-race.json"


func test_the_addon_meets_every_claim() -> void:
	var vector: Dictionary = _read()
	assert_str(ExpectiminimaxVector.why_not_a_vector(vector)).is_empty()
	assert_array(ExpectiminimaxVector.wrong_claims(vector, ExpectiminimaxVector.addon_search())).is_empty()


func test_a_search_that_sees_no_dice_fails() -> void:
	var planted: Callable = func(game: GakAdversarialGame, state: RefCounted, depth: int) -> AdversarialResult:
		return MinimaxSearch.new().search(game, state, depth)
	assert_array(ExpectiminimaxVector.wrong_claims(_read(), planted)).is_not_empty()


func test_a_search_one_ply_short_fails() -> void:
	var planted: Callable = func(game: GakAdversarialGame, state: RefCounted, depth: int) -> AdversarialResult:
		return ExpectiminimaxSearch.new(game, state).search_to(depth - 1)
	assert_array(ExpectiminimaxVector.wrong_claims(_read(), planted)).is_not_empty()


func test_a_broken_vector_is_refused() -> void:
	var vector: Dictionary = _read()
	var first: Dictionary = vector["cases"][0]
	var without_game: Dictionary = vector.duplicate()
	without_game.erase("game")
	assert_str(ExpectiminimaxVector.why_not_a_vector(without_game)).starts_with("E1")
	assert_str(ExpectiminimaxVector.why_not_a_vector(_with(vector, "game", "nim"))).starts_with("E2")
	assert_str(ExpectiminimaxVector.why_not_a_vector(_with(vector, "cases", []))).starts_with("E3")
	assert_str(ExpectiminimaxVector.why_not_a_vector(_with(vector, "cases", [_with(first, "seed", 1)]))).starts_with("E4")
	assert_str(ExpectiminimaxVector.why_not_a_vector(_with(vector, "cases", [_with(first, "depth", 0)]))).starts_with("E5")


func test_a_wrong_value_move_or_count_is_caught() -> void:
	var vector: Dictionary = _read()
	var first: Dictionary = vector["cases"][0]
	var search: Callable = ExpectiminimaxVector.addon_search()
	var values: Array = (first["values"] as Array).duplicate()
	values[0] += 1e-6
	assert_array(ExpectiminimaxVector.wrong_claims(_with(vector, "cases", [_with(first, "values", values)]), search)).is_not_empty()
	assert_array(ExpectiminimaxVector.wrong_claims(_with(vector, "cases", [_with(first, "action", "walk")]), search)).is_not_empty()
	assert_array(ExpectiminimaxVector.wrong_claims(_with(vector, "cases", [_with(first, "positions", 1)]), search)).is_not_empty()


func _read() -> Dictionary:
	var path: String = ProjectSettings.globalize_path("res://").path_join("../spec/vectors/adversarial").path_join(FILE)
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _with(dictionary: Dictionary, key: String, value: Variant) -> Dictionary:
	var changed: Dictionary = dictionary.duplicate()
	changed[key] = value
	return changed


# T121: each of these, a list given as text in a copy of a real file, was
# a SCRIPT ERROR that skipped the check and let the runner exit 0.
func test_a_vector_of_the_wrong_types_is_refused_before_it_is_read() -> void:
	var vector: Dictionary = VectorShape.read_spec("vectors/adversarial/expectiminimax-dice-race.json")
	var paths: Array = [["cases"], ["cases", 0, "values"], ["cases", 0, "state", "squares"]]
	for path: Array in paths:
		var why: String = ExpectiminimaxVector.why_not_a_vector(VectorShape.planted(vector, path, "x"))
		assert_str(why).override_failure_message(str(path)).starts_with("E6")