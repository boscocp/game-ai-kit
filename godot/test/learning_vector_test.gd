# A planted case for every rule `LearningVector` has.
#
# The wave before this one found nine rules in the planning vector type with
# no planted case at all: deleting any of them left the whole repository
# green, under a header claiming the opposite. `lint-selftests` cannot help
# here -- it only looks inside `scripts/`, and this is GDScript -- so this
# file is the only thing standing between a conformance runner and a rule
# that has quietly stopped being applied.
extends GdUnitTestSuite

const CONVENTIONS: Dictionary = {
	"nearby_radius": 2,
	"reinforcement_distance_when_alone": 15,
	"cheapest_ground": 1,
	"dearest_ground": 3,
}


func test_a_sound_vector_is_accepted_and_claims_nothing_false() -> void:
	assert_str(LearningVector.why_not_a_vector(_sound())).is_empty()
	assert_array(LearningVector.check("sound", _sound())).is_empty()


func test_a_vector_with_no_cases_claims_nothing_and_is_refused() -> void:
	# The failure this whole family is arranged against: a conformance file
	# that inspects nothing and reports success.
	assert_str(LearningVector.why_not_a_vector(_but({"cases": []}))).contains("V1")


func test_a_vector_with_no_models_is_refused_in_the_loader_s_own_words() -> void:
	assert_str(LearningVector.why_not_a_vector(_but({"models": {}}))).contains("M3")


func test_a_vector_with_no_conventions_is_refused() -> void:
	var data: Dictionary = _sound()
	data.erase("feature_conventions")

	assert_str(LearningVector.why_not_a_vector(data)).contains("M9")


func test_a_case_of_an_unknown_kind_is_refused() -> void:
	assert_str(_why_one_case_is_wrong({"kind": "vibes"})).contains("V2")


func test_a_case_that_is_not_an_object_is_refused() -> void:
	assert_str(LearningVector.why_not_a_vector(_but({"cases": ["nearly"]}))).contains("V2")


func test_a_case_with_no_features_is_refused() -> void:
	assert_str(_why_one_case_is_wrong({"features": {}})).contains("V3")


func test_a_case_claiming_no_prediction_is_refused() -> void:
	# A case with no answer in it passes whatever the model says, which is
	# the same as not having written the case.
	var case: Dictionary = _row_case()
	case.erase("prediction")

	assert_str(LearningVector.why_not_a_vector(_but({"cases": [case]}))).contains("V4")


func test_a_prediction_that_is_not_a_number_is_refused() -> void:
	assert_str(_why_one_case_is_wrong({"prediction": "about a half"})).contains("V4")


func test_a_case_that_does_not_say_what_it_is_for_is_refused() -> void:
	# Both halves require it now. Python read `case["why"]` and raised a
	# KeyError naming a dictionary key rather than the vector; this side
	# defaulted and said nothing.
	var case: Dictionary = _row_case()
	case.erase("why")

	assert_str(LearningVector.why_not_a_vector(_but({"cases": [case]}))).contains("V10")


func test_a_case_whose_reason_is_blank_is_refused_too() -> void:
	assert_str(_why_one_case_is_wrong({"why": "   "})).contains("V10")


func test_a_case_about_a_model_the_vector_does_not_publish_is_refused() -> void:
	assert_str(_why_one_case_is_wrong({"model": "random_forest"})).contains("V5")


func test_a_case_that_reads_a_board_when_there_is_none_is_refused() -> void:
	var data: Dictionary = _sound()
	data.erase("board")

	assert_str(LearningVector.why_not_a_vector(data)).contains("V6")


func test_a_board_that_is_not_an_object_is_refused() -> void:
	# One of four rules review found deletable with the suite green, in a file
	# whose header says every rule here has a planted case.
	assert_str(LearningVector.why_not_a_vector(
		_but({"board": "three by three"}))).contains("`board` is not an object")


func test_a_board_with_no_cells_at_all_is_refused() -> void:
	# Width *and* height: with only the width zeroed, the row-count rule
	# catches it first and this case would be passing on somebody else's
	# work -- which is what it was doing when it was written.
	assert_str(_why_the_board_is_wrong(
		{"width": 0, "height": 0, "costs": []})).contains("holds nothing")


