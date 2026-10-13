# A planted case for every rule `FuzzyVector` has.
#
# `lint-selftests` only looks inside `scripts/`, and this is GDScript, so this
# file is the only thing between the fuzzy runner and a rule that has quietly
# stopped being applied. Each test breaks one thing in an otherwise sound
# vector and names the code it expects.
extends GdUnitTestSuite


func _sound() -> Dictionary:
	var noise: Dictionary = {"name": "noise", "minimum": 0.0, "maximum": 10.0,
		"sets": {"quiet": [0.0, 0.0, 2.0, 6.0], "loud": [4.0, 8.0, 10.0, 10.0]}}
	var alertness: Dictionary = {"name": "alertness", "minimum": 0.0, "maximum": 100.0,
		"samples": 11.0,
		"sets": {"calm": [0.0, 0.0, 20.0, 50.0], "alarmed": [50.0, 80.0, 100.0, 100.0]}}
	var rules: Array = [{"if": [["noise", "quiet"]], "then": ["alertness", "calm"]},
		{"if": [["noise", "loud"]], "then": ["alertness", "alarmed"]}]
	var cases: Array = [
		{"kind": "membership", "variable": "noise", "set": "quiet", "value": 4.0,
			"degree": 0.5, "why": "halfway down"},
		{"kind": "fuzzify", "variable": "noise", "value": 5.0,
			"degrees": {"quiet": 0.25, "loud": 0.25}, "why": "both"},
		_evaluation("calm", 1.0, {"calm": 1.0, "alarmed": 0.0}, 95.0 / 6.0),
		_evaluation("alarmed", 9.0, {"calm": 0.0, "alarmed": 1.0}, 505.0 / 6.0),
		_evaluation("both", 5.0, {"calm": 0.25, "alarmed": 0.25}, 50.0, ["calm", "alarmed"]),
	]
	var controller: Dictionary = {"inputs": [noise], "outputs": [alertness], "rules": rules}
	return {"controller": controller, "cases": cases}


func _evaluation(name: String, noise: float, strengths: Dictionary, answer: float,
		between: Array = []) -> Dictionary:
	var case: Dictionary = {"kind": "evaluate", "name": name, "why": name,
			"inputs": {"noise": noise}, "activations": {"alertness": strengths},
			"outputs": {"alertness": answer}}
	if not between.is_empty():
		case["between"] = between
	return case


func _with_case(index: int, field: String, value: Variant) -> Dictionary:
	var data: Dictionary = _sound()
	if value == null:
		data["cases"][index].erase(field)
	else:
		data["cases"][index][field] = value
	return data


func _why(data: Dictionary) -> String:
	return FuzzyVector.why_not_a_vector(data)


func test_a_sound_vector_is_accepted_and_claims_nothing_false() -> void:
	assert_str(_why(_sound())).is_empty()
	assert_array(FuzzyVector.check("sound", _sound())).is_empty()


func test_a_vector_with_no_cases_is_refused() -> void:
	var data: Dictionary = _sound()
	data["cases"] = []
	assert_str(_why(data)).contains("V1")


func test_a_case_of_an_unknown_kind_is_refused() -> void:
	assert_str(_why(_with_case(0, "kind", "vibes"))).contains("V2")


func test_a_case_that_is_not_an_object_is_refused() -> void:
	var data: Dictionary = _sound()
	data["cases"][0] = "nearly"
	assert_str(_why(data)).contains("V2")


func test_a_vector_with_no_controller_is_refused() -> void:
	var data: Dictionary = _sound()
	data.erase("controller")
	assert_str(_why(data)).contains("V3")


func test_a_variable_missing_its_range_is_refused() -> void:
	var data: Dictionary = _sound()
	data["controller"]["inputs"][0].erase("minimum")
	assert_str(_why(data)).contains("V3")


func test_an_output_missing_its_samples_is_refused() -> void:
	var data: Dictionary = _sound()
	data["controller"]["outputs"][0].erase("samples")
	assert_str(_why(data)).contains("V3")


func test_a_set_that_is_not_a_list_is_refused() -> void:
	var data: Dictionary = _sound()
	data["controller"]["inputs"][0]["sets"]["quiet"] = "low"
	assert_str(_why(data)).contains("V3")


func test_a_rule_with_no_then_is_refused() -> void:
	var data: Dictionary = _sound()
	data["controller"]["rules"][1].erase("then")
	assert_str(_why(data)).contains("V3")


