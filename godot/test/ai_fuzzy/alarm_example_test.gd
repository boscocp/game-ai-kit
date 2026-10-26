# The ai_fuzzy page's minimal example, loaded into an empty scene and asked
# about a body near and lit, far and dark, and everything between: the alarm
# must rise as the body comes nearer, with no jump anywhere along the way.
# The page shows the file's text, held equal by check_translations_docs.py.
extends GdUnitTestSuite

const EXAMPLE: Script = preload("res://test/ai_fuzzy/alarm_example.gd")


func _guard() -> Node:
	var scene: Node = auto_free(Node.new())
	add_child(scene)
	var example: Node = EXAMPLE.new()
	scene.add_child(example)
	return example


func test_the_example_is_alarmed_near_and_lit_and_calm_far_and_dark() -> void:
	var guard: Node = _guard()
	assert_float(guard.alarm(1.0, 1.0)).is_greater(75.0)
	assert_float(guard.alarm(9.0, 0.0)).is_less(25.0)
	var halfway: float = guard.alarm(9.0, 1.0)
	assert_float(halfway).is_between(25.0, 75.0)


func test_the_example_rises_by_degrees_as_the_body_comes_nearer() -> void:
	var guard: Node = _guard()
	var previous: float = guard.alarm(10.0, 1.0)
	for tenths: int in range(99, -1, -1):
		var now: float = guard.alarm(tenths / 10.0, 1.0)
		assert_float(now).is_greater_equal(previous - 0.001)
		# By degrees: a tenth of a metre never moves it by more than a few.
		assert_float(now - previous).is_less(5.0)
		previous = now


func test_the_example_says_which_rule_fired() -> void:
	var guard: Node = _guard()
	var why: Dictionary = guard.why(1.0, 1.0)
	assert_float(why["alarmed"]).is_equal(1.0)
	assert_float(why["calm"]).is_equal(0.0)


func test_the_example_refuses_an_input_that_is_not_a_number() -> void:
	var guard: Node = _guard()
	assert_bool(is_nan(guard.alarm(NAN, 1.0))).is_true()
	assert_dict(guard.why(NAN, 1.0)).is_empty()