func test_a_unit_that_is_not_an_object_is_refused() -> void:
	assert_str(_why_the_board_is_wrong(
		{"units": [_unit(1, 0, 0, 0), "a soldier"]})).contains("a unit is not an object")


func test_a_prediction_that_is_an_infinity_is_refused() -> void:
	# JSON cannot spell one and `1e400` parses to one. A case claiming INF
	# passes any model that also answers INF, which is every model with an
	# infinite bias -- and the weights file is the only thing refusing those.
	assert_str(_why_one_case_is_wrong({"prediction": INF})).contains("V4")


func test_a_board_missing_a_field_is_refused() -> void:
	var board: Dictionary = _board()
	board.erase("costs")

	assert_str(LearningVector.why_not_a_vector(
		_but({"board": board}))).contains("has no `costs`")


func test_a_board_with_the_wrong_number_of_cost_rows_is_refused() -> void:
	assert_str(_why_the_board_is_wrong({"costs": [[1, 1, 1]]})).contains("rows")


func test_a_row_of_costs_of_the_wrong_width_is_refused() -> void:
	assert_str(_why_the_board_is_wrong(
		{"costs": [[1, 1, 1], [1, 1], [1, 1, 1]]})).contains("entries")


func test_a_board_with_nothing_on_it_is_refused() -> void:
	assert_str(_why_the_board_is_wrong({"units": []})).contains("no units on it")


func test_two_units_sharing_an_id_are_refused() -> void:
	# `unit_by_id` answers with the first, so the second could never be named
	# by a case -- and the case naming the id would quietly be about the
	# other unit.
	assert_str(_why_the_board_is_wrong({"units": [
		_unit(1, 0, 0, 0), _unit(1, 1, 1, 0),
	]})).contains("share the id")


func test_two_units_on_one_cell_are_refused() -> void:
	assert_str(_why_the_board_is_wrong({"units": [
		_unit(1, 0, 0, 0), _unit(2, 1, 0, 0),
	]})).contains("stand on")


func test_a_unit_standing_off_the_board_is_refused() -> void:
	assert_str(_why_the_board_is_wrong({"units": [
		_unit(1, 0, 0, 0), _unit(2, 1, 7, 7),
	]})).contains("off the board")


func test_a_unit_with_no_health_is_refused() -> void:
	# A state drops the dead on the way in, so such a unit would vanish and
	# every feature counted from it would be a different number.
	var dead: Dictionary = _unit(2, 1, 1, 0)
	dead["health"] = 0

	assert_str(_why_the_board_is_wrong(
		{"units": [_unit(1, 0, 0, 0), dead]})).contains("no health")


func test_a_fight_naming_a_unit_that_is_not_there_is_refused() -> void:
	assert_str(_why_one_case_is_wrong(_combat_case({"defender": 9}))).contains("V8")


func test_a_unit_fighting_itself_is_refused() -> void:
	assert_str(_why_one_case_is_wrong(_combat_case({"defender": 1}))).contains("V8")


func test_a_run_at_no_node_at_all_is_refused() -> void:
	assert_str(_why_one_case_is_wrong(_capture_case({"node": [2]}))).contains("V9")


func test_a_run_by_a_side_that_is_not_on_the_board_is_refused() -> void:
	assert_str(_why_one_case_is_wrong(_capture_case({"faction": 7}))).contains("V9")


func test_a_feature_the_board_disagrees_with_is_reported() -> void:
	var case: Dictionary = _combat_case()
	case["features"]["defender_terrain"] = 3

	assert_str(_one_failure({"cases": [case]})).contains("C1")


func test_a_feature_the_vector_does_not_mention_is_reported() -> void:
	# Both directions. A vector quietly dropping a feature would hold the two
	# languages to three numbers out of four for as long as nobody noticed.
	var case: Dictionary = _combat_case()
	case["features"].erase("reinforcement_distance")

	assert_str(_one_failure({"cases": [case]})).contains("C1")


func test_a_prediction_the_model_disagrees_with_is_reported() -> void:
	var case: Dictionary = _row_case()
	case["prediction"] = 0.4

	assert_str(_one_failure({"cases": [case]})).contains("C2")


