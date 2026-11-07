# T113: a decision tree read back through the model file, and walked.
# The walks' numbers are the vectors' (`make test-tree-vectors`); these hold
# what a game relies on beside them: the kinds kept apart, the walk told
# step by step, and a walk that cannot be read answering nothing.
extends GdUnitTestSuite

const TREE: Dictionary = {"kind": "tree", "features": ["distance", "health"], "classes": ["high", "low"],
	"nodes": [{"feature": "distance", "is": "close", "yes": 1, "no": 2}, {"counts": {"low": 3.0}},
		{"feature": "health", "at_most": 2.5, "yes": 3, "no": 4}, {"counts": {"high": 1, "low": 1}},
		{"counts": {"high": 4}}]}


func _published() -> ModelFile:
	return ModelFile.from_dictionary({"models": {"reads": TREE,
		"chance": {"kind": "logistic", "features": ["one"], "weights": [1.0], "bias": 0.0}}}, "the test")


func test_a_tree_and_a_weighted_model_are_each_found_by_their_own_kind() -> void:
	var published: ModelFile = _published()
	assert_str(published.error).is_empty()
	assert_object(published.tree("reads")).is_not_null()
	assert_object(published.model("reads")).is_null()
	assert_object(published.model("chance")).is_not_null()
	assert_object(published.tree("chance")).is_null()
	assert_array(published.model_names()).contains_exactly(["chance", "reads"])


func test_indices_and_counts_come_back_as_whole_numbers() -> void:
	var tree: LearnedTree = _published().tree("reads")
	assert_int(typeof(tree.nodes[0]["yes"])).is_equal(TYPE_INT)
	assert_int(typeof(tree.nodes[1]["counts"]["low"])).is_equal(TYPE_INT)


func test_the_walk_is_told_a_test_at_a_time_and_ends_at_the_leaf() -> void:
	var steps: Array[Dictionary] = _published().tree("reads").steps({"distance": "far", "health": 1})
	assert_int(steps.size()).is_equal(3)
	assert_dict(steps[0]).contains_key_value("went", LearnedTree.NO).contains_key_value("seen", "far")
	assert_dict(steps[1]).contains_key_value("test", "at_most").contains_key_value("went", LearnedTree.YES)
	assert_dict(steps[2]).contains_key_value("node", 3)
	assert_dict(steps[2]["counts"]).is_equal({"high": 1, "low": 1})


func test_a_tie_in_the_leaf_goes_to_the_first_class() -> void:
	var tree: LearnedTree = _published().tree("reads")
	assert_str(tree.likeliest({"distance": "far", "health": 1})).is_equal("high")
	assert_float(tree.probabilities({"distance": "far", "health": 1})["low"]).is_equal(0.5)


func test_a_value_it_cannot_read_stops_the_walk_and_answers_nothing() -> void:
	var tree: LearnedTree = _published().tree("reads")
	for unreadable: Dictionary in [{"health": 1}, {"distance": "far", "health": "low"}, {"distance": 3}]:
		assert_str(tree.likeliest(unreadable)).is_empty()
		assert_dict(tree.counts(unreadable)).is_empty()
		assert_dict(tree.probabilities(unreadable)).is_empty()
		assert_str(tree.steps(unreadable).back()["went"]).is_equal(LearnedTree.UNREAD)


func test_a_feature_no_test_on_the_path_asks_about_is_not_needed() -> void:
	assert_str(_published().tree("reads").likeliest({"distance": "close"})).is_equal("low")


# The planted case for the refusals the walk relies on: a child pointing
# back would loop, and the file is refused before a walk could start.
func test_a_tree_whose_child_points_back_is_refused_whole() -> void:
	var looping: Dictionary = TREE.duplicate(true)
	looping["nodes"][2]["no"] = 0
	var published := ModelFile.from_dictionary({"models": {"reads": looping}}, "the test")
	assert_str(published.error).starts_with("M14")
	assert_object(published.tree("reads")).is_null()
