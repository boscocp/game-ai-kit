# The ai_bayes page's minimal example, loaded into an empty scene: with
# nothing noticed the belief is the prior, each sign raises it, the open
# gate moves it more than the dog, and forgetting it brings the belief back.
# The page shows the file's text, held equal by check_translations_docs.py.
extends GdUnitTestSuite

const EXAMPLE: Script = preload("res://test/ai_bayes/watchman_example.gd")


func _watchman() -> Node:
	var scene: Node = auto_free(Node.new())
	add_child(scene)
	var example: Node = EXAMPLE.new()
	scene.add_child(example)
	return example


func test_nothing_noticed_is_the_prior() -> void:
	assert_float(_watchman().chance_of_intruder()).is_equal_approx(0.05, 1e-12)


func test_each_sign_raises_the_belief() -> void:
	var watchman: Node = _watchman()
	watchman.noticed("dog_barks", true)
	var dog: float = watchman.chance_of_intruder()
	watchman.noticed("gate_open", true)
	assert_float(dog).is_greater(0.05)
	assert_float(watchman.chance_of_intruder()).is_greater(dog)


func test_the_gate_is_named_over_the_dog() -> void:
	var watchman: Node = _watchman()
	watchman.noticed("dog_barks", true)
	watchman.noticed("gate_open", true)
	assert_str(watchman.reason()).is_equal("gate_open")


func test_a_quiet_dog_lowers_it_and_forgetting_restores_it() -> void:
	var watchman: Node = _watchman()
	watchman.noticed("dog_barks", false)
	assert_float(watchman.chance_of_intruder()).is_less(0.05)
	watchman.forget("dog_barks")
	assert_float(watchman.chance_of_intruder()).is_equal_approx(0.05, 1e-12)
