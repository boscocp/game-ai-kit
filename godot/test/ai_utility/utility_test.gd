# ai_utility's refusals, and the vector checker's. The vectors pin answers
# on stated queries; these hold that data which is not a list of actions is
# refused whole, and that the checker objects to what it must.
extends GdUnitTestSuite


func test_the_checker_refuses_a_vector_missing_a_part_or_of_an_unknown_kind() -> void:
	var whole: Dictionary = VectorShape.read_spec("vectors/utility/an-absent-percept-is-nothing.json")
	assert_str(UtilityVector.why_not_a_vector(whole)).is_equal("")
	for key: String in ["name", "why", "kind", "query", "expect"]:
		var broken: Dictionary = whole.duplicate(true)
		broken.erase(key)
		assert_str(UtilityVector.why_not_a_vector(broken)).is_not_equal("")
	var unknown: Dictionary = whole.duplicate(true)
	unknown["kind"] = "positions"
	assert_str(UtilityVector.why_not_a_vector(unknown)).is_not_equal("")
	var empty: Dictionary = whole.duplicate(true)
	empty["expect"] = {}
	assert_str(UtilityVector.why_not_a_vector(empty)).is_not_equal("")


func test_the_checker_catches_a_wrong_number_a_wrong_word_and_a_missing_key() -> void:
	var found: Array[String] = []
	UtilityVector.differences({"value": 1.0}, {"value": 1.0 + 10 * UtilityVector.TOLERANCE}, "n", found)
	UtilityVector.differences({"errand": "resupply"}, {"errand": "fetch power"}, "n", found)
	UtilityVector.differences({"a": 1, "b": 2}, {"a": 1}, "n", found)
	assert_int(found.size()).is_equal(3)
	var none: Array[String] = []
	UtilityVector.differences({"value": 1.0, "list": [1, "x"]}, {"value": 1.00001, "list": [1.0, "x"]}, "n", none)
	assert_array(none).is_empty()


func test_actions_with_an_unknown_key_or_curve_are_refused() -> void:
	var good: Array = [{"name": "go", "weight": 1.0, "considerations": [{"percept": "x", "curve": "step", "at": 0.5}]}]
	assert_str(ActionChoice.why_not_actions(good)).is_empty()
	assert_int(ActionChoice.actions_from(good).size()).is_equal(1)
	var planted: Array = [
		[{"name": "go", "wieght": 1.0}],
		[{"name": "go", "considerations": [{"percept": "x", "curve": "stepp"}]}],
		[{"name": "go", "considerations": [{"percept": "x", "slop": 2.0}]}],
		[{"weight": 1.0}],
	]
	for data: Array in planted:
		assert_str(ActionChoice.why_not_actions(data)).override_failure_message(str(data)).is_not_empty()


# T121: a vector of the wrong types is refused before it is read. Each of
# these, a list given as text in a copy of a real file, was a SCRIPT ERROR
# that skipped the query and let the runner exit 0 or 1.
func test_a_utility_vector_of_the_wrong_types_is_refused() -> void:
	var vector: Dictionary = VectorShape.read_spec("vectors/utility/a-line-is-clamped-at-both-ends.json")
	assert_str(UtilityVector.why_not_a_vector(vector)).is_empty()
	var paths: Array = [["query", "actions"], ["query", "actions", 0, "considerations"], ["query", "percepts"]]
	for path: Array in paths:
		var why: String = UtilityVector.why_not_a_vector(VectorShape.planted(vector, path, "x"))
		assert_str(why).override_failure_message(str(path)).contains(" is not ")