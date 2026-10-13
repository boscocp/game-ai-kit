# ai_fuzzy, held to what its headers claim.
#
# The numbers two languages must agree on are the conformance vectors'; these
# are the claims about this side alone -- each refusal, with the code the
# Python side uses for it, and the order of the tests inside `degree`.
extends GdUnitTestSuite


func _term(set_name: String, points: Array) -> FuzzySet:
	return FuzzySet.new(set_name, PackedFloat64Array(points))


func _sets(pairs: Dictionary) -> Array[FuzzySet]:
	var found: Array[FuzzySet] = []
	for set_name: String in pairs:
		found.append(_term(set_name, pairs[set_name]))
	return found


func _rule(conditions: Array, conclusion: Array, connective: String = FuzzyRule.AND) -> FuzzyRule:
	var typed: Array[PackedStringArray] = []
	for condition: Array in conditions:
		typed.append(PackedStringArray(condition))
	return FuzzyRule.new(typed, PackedStringArray(conclusion), connective)


func _noise() -> FuzzyVariable:
	return FuzzyVariable.new("noise", 0, 10, _sets({"quiet": [0, 0, 2, 6], "loud": [4, 8, 10, 10]}))


func _alertness(samples: int = 11) -> FuzzyVariable:
	return FuzzyVariable.new("alertness", 0, 100,
			_sets({"calm": [0, 0, 20, 50], "alarmed": [50, 80, 100, 100]}), samples)


func _controller(rules: Array[FuzzyRule] = []) -> FuzzyRuleBase:
	if rules.is_empty():
		rules.append(_rule([["noise", "quiet"]], ["alertness", "calm"]))
		rules.append(_rule([["noise", "loud"]], ["alertness", "alarmed"]))
	return FuzzyRuleBase.new([_noise()] as Array[FuzzyVariable],
			[_alertness()] as Array[FuzzyVariable], rules)


func _with_rule(rule: FuzzyRule) -> FuzzyRuleBase:
	return FuzzyRuleBase.new([_noise()] as Array[FuzzyVariable],
			[_alertness()] as Array[FuzzyVariable], [rule] as Array[FuzzyRule])


func test_three_points_are_a_triangle() -> void:
	var peak: FuzzySet = _term("peak", [1, 2, 3])
	assert_float(peak.rise_end).is_equal(2.0)
	assert_float(peak.fall_start).is_equal(2.0)
	assert_float(peak.degree(1.5)).is_equal(0.5)


func test_a_vertical_rising_edge_answers_one_at_its_corner() -> void:
	var shoulder: FuzzySet = _term("edge", [0, 0, 1, 2])
	assert_float(shoulder.degree(0.0)).is_equal(1.0)
	assert_float(shoulder.degree(-0.001)).is_equal(0.0)


func test_a_vertical_falling_edge_answers_one_at_its_corner() -> void:
	assert_float(_term("wall", [0, 1, 2, 2]).degree(2.0)).is_equal(1.0)


func test_points_out_of_order_are_refused() -> void:
	assert_str(_term("backwards", [0, 4, 3, 5]).problem()).starts_with("F1")


func test_the_wrong_number_of_points_is_refused() -> void:
	assert_str(_term("two", [0, 1]).problem()).starts_with("F1")


func test_a_point_that_is_not_a_number_is_refused() -> void:
	assert_str(_term("hole", [0, NAN, 2]).problem()).starts_with("F1")


func test_a_sound_set_has_no_problem() -> void:
	assert_str(_term("fine", [0, 1, 2, 3]).problem()).is_empty()


func test_an_input_is_clamped_before_it_is_fuzzified() -> void:
	assert_dict(_noise().fuzzify(-5.0)).is_equal(_noise().fuzzify(0.0))
	assert_float(_noise().fuzzify(50.0)["loud"]).is_equal(1.0)


func test_an_empty_range_is_refused() -> void:
	var flat := FuzzyVariable.new("flat", 3, 3, _sets({"one": [3, 3, 3]}))
	assert_str(flat.problem(false)).starts_with("F2")


func test_a_variable_with_no_sets_is_refused() -> void:
	var bare := FuzzyVariable.new("bare", 0, 1, [] as Array[FuzzySet])
	assert_str(bare.problem(false)).starts_with("F2")


func test_a_set_named_twice_is_refused() -> void:
	var twice: Array[FuzzySet] = [_term("same", [0, 1, 2]), _term("same", [1, 2, 3])]
	assert_str(FuzzyVariable.new("doubled", 0, 3, twice).problem(false)).starts_with("F2")


func test_a_variable_reports_its_set_s_problem() -> void:
	var broken := FuzzyVariable.new("broken", 0, 5, _sets({"backwards": [0, 4, 3, 5]}))
	assert_str(broken.problem(false)).starts_with("F1")


func test_an_output_with_one_sample_is_refused_and_an_input_needs_none() -> void:
	assert_str(_alertness(1).problem(true)).starts_with("F3")
	assert_str(_noise().problem(false)).is_empty()


