# The ai_behaviour page's minimal example, loaded into an empty scene and
# asked with three sets of facts: it must choose differently for each, and
# leave a trail saying why. The page shows the file's text, held equal by
# check_translations_docs.py.
extends GdUnitTestSuite

const EXAMPLE: Script = preload("res://test/ai_behaviour/guard_example.gd")


func _guard() -> Node:
	var scene: Node = auto_free(Node.new())
	add_child(scene)
	var example: Node = EXAMPLE.new()
	scene.add_child(example)
	return example


func test_the_example_chases_what_it_sees_before_what_it_hears() -> void:
	var guard: Node = _guard()
	assert_str(guard.decide({"sees_player": true, "heard_noise": true})).is_equal("chase")
	assert_str(guard.decide({"heard_noise": true})).is_equal("investigate")
	assert_str(guard.decide({})).is_equal("patrol")


func test_the_example_leaves_a_trail_of_what_it_asked() -> void:
	var guard: Node = _guard()
	guard.decide({"heard_noise": true})
	assert_array(guard.trail()).contains([
		"sees someone?: failure", "heard something?: success", "go and look: success",
	])
