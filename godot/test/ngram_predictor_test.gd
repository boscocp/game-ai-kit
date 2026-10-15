# T17: the n-gram predictor's rules, the ones a vector cannot show.
extends GdUnitTestSuite

const ACTIONS: Array[String] = ["high", "low", "throw"]


func test_settings_that_cannot_work_are_named() -> void:
	assert_str(NGramPredictor.new(0, ACTIONS).problem()).contains("order")
	assert_str(NGramPredictor.new(1, [] as Array[String]).problem()).contains("at least one action")
	assert_str(NGramPredictor.new(1, ACTIONS, 0.0).problem()).contains("decay")
	assert_str(NGramPredictor.new(1, ACTIONS, 1.0, 0.0).problem()).contains("prior")
	assert_str(NGramPredictor.new(2, ACTIONS, 0.9, 1.0).problem()).is_empty()


func test_an_action_it_was_not_told_about_is_ignored() -> void:
	var predictor := NGramPredictor.new(2, ACTIONS)
	predictor.observe("high")
	predictor.observe("cartwheel")
	assert_str(predictor.context()).is_equal("high")


func test_before_any_context_every_action_is_alike() -> void:
	var predictor := NGramPredictor.new(3, ACTIONS)
	predictor.observe("high")
	for chance: float in predictor.probabilities().values():
		assert_float(chance).is_equal_approx(1.0 / 3.0, 1e-12)


func test_the_table_prints_each_context_heaviest_first() -> void:
	var predictor := NGramPredictor.new(2, ACTIONS)
	for action: String in ["high", "low", "high", "low", "high", "throw"]:
		predictor.observe(action)
	assert_array(Array(predictor.rows())).contains(["high -> low 2.0, throw 1.0", "low -> high 2.0"])
