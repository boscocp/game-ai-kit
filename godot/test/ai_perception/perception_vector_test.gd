# PerceptionVector's own rules, each handed a broken vector it must refuse
# or a wrong answer it must name -- so a runner that only goes green cannot.
extends GdUnitTestSuite


func _loudness_vector(expected: float) -> Dictionary:
	return {"name": "planted", "why": "a test", "kind": "loudness",
		"query": {"heard": [[4.0, 10.0, 1.0]]}, "expect": {"loudness": [expected]}}


func test_a_right_answer_passes_and_a_wrong_one_is_named() -> void:
	assert_array(PerceptionVector.check("right", _loudness_vector(0.6))).is_empty()
	assert_array(PerceptionVector.check("wrong", _loudness_vector(0.6 + 1e-6))).has_size(1)


func test_a_vector_without_a_field_or_of_an_unknown_kind_is_refused() -> void:
	var missing: Dictionary = _loudness_vector(0.6)
	missing.erase("why")
	assert_str(PerceptionVector.why_not_a_vector(missing)).is_equal("it has no why")
	var unknown: Dictionary = _loudness_vector(0.6)
	unknown["kind"] = "smell"
	assert_str(PerceptionVector.why_not_a_vector(unknown)).contains("none of")


func test_a_vector_that_expects_nothing_is_refused() -> void:
	var empty: Dictionary = _loudness_vector(0.6)
	empty["expect"] = {}
	assert_str(PerceptionVector.why_not_a_vector(empty)).is_equal("it expects nothing")


func test_a_flipped_flag_and_a_short_list_are_named() -> void:
	var found: Array[String] = []
	PerceptionVector.differences({"reseeded": [true, false]}, {"reseeded": [true, true]}, "planted", found)
	PerceptionVector.differences({"shares": [0.5, 0.5]}, {"shares": [1.0]}, "planted", found)
	assert_array(found).has_size(2)
