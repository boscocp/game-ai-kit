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


func test_the_example_refuses_an_entry_that_is_not_a_model() -> void:
	assert_object(EXAMPLE.model_from({"kind": "tree", "features": ["x"], "weights": [1.0]})).is_null()
	assert_object(EXAMPLE.model_from({"kind": "linear", "features": ["x", "y"], "weights": [1.0]})).is_null()
	assert_object(EXAMPLE.model_from({"kind": "linear", "features": ["x"], "weights": [1.0]})).is_null()
	assert_object(EXAMPLE.model_from(EXAMPLE.PUBLISHED)).is_not_null()
