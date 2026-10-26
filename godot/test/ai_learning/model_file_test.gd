# The addon's two inference pieces, each held to the thing it is easy to get
# wrong: `LearnedModel` to its arithmetic, and `ModelFile` to its refusals.
#
# The refusals are the vector's: spec/vectors/model_file/refusals.json names,
# for every file in it, the code of the first rule it breaks, and
# `make test-python` holds `gameaikit.training.model_file` to the same file.
# No game here -- a model file is anybody's, and the tactical game's own
# conventions are its own test's (test/tactical/learning_test.gd).
extends GdUnitTestSuite

## A sound model file with nothing in it but one model.
const SOUND: Dictionary = {
	"models": {
		"chance": {
			"kind": "logistic",
			"features": ["my_health", "their_health", "distance"],
			"weights": [0.5, -0.5, -0.125],
			"bias": 3.0,
		},
	},
}


func test_a_linear_model_answers_the_number_itself() -> void:
	var model := LearnedModel.new(
		LearnedModel.LINEAR, PackedStringArray(["one", "two"]),
		PackedFloat64Array([2.0, 0.25]), -1.0)

	assert_float(model.predict(PackedFloat64Array([4.0, 8.0]))).is_equal_approx(9.0, 1e-12)


func test_a_logistic_model_answers_a_probability() -> void:
	var model := LearnedModel.new(
		LearnedModel.LOGISTIC, PackedStringArray(["one"]),
		PackedFloat64Array([1.0]), 0.0)

	assert_float(model.predict(PackedFloat64Array([0.0]))).is_equal_approx(0.5, 1e-12)
	assert_bool(model.predict(PackedFloat64Array([4.0])) > 0.98).is_true()


func test_a_row_of_the_wrong_length_answers_nan_rather_than_a_number() -> void:
	# The fail-loud choice. A short row padded with zeros would come back as a
	# probability, and a probability is indistinguishable from an answer.
	var model: LearnedModel = _chance()

	assert_bool(is_nan(model.predict(PackedFloat64Array([1.0])))).is_true()


func test_a_named_row_is_read_by_name_and_not_by_the_order_it_was_built_in() -> void:
	# The weight order is the published contract. A caller handing over a
	# dictionary cannot get it wrong, which is the whole reason this call
	# exists beside the one taking an array.
	var model: LearnedModel = _chance()
	var forwards: float = model.predict_named({"my_health": 4, "their_health": 1, "distance": 8})
	var backwards: float = model.predict_named({"distance": 8, "their_health": 1, "my_health": 4})

	assert_float(forwards).is_equal_approx(backwards, 1e-15)
	# 0.5 * 4 - 0.5 * 1 - 0.125 * 8 + 3 = 3.5, through the sigmoid.
	assert_float(forwards).is_equal_approx(1.0 / (1.0 + exp(-3.5)), 1e-12)


func test_a_named_row_missing_a_feature_answers_nan() -> void:
	assert_bool(is_nan(_chance().predict_named({"my_health": 4}))).is_true()


func test_the_sigmoid_survives_the_row_that_overflows_the_obvious_spelling() -> void:
	# `1.0 / (1.0 + exp(-value))` returns inf for the second of these, and a
	# model that dies on one unusual row dies mid-game.
	assert_float(LearnedModel.sigmoid(800.0)).is_equal_approx(1.0, 1e-12)
	assert_float(LearnedModel.sigmoid(-800.0)).is_equal_approx(0.0, 1e-12)


func test_every_vector_case_gets_the_answer_it_claims() -> void:
	var cases: Array = _vector()["cases"]

	assert_int(cases.size()).is_greater(10)
	for case: Dictionary in cases:
		assert_str(_answer(case)).override_failure_message(case["why"]).is_equal(_claimed(case))


func test_a_wrong_claim_in_the_vector_is_caught() -> void:
	# The planted case for the comparison itself: claims this side meets are
	# worth something only if a wrong one fails. Each kind of claim made
	# wrong, and put through the same comparison.
	var cases: Array = _vector()["cases"]
	var wrong_code: Dictionary = cases[4].duplicate(true)
	wrong_code["refused"] = "M4"
	var wrong_names: Dictionary = cases[0].duplicate(true)
	wrong_names["loads"] = ["somebody else's"]
	var wrong_fields: Dictionary = cases[1].duplicate(true)
	wrong_fields["extra"] = ["generated_by"]

	for wrong: Dictionary in [wrong_code, wrong_names, wrong_fields]:
		assert_str(_answer(wrong)).is_not_equal(_claimed(wrong))


