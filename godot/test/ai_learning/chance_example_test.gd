# The ai_learning page's minimal example, loaded into an empty scene and
# asked about a fight it should win, one it should lose, and one it was not
# told enough about. The page shows the file's text, held equal by
# check_translations_docs.py.
extends GdUnitTestSuite

const EXAMPLE: Script = preload("res://test/ai_learning/chance_example.gd")


func _unit() -> Node:
	var scene: Node = auto_free(Node.new())
	add_child(scene)
	var example: Node = EXAMPLE.new()
	scene.add_child(example)
	return example


func test_the_example_favours_the_healthier_side() -> void:
	var unit: Node = _unit()
	var strong: float = unit.chance_to_win({"my_health": 100, "their_health": 20, "distance": 1})
	var weak: float = unit.chance_to_win({"my_health": 20, "their_health": 100, "distance": 1})
	assert_float(strong).is_greater(0.9)
	assert_float(weak).is_less(0.1)


func test_the_example_answers_nan_when_a_fact_is_missing() -> void:
	var unit: Node = _unit()
	assert_bool(is_nan(unit.chance_to_win({"my_health": 100}))).is_true()


func test_a_unit_whose_file_was_refused_answers_nan_rather_than_crashing() -> void:
	# Readers copy this example. A unit whose model never loaded must not
	# call through null; NAN is the answer no threshold passes.
	var unit: Node = auto_free(EXAMPLE.new())
	assert_bool(is_nan(unit.chance_to_win({"my_health": 100, "their_health": 20, "distance": 1}))).is_true()


func test_the_example_loads_its_own_file_and_refuses_a_missing_one() -> void:
	assert_object(EXAMPLE.model_from(EXAMPLE.MODEL_PATH)).is_not_null()
	assert_object(EXAMPLE.model_from("res://test/ai_learning/nothing.json")).is_null()
