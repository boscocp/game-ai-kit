# The addon's three pieces, each held to the thing it is easy to get wrong:
# the model to its arithmetic, the file to its refusals, and the features to
# the conventions the training published.
#
# The conformance vectors in spec/vectors/learning/ already hold the model and
# the features against the Python side. These are the claims that have no
# Python half to disagree with -- every way a weights file can be malformed,
# and the clamp that reads terrain the data never covered.
extends GdUnitTestSuite

const SOUND: Dictionary = {
	"generated_by": "gameaikit.training.report",
	"feature_conventions": {
		"nearby_radius": 2,
		"reinforcement_distance_when_alone": 15,
		"cheapest_ground": 1,
		"dearest_ground": 3,
	},
	"models": {
		"combat": {
			"kind": "logistic",
			"features": ["health_difference", "numeric_advantage",
				"defender_terrain", "reinforcement_distance"],
			"weights": [0.5, 2.0, -1.5, -0.125],
			"bias": 3.0,
		},
		"capture": {
			"kind": "linear",
			"features": ["distance_to_node", "own_units", "enemy_units",
				"terrain_on_the_way"],
			"weights": [0.7, 0.1, 0.1, 0.4],
			"bias": 1.0,
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
	var model: LearnedModel = _published().model("combat")

	assert_bool(is_nan(model.predict(PackedFloat64Array([1.0])))).is_true()


func test_nan_cannot_be_mistaken_for_clearing_a_threshold() -> void:
	# The property the rest of the addon rests on: a row nobody could read is
	# never an attack. Asserted rather than assumed, because it is a property
	# of the comparison and not of the model.
	var model: LearnedModel = _published().model("combat")
	var nothing: float = model.predict(PackedFloat64Array([]))

	assert_bool(nothing >= LearnedPolicy.DEFAULT_THRESHOLD).is_false()


func test_a_named_row_is_read_by_name_and_not_by_the_order_it_was_built_in() -> void:
	# The weight order is the published contract. A caller handing over a
	# dictionary cannot get it wrong, which is the whole reason this call
	# exists beside the one taking an array.
	var model: LearnedModel = _published().model("combat")
	var forwards: float = model.predict_named({
		"health_difference": 4, "numeric_advantage": 1,
		"defender_terrain": 2, "reinforcement_distance": 3,
	})
	var backwards: float = model.predict_named({
		"reinforcement_distance": 3, "defender_terrain": 2,
		"numeric_advantage": 1, "health_difference": 4,
	})

	assert_float(forwards).is_equal_approx(backwards, 1e-15)
	assert_float(forwards).is_equal_approx(0.9740426428022031, 1e-12)


func test_a_named_row_missing_a_feature_answers_nan() -> void:
	var model: LearnedModel = _published().model("combat")

	assert_bool(is_nan(model.predict_named({"health_difference": 4}))).is_true()


func test_the_sigmoid_survives_the_row_that_overflows_the_obvious_spelling() -> void:
	# `1.0 / (1.0 + exp(-value))` returns inf for the second of these, and a
	# model that dies on one unusual row dies mid-game.
	assert_float(LearnedModel.sigmoid(800.0)).is_equal_approx(1.0, 1e-12)
	assert_float(LearnedModel.sigmoid(-800.0)).is_equal_approx(0.0, 1e-12)


func test_a_sound_file_publishes_both_models_and_its_conventions() -> void:
	var published: ModelFile = _published()

	assert_str(published.error).is_empty()
	assert_array(published.model_names()).contains_exactly(["capture", "combat"])
	assert_int(published.convention("nearby_radius")).is_equal(2)
	assert_int(published.convention("reinforcement_distance_when_alone")).is_equal(15)


func test_the_published_weights_load() -> void:
	# Not a duplicate of the above: this is the file `make train` wrote and
	# the game loads, read through the same rules as everything else.
	var published: ModelFile = ModelFile.load_from(ModelFile.DEFAULT_PATH)

	assert_str(published.error).is_empty()
	assert_str(published.generated_by).contains("gameaikit.training")


func test_a_missing_file_is_refused_by_name() -> void:
	var published: ModelFile = ModelFile.load_from("res://addons/ai_learning/nothing.json")

	assert_str(published.error).contains("M1")
	assert_bool(published.is_loaded()).is_false()


func test_a_file_that_is_not_json_is_refused() -> void:
	var path: String = "user://not-a-model.txt"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("weights: lots\n")
	file.close()

	assert_str(ModelFile.load_from(path).error).contains("M2")


func test_a_refused_file_has_no_models_at_all() -> void:
	# The property that matters more than the message: a half-read file must
	# not leave a model predicting from whatever survived.
	var published: ModelFile = ModelFile.from_dictionary({}, "nothing")

	assert_object(published.model("combat")).is_null()
	assert_array(published.model_names()).is_empty()


func test_a_file_publishing_no_models_is_refused() -> void:
	assert_str(_but({"models": {}}).error).contains("M3")


func test_a_model_missing_a_field_is_refused() -> void:
	var model: Dictionary = _a_model()
	model.erase("bias")

	assert_str(_with_model(model).error).contains("M4")


func test_a_kind_nothing_can_evaluate_is_refused() -> void:
	# Named rather than guessed at. A file asking for a kind of model this
	# addon does not implement is a file from a later lesson, and quietly
	# treating it as linear would answer with great confidence.
	assert_str(_with_model(_a_model({"kind": "random_forest"})).error).contains("M5")


func test_a_feature_listed_twice_is_refused() -> void:
	# Rows are matched by name, so a name appearing twice is a weight that
	# can never be applied and a row that quietly means something else.
	var model: Dictionary = _a_model({"features": ["one", "one"], "weights": [1.0, 2.0]})

	assert_str(_with_model(model).error).contains("M6")


func test_a_model_with_no_features_is_refused() -> void:
	assert_str(_with_model(_a_model({"features": [], "weights": []})).error).contains("M6")


func test_a_weight_missing_from_a_feature_is_refused() -> void:
	var model: Dictionary = _a_model({"features": ["one", "two"], "weights": [1.0]})

	assert_str(_with_model(model).error).contains("M7")


func test_a_weight_that_is_not_a_number_is_refused() -> void:
	assert_str(_with_model(_a_model({"weights": ["heavy"]})).error).contains("M8")


func test_an_infinite_bias_is_refused() -> void:
	# JSON cannot spell an infinity, and `1e400` parses to one. A bias of inf
	# multiplies every feature into the same answer.
	assert_str(_with_model(_a_model({"bias": INF})).error).contains("M8")


func test_a_file_with_no_conventions_is_refused() -> void:
	var data: Dictionary = SOUND.duplicate(true)
	data.erase("feature_conventions")

	assert_str(ModelFile.from_dictionary(data, "the test").error).contains("M9")


func test_a_radius_of_zero_is_refused() -> void:
	# Zero is what a missing key reads as the moment somebody writes
	# `get(name, 0)` on the other side, and it is a radius that counts nobody.
	assert_str(_but({"feature_conventions": {
		"nearby_radius": 0,
		"reinforcement_distance_when_alone": 15,
		"cheapest_ground": 1,
		"dearest_ground": 3,
	}}).error).contains("M9")


func test_a_convention_nobody_publishes_answers_minus_one() -> void:
	assert_int(_published().convention("neerby_radius")).is_equal(-1)


func test_a_wall_reads_as_the_dearest_ground_the_data_covered() -> void:
	# The simulator never generated a wall, so there is no honest number for
	# one. -1 is the worst possible answer: a weight of -1.6 on terrain turns
	# it into a bonus.
	var graph := GridGraph.new(3, 3)
	graph.block(Vector2i(1, 1))

	assert_int(BoardFeatures.terrain_at(graph, Vector2i(1, 1), _published())).is_equal(3)


func test_ground_dearer_than_the_data_is_clamped_to_what_the_data_had() -> void:
	var graph := GridGraph.new(3, 3)
	graph.set_cost(Vector2i(1, 1), 9)

	assert_int(BoardFeatures.terrain_at(graph, Vector2i(1, 1), _published())).is_equal(3)


func test_a_cell_off_the_board_reads_as_the_dearest_ground_too() -> void:
	assert_int(BoardFeatures.terrain_at(
		GridGraph.new(3, 3), Vector2i(9, 9), _published())).is_equal(3)


func test_a_unit_already_on_the_node_has_the_cheapest_ground_on_the_way() -> void:
	# No cells are entered, so there is no terrain to average. Zero would be
	# a cost no board can produce, and the mean of nothing is not zero.
	var state := BoardState.new(GridGraph.new(4, 4), [
		Unit.new(1, 0, Vector2i(2, 2), 10, 3),
	] as Array[Unit], 0)

	var row: Dictionary = BoardFeatures.capture_row(state, 0, Vector2i(2, 2), _published())

	assert_float(row["terrain_on_the_way"]).is_equal_approx(1.0, 1e-12)
	assert_int(row["distance_to_node"]).is_equal(0)


func test_a_side_with_nothing_on_the_board_produces_no_row() -> void:
	# An empty row rather than a row of zeros: zeros are a position, and a
	# side with no units does not have one.
	var state := BoardState.new(GridGraph.new(4, 4), [
		Unit.new(1, 0, Vector2i(2, 2), 10, 3),
	] as Array[Unit], 0)

	assert_dict(BoardFeatures.capture_row(state, 1, Vector2i(0, 0), _published())).is_empty()


# A sound published file, as the game would have loaded one.
func _published() -> ModelFile:
	return ModelFile.from_dictionary(SOUND.duplicate(true), "the test")


# The sound file with something replaced, for a rule to object to.
#
# Replaced, never removed: `merge` puts keys in. A test that needs a key gone
# builds the dictionary itself, which is a distinction this helper cost a
# green run to make.
func _but(changed: Dictionary) -> ModelFile:
	var data: Dictionary = SOUND.duplicate(true)
	data.merge(changed, true)
	return ModelFile.from_dictionary(data, "the test")


# A single-feature model, with whatever this case needs changed about it.
func _a_model(changed: Dictionary = {}) -> Dictionary:
	var model: Dictionary = {
		"kind": "linear", "features": ["one"], "weights": [1.0], "bias": 0.0,
	}
	model.merge(changed, true)
	return model


# The sound file with one model replaced by a broken one.
func _with_model(model: Dictionary) -> ModelFile:
	return _but({"models": {"only": model}})