func test_the_first_wrong_feature_name_is_the_one_reported() -> void:
	# The code alone cannot tell the two M6 sentences apart; the names are
	# walked once, in order, and the repeat comes before the number.
	var published: ModelFile = ModelFile.from_dictionary({"models": {"only": {
		"kind": "linear", "features": ["a", "a", 1], "weights": [1.0, 1.0, 1.0], "bias": 0.0,
	}}}, "the test")

	assert_str(published.error).contains("twice")


func test_a_parse_error_is_placed_on_the_line_an_editor_shows() -> void:
	# Counted from 1, as the Python side counts it: the third line here.
	var published: ModelFile = ModelFile.from_text('{\n"a": 1,\n oops\n}', "the test")

	assert_str(published.error).ends_with("at line 3")


func test_a_missing_file_is_refused_by_name() -> void:
	var published: ModelFile = ModelFile.load_from("res://test/ai_learning/nothing.json")

	assert_str(published.error).starts_with("M1 ")
	assert_bool(published.is_loaded()).is_false()


func test_a_file_on_disk_is_read_through_the_same_rules() -> void:
	# The example's own file, which the page shows beside the code.
	var published: ModelFile = ModelFile.load_from("res://test/ai_learning/chance_model.json")

	assert_str(published.error).is_empty()
	assert_array(published.model_names()).contains_exactly(["chance"])


func test_a_refused_file_has_no_models_and_nothing_beside_them() -> void:
	# The property that matters more than the message: a half-read file must
	# not leave a model predicting from whatever survived.
	var published: ModelFile = ModelFile.from_dictionary({"radius": 2}, "nothing")

	assert_object(published.model("chance")).is_null()
	assert_array(published.model_names()).is_empty()
	assert_dict(published.extra).is_empty()


func test_the_fields_beside_the_models_are_handed_over_unread() -> void:
	# Never checked here, and never refused: what they must hold is the
	# publishing game's rule. The copy is the reader's, so changing it cannot
	# reach back into the data the file was built from.
	var data: Dictionary = SOUND.duplicate(true)
	data["radius"] = {"nearby": 2}
	var published: ModelFile = ModelFile.from_dictionary(data, "the test")
	published.extra["radius"]["nearby"] = 9

	assert_str(published.error).is_empty()
	assert_array(published.extra.keys()).contains_exactly(["radius"])
	assert_int(int(data["radius"]["nearby"])).is_equal(2)


func test_a_file_with_nothing_but_a_model_loads() -> void:
	# The defect this file's rules had until wave 99: a file was refused for
	# lacking one game's own fields, so no other game could use the loader.
	var published: ModelFile = ModelFile.from_dictionary(SOUND.duplicate(true), "the test")

	assert_str(published.error).is_empty()
	assert_str(published.generated_by).is_equal("unknown")


# The vector, from the spec directory beside the Godot project.
func _vector() -> Dictionary:
	var path: String = ProjectSettings.globalize_path("res://").path_join(
		"../spec/vectors/model_file/refusals.json")
	return JSON.parse_string(FileAccess.get_file_as_string(path))


# What `ModelFile` makes of one case: a code, or what loaded, in one string.
func _answer(case: Dictionary) -> String:
	var published: ModelFile
	if case.has("text"):
		published = ModelFile.from_text(case["text"], "the vector")
	else:
		published = ModelFile.from_dictionary(case["file"], "the vector")
	if not published.is_loaded():
		return published.error.get_slice(" ", 0)
	var extra: Array = published.extra.keys()
	extra.sort()
	return "loads %s beside %s" % [Array(published.model_names()), extra]


# What the vector claims about the same case, in the same string.
func _claimed(case: Dictionary) -> String:
	if case.has("refused"):
		return case["refused"]
	var loads: Array = case["loads"].duplicate()
	loads.sort()
	var extra: Array = case["extra"].duplicate()
	extra.sort()
	return "loads %s beside %s" % [loads, extra]


# The one model in `SOUND`.
func _chance() -> LearnedModel:
	return ModelFile.from_dictionary(SOUND.duplicate(true), "the test").model("chance")