func test_a_prediction_inside_the_tolerance_is_not_reported() -> void:
	# The margin is for the last places of a double, and nothing wider. A
	# vector out by a thousandth is a vector that disagrees.
	var near: Dictionary = _row_case()
	near["prediction"] = 0.5 + 1e-12
	assert_array(LearningVector.check("near", _but({"cases": [near]}))).is_empty()

	var adrift: Dictionary = _row_case()
	adrift["prediction"] = 0.501
	assert_array(LearningVector.check("adrift", _but({"cases": [adrift]}))).has_size(1)


# A vector with nothing wrong with it: one row, one fight, one run at a node.
func _sound() -> Dictionary:
	return {
		"name": "a sound vector",
		"feature_conventions": CONVENTIONS.duplicate(true),
		"models": {"combat": _combat_model(), "capture": _capture_model()},
		"board": _board(),
		"cases": [_row_case(), _combat_case(), _capture_case()],
	}


# Both models answer the same thing whatever they are shown, so every number
# in a case below can be read off the board rather than worked out.
func _combat_model() -> Dictionary:
	return {
		"kind": "logistic",
		"features": ["health_difference", "numeric_advantage",
			"defender_terrain", "reinforcement_distance"],
		"weights": [0.0, 0.0, 0.0, 0.0],
		"bias": 0.0,
	}


func _capture_model() -> Dictionary:
	return {
		"kind": "linear",
		"features": ["distance_to_node", "own_units", "enemy_units",
			"terrain_on_the_way"],
		"weights": [0.0, 0.0, 0.0, 0.0],
		"bias": 2.0,
	}


# The sound vector with something replaced.
func _but(changed: Dictionary) -> Dictionary:
	var data: Dictionary = _sound()
	data.merge(changed, true)
	return data


# A flat three by three with one unit a side, which makes every feature
# countable by eye.
func _board() -> Dictionary:
	return {
		"width": 3,
		"height": 3,
		"costs": [[1, 1, 1], [1, 1, 1], [1, 1, 1]],
		"units": [_unit(1, 0, 0, 0), _unit(2, 1, 1, 0)],
	}


func _unit(id: int, faction: int, x: int, y: int) -> Dictionary:
	return {"id": id, "faction": faction, "x": x, "y": y, "health": 10}


func _row_case(changed: Dictionary = {}) -> Dictionary:
	var case: Dictionary = {
		"kind": "row", "model": "combat", "why": "a row handed straight over",
		"features": {
			"health_difference": 0, "numeric_advantage": 0,
			"defender_terrain": 1, "reinforcement_distance": 15,
		},
		"prediction": 0.5,
	}
	case.merge(changed, true)
	return case


func _combat_case(changed: Dictionary = {}) -> Dictionary:
	var case: Dictionary = {
		"kind": "combat", "attacker": 1, "defender": 2, "why": "the only fight there is",
		"features": {
			"health_difference": 0, "numeric_advantage": 0,
			"defender_terrain": 1, "reinforcement_distance": 15,
		},
		"prediction": 0.5,
	}
	case.merge(changed, true)
	return case


func _capture_case(changed: Dictionary = {}) -> Dictionary:
	var case: Dictionary = {
		"kind": "capture", "faction": 0, "node": [2, 2],
		"why": "a corner to walk at",
		"features": {
			"distance_to_node": 4, "own_units": 1,
			"enemy_units": 1, "terrain_on_the_way": 1.0,
		},
		"prediction": 2.0,
	}
	case.merge(changed, true)
	return case


# Why the vector is refused when its only case is this one.
func _why_one_case_is_wrong(changed: Dictionary) -> String:
	var case: Dictionary = changed if changed.has("kind") else _row_case(changed)
	return LearningVector.why_not_a_vector(_but({"cases": [case]}))


# Why the vector is refused when its board is changed like this.
func _why_the_board_is_wrong(changed: Dictionary) -> String:
	var board: Dictionary = _board()
	board.merge(changed, true)
	return LearningVector.why_not_a_vector(_but({"board": board}))


# The one failure a changed vector produces, as a sentence.
func _one_failure(changed: Dictionary) -> String:
	var failures: Array[String] = LearningVector.check("planted", _but(changed))
	return failures[0] if not failures.is_empty() else "nothing was reported"
