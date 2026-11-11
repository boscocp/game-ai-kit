# T121: the three vectors runners of ai_learning refuse a file of the wrong
# types before they read it. Before, a list given as text in the cloning,
# tree or forest vectors was a SCRIPT ERROR that skipped a check, and the
# run printed "0 failure(s)". Each case plants it in a copy of a real file.
extends GdUnitTestSuite

const CloningRunner: GDScript = preload("res://test/ai_learning/cloning_vectors_runner.gd")
const TreeRunner: GDScript = preload("res://test/ai_learning/tree_vectors_runner.gd")
const ForestRunner: GDScript = preload("res://test/ai_learning/forest_vectors_runner.gd")


func test_the_real_files_have_the_shapes() -> void:
	assert_str(VectorShape.why_not(_read("cloning/softmax-by-hand.json"), CloningRunner.SOFTMAX_SHAPE)).is_empty()
	assert_str(VectorShape.why_not(_read("cloning/ghost-by-hand.json"), CloningRunner.GHOST_SHAPE)).is_empty()
	for name: String in ["fit-by-hand", "fit-capped", "fit-a-tie"]:
		assert_str(VectorShape.why_not(_read("tree/%s.json" % name), TreeRunner.SHAPE)).is_empty()
	for name: String in ["three-trees", "a-tied-vote"]:
		assert_str(VectorShape.why_not(_read("forest/%s.json" % name), ForestRunner.SHAPE)).is_empty()


func test_a_cloning_vector_of_the_wrong_types_is_refused() -> void:
	var softmax: Dictionary = _read("cloning/softmax-by-hand.json")
	var paths: Array = [["cases"], ["model", "weights"], ["model", "weights", 0], ["cases", 0, "probabilities"]]
	for path: Array in paths:
		var why: String = VectorShape.why_not(VectorShape.planted(softmax, path, "x"), CloningRunner.SOFTMAX_SHAPE)
		assert_str(why).override_failure_message(str(path)).is_not_empty()
	var ghost: Dictionary = _read("cloning/ghost-by-hand.json")
	paths = [["features"], ["cases"], ["cases", 0, "nearest"]]
	for path: Array in paths:
		var why: String = VectorShape.why_not(VectorShape.planted(ghost, path, "x"), CloningRunner.GHOST_SHAPE)
		assert_str(why).override_failure_message(str(path)).is_not_empty()


func test_a_tree_or_forest_vector_of_the_wrong_types_is_refused() -> void:
	var tree: Dictionary = _read("tree/fit-a-tie.json")
	var paths: Array = [["rows"], ["rows", 0], ["cases"], ["cases", 0, "path"]]
	for path: Array in paths:
		var why: String = VectorShape.why_not(VectorShape.planted(tree, path, "x"), TreeRunner.SHAPE)
		assert_str(why).override_failure_message(str(path)).is_not_empty()
	var forest: Dictionary = _read("forest/a-tied-vote.json")
	paths = [["rows"], ["cases"], ["cases", 0, "votes"], ["model"]]
	for path: Array in paths:
		var why: String = VectorShape.why_not(VectorShape.planted(forest, path, "x"), ForestRunner.SHAPE)
		assert_str(why).override_failure_message(str(path)).is_not_empty()


func _read(name: String) -> Dictionary:
	return VectorShape.read_spec("vectors/" + name)