func test_a_controller_s_own_problem_is_reported_in_its_words() -> void:
	var data: Dictionary = _sound()
	data["controller"]["rules"][0]["then"] = ["alertness", "bored"]
	assert_str(_why(data)).contains("F7")


func test_a_membership_case_naming_no_set_is_refused() -> void:
	assert_str(_why(_with_case(0, "set", "deafening"))).contains("V4")


func test_a_membership_case_with_no_degree_is_refused() -> void:
	assert_str(_why(_with_case(0, "degree", null))).contains("V4")


func test_a_case_naming_no_input_is_refused() -> void:
	assert_str(_why(_with_case(1, "variable", "alertness"))).contains("V4")


func test_a_case_with_no_value_is_refused() -> void:
	assert_str(_why(_with_case(1, "value", null))).contains("V4")


func test_a_fuzzify_case_with_no_degrees_is_refused() -> void:
	assert_str(_why(_with_case(1, "degrees", null))).contains("V4")


func test_an_evaluation_with_no_activations_is_refused() -> void:
	assert_str(_why(_with_case(2, "activations", null))).contains("V5")


func test_an_evaluation_with_no_outputs_is_refused() -> void:
	assert_str(_why(_with_case(2, "outputs", null))).contains("V5")


func test_an_evaluation_with_no_inputs_is_refused() -> void:
	assert_str(_why(_with_case(2, "inputs", null))).contains("V5")


func test_an_evaluation_missing_an_input_s_value_is_refused() -> void:
	assert_str(_why(_with_case(2, "inputs", {"volume": 1.0}))).contains("V5")


func test_an_evaluation_claiming_no_answer_for_an_output_is_refused() -> void:
	assert_str(_why(_with_case(2, "outputs", {}))).contains("V5")


func test_two_evaluations_sharing_a_name_are_refused() -> void:
	assert_str(_why(_with_case(3, "name", "calm"))).contains("V5")


func test_between_naming_a_later_case_is_refused() -> void:
	var data: Dictionary = _sound()
	data["cases"][2]["between"] = ["alarmed", "both"]
	assert_str(_why(data)).contains("V6")


func test_between_naming_one_case_is_refused() -> void:
	assert_str(_why(_with_case(4, "between", ["calm"]))).contains("V6")


func test_a_wrong_degree_fails() -> void:
	assert_array(FuzzyVector.check("wrong", _with_case(0, "degree", 0.6))).has_size(1)


func test_a_wrong_fuzzified_degree_fails() -> void:
	var wrong: Dictionary = _with_case(1, "degrees", {"quiet": 0.25, "loud": 0.3})
	assert_array(FuzzyVector.check("wrong", wrong)).has_size(1)


func test_a_fuzzify_case_missing_a_term_fails() -> void:
	var wrong: Dictionary = _with_case(1, "degrees", {"quiet": 0.25})
	assert_array(FuzzyVector.check("wrong", wrong)).has_size(1)


func test_a_wrong_activation_fails() -> void:
	var wrong: Dictionary = _with_case(2, "activations", {"alertness": {"calm": 0.9, "alarmed": 0.0}})
	assert_array(FuzzyVector.check("wrong", wrong)).has_size(1)


func test_a_wrong_answer_fails() -> void:
	assert_array(FuzzyVector.check("wrong", _with_case(2, "outputs", {"alertness": 15.9}))).has_size(1)


func test_an_answer_claimed_as_nan_fails_when_a_rule_fired() -> void:
	assert_array(FuzzyVector.check("wrong", _with_case(2, "outputs", {"alertness": null}))).has_size(1)


func test_an_answer_on_the_edge_of_between_fails() -> void:
	# The claim is strict. `both` is moved to `calm`'s own inputs, so its
	# number is right and equal to one end -- and that alone must fail.
	var data: Dictionary = _with_case(4, "inputs", {"noise": 1.0})
	data["cases"][4]["activations"] = {"alertness": {"calm": 1.0, "alarmed": 0.0}}
	data["cases"][4]["outputs"] = {"alertness": 95.0 / 6.0}
	var failures: Array[String] = FuzzyVector.check("edge", data)
	assert_array(failures).has_size(1)
	assert_str(failures[0]).contains("strictly between")


func test_nan_compares_equal_only_to_a_claimed_null() -> void:
	assert_bool(FuzzyVector.close_enough(NAN, null)).is_true()
	assert_bool(FuzzyVector.close_enough(0.0, null)).is_false()
	assert_bool(FuzzyVector.close_enough(NAN, 0.0)).is_false()