func test_and_is_the_smaller_and_or_the_larger() -> void:
	var degrees: Dictionary = {"one": {"yes": 0.25}, "two": {"yes": 0.75}}
	var both: Array = [["one", "yes"], ["two", "yes"]]
	assert_float(_rule(both, ["out", "x"], FuzzyRule.AND).strength(degrees)).is_equal(0.25)
	assert_float(_rule(both, ["out", "x"], FuzzyRule.OR).strength(degrees)).is_equal(0.75)


func test_a_term_concluded_twice_takes_the_stronger_rule() -> void:
	var rules: Array[FuzzyRule] = [_rule([["noise", "quiet"]], ["alertness", "calm"]),
			_rule([["noise", "loud"]], ["alertness", "calm"])]
	var strengths: Dictionary = _controller(rules).activations({"noise": 4.5})
	assert_float(strengths["alertness"]["calm"]).is_equal(0.375)
	assert_float(strengths["alertness"]["alarmed"]).is_equal(0.0)


func test_a_sound_controller_has_no_problem() -> void:
	assert_str(_controller().problem()).is_empty()


func test_two_variables_sharing_a_name_are_refused() -> void:
	var clash := FuzzyVariable.new("noise", 0, 100, _alertness().sets, 11)
	var controller := FuzzyRuleBase.new([_noise()] as Array[FuzzyVariable],
			[clash] as Array[FuzzyVariable], _controller().rules)
	assert_str(controller.problem()).starts_with("F4")


func test_a_controller_with_no_rules_is_refused() -> void:
	var controller := FuzzyRuleBase.new([_noise()] as Array[FuzzyVariable],
			[_alertness()] as Array[FuzzyVariable], [] as Array[FuzzyRule])
	assert_str(controller.problem()).starts_with("F5")


func test_an_unknown_connective_is_refused() -> void:
	var rule: FuzzyRule = _rule([["noise", "quiet"]], ["alertness", "calm"], "xor")
	assert_str(_with_rule(rule).problem()).starts_with("F6")


func test_a_rule_with_no_conditions_is_refused() -> void:
	assert_str(_with_rule(_rule([], ["alertness", "calm"])).problem()).starts_with("F6")


func test_a_condition_on_no_input_s_set_is_refused() -> void:
	var rule: FuzzyRule = _rule([["noise", "deafening"]], ["alertness", "calm"])
	assert_str(_with_rule(rule).problem()).starts_with("F7")


func test_a_condition_on_an_output_is_refused() -> void:
	var rule: FuzzyRule = _rule([["alertness", "calm"]], ["alertness", "calm"])
	assert_str(_with_rule(rule).problem()).starts_with("F7")


func test_a_conclusion_on_no_output_s_set_is_refused() -> void:
	var rule: FuzzyRule = _rule([["noise", "quiet"]], ["noise", "loud"])
	assert_str(_with_rule(rule).problem()).starts_with("F7")


func test_a_malformed_condition_is_refused_rather_than_read() -> void:
	var rule: FuzzyRule = _rule([["noise"]], ["alertness", "calm"])
	assert_str(_with_rule(rule).problem()).starts_with("F7")


func test_a_controller_with_a_problem_answers_nan_rather_than_a_number() -> void:
	var rule: FuzzyRule = _rule([["noise", "quiet"]], ["alertness", "calm"], "xor")
	assert_bool(is_nan(_with_rule(rule).evaluate({"noise": 1.0})["alertness"])).is_true()


func test_a_missing_input_answers_nan_rather_than_reading_zero() -> void:
	assert_dict(_controller().activations({})).is_empty()
	assert_bool(is_nan(_controller().evaluate({})["alertness"])).is_true()


func test_the_samples_include_both_ends() -> void:
	assert_float(FuzzyCentroid.sample_point(_alertness(), 0)).is_equal(0.0)
	assert_float(FuzzyCentroid.sample_point(_alertness(), 10)).is_equal(100.0)
	assert_float(FuzzyCentroid.sample_point(_alertness(), 3)).is_equal(30.0)


func test_nothing_fired_is_nan_rather_than_a_number() -> void:
	var nothing: Dictionary = {"calm": 0.0, "alarmed": 0.0}
	assert_bool(is_nan(FuzzyCentroid.of(_alertness(), nothing))).is_true()


func test_a_weak_rule_cannot_outvote_a_strong_one() -> void:
	var leaning: Dictionary = {"calm": 0.9, "alarmed": 0.1}
	assert_float(FuzzyCentroid.of(_alertness(), leaning)).is_less(50.0)


func test_two_rules_at_once_land_strictly_between_their_terms() -> void:
	var controller: FuzzyRuleBase = _controller()
	var calm: float = controller.evaluate({"noise": 1.0})["alertness"]
	var alarmed: float = controller.evaluate({"noise": 9.0})["alertness"]
	var both: float = controller.evaluate({"noise": 5.0})["alertness"]
	assert_float(both).is_greater(calm)
	assert_float(both).is_less(alarmed)
