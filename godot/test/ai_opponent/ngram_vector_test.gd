# The n-gram vector's rules, each refusing a planted case, and a planted
# predictor -- one that never forgets -- failing the vector its decay is for.
extends GdUnitTestSuite


func _vector(name: String) -> Dictionary:
	var path: String = ProjectSettings.globalize_path("res://").path_join("../spec/vectors/ngram").path_join(name)
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func test_the_vectors_are_vectors() -> void:
	for name: String in ["order-two-by-hand.json", "decay-follows-a-change.json", "order-one.json", "order-three.json"]:
		assert_str(NGramVector.why_not_a_vector(_vector(name))).is_empty()


func test_a_misspelt_or_short_or_lopsided_case_is_refused() -> void:
	var vector: Dictionary = _vector("order-two-by-hand.json")
	var case: Dictionary = (vector["cases"][0] as Dictionary).duplicate(true)
	vector["cases"] = [case]
	case["likelist"] = case["likeliest"]
	assert_str(NGramVector.why_not_a_vector(vector)).starts_with("V3")
	case.erase("likelist")
	case["probabilities"] = {"high": 1.0}
	assert_str(NGramVector.why_not_a_vector(vector)).starts_with("V4")
	case["probabilities"] = {"high": 0.5, "low": 0.5, "throw": 0.5}
	assert_str(NGramVector.why_not_a_vector(vector)).starts_with("V5")
	case["probabilities"] = _vector("order-two-by-hand.json")["cases"][0]["probabilities"]
	vector["cases"] = [case, case.duplicate()]
	assert_str(NGramVector.why_not_a_vector(vector)).starts_with("V7")
	vector["cases"] = [case]
	case["seen"] = 4.5
	assert_str(NGramVector.why_not_a_vector(vector)).starts_with("V6")
	case["seen"] = 0
	vector["sequence"] = ["high", "cartwheel"]
	assert_str(NGramVector.why_not_a_vector(vector)).starts_with("V8")
	vector["sequence"] = ["high"]
	vector["decay"] = 0.0
	assert_str(NGramVector.why_not_a_vector(vector)).starts_with("V9")
	vector.erase("decay")
	assert_str(NGramVector.why_not_a_vector(vector)).starts_with("V1")


# T121: each of these, a list given as text in a copy of a real file, was
# a SCRIPT ERROR that skipped the check and let the runner exit 0.
func test_a_vector_of_the_wrong_types_is_refused_before_it_is_read() -> void:
	var vector: Dictionary = _vector("decay-follows-a-change.json")
	var paths: Array = [["actions"], ["cases"], ["sequence"], ["cases", 0, "probabilities"]]
	for path: Array in paths:
		var why: String = NGramVector.why_not_a_vector(VectorShape.planted(vector, path, "x"))
		assert_str(why).override_failure_message(str(path)).starts_with("V10")


func test_a_predictor_that_never_forgets_fails_the_decay_vector() -> void:
	var vector: Dictionary = _vector("decay-follows-a-change.json")
	var actions: Array[String] = []
	actions.assign(vector["actions"])
	var never_forgets := NGramPredictor.new(int(vector["order"]), actions, 1.0, float(vector["prior"]))
	assert_array(NGramVector.wrong_claims(vector, never_forgets)).is_not_empty()
	assert_array(NGramVector.wrong_claims(vector, NGramVector.predictor_of(vector))).is_empty()
