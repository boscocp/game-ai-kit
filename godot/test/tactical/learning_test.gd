# The tactical game's side of its learned models: its weights file held to
# the conventions the training published, and the features to those
# conventions. The model's arithmetic and every way a model file in general
# can be malformed are the addon's, in test/ai_learning/model_file_test.gd.
#
# The conformance vectors in spec/vectors/learning/ already hold the features
# against the Python side. These are the claims that have no Python half to
# disagree with -- the clamp that reads terrain the data never covered -- and
# the conventions' refusals, which `gameaikit.tactical.report` holds too.
extends GdUnitTestSuite

const SOUND: Dictionary = {
	"generated_by": "gameaikit.tactical.report",
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


# These tests read the English words. The engine starts in the system's
# locale, so on a Portuguese system they would read the pt-BR ones (T79);
# the Portuguese screen is test/locale's. The locale found is put back.
var _locale_before: String


func before() -> void:
	_locale_before = TranslationServer.get_locale()
	TranslationServer.set_locale("en")


func after() -> void:
	TranslationServer.set_locale(_locale_before)


func test_nan_cannot_be_mistaken_for_clearing_a_threshold() -> void:
	# The property the rest of the addon rests on: a row nobody could read is
	# never an attack. Asserted rather than assumed, because it is a property
	# of the comparison and not of the model.
	var model: LearnedModel = _published().model("combat")
	var nothing: float = model.predict(PackedFloat64Array([]))

	assert_bool(nothing >= LearnedPolicy.DEFAULT_THRESHOLD).is_false()


func test_a_sound_file_publishes_both_models_and_its_conventions() -> void:
	var published: TacticalWeights = _published()

	assert_str(published.error).is_empty()
	assert_array(published.model_names()).contains_exactly(["capture", "combat"])
	assert_int(published.convention("nearby_radius")).is_equal(2)
	assert_int(published.convention("reinforcement_distance_when_alone")).is_equal(15)


func test_the_published_weights_load() -> void:
	# Not a duplicate of the above: this is the file `make train` wrote and
	# the game loads, read through the same rules as everything else.
	var published: TacticalWeights = TacticalWeights.load_from(LearnedPolicy.WEIGHTS_PATH)

	assert_str(published.error).is_empty()
	assert_str(published.generated_by()).contains("gameaikit.tactical")


func test_a_missing_file_is_refused_by_name_and_says_how_to_make_one() -> void:
	var published: TacticalWeights = TacticalWeights.load_from("res://game/tactical/nothing.json")

	assert_str(published.error).starts_with("M1 ")
	assert_str(published.error).contains("make train")
	assert_bool(published.is_loaded()).is_false()


func test_a_file_refused_for_its_conventions_has_no_models_at_all() -> void:
	# The property that matters more than the message: the addon loaded both
	# models, and this game's refusal must still leave none to predict with.
	var data: Dictionary = SOUND.duplicate(true)
	data.erase("feature_conventions")
	var published: TacticalWeights = TacticalWeights.from_dictionary(data, "the test")

	assert_object(published.model("combat")).is_null()
	assert_array(published.model_names()).is_empty()
	assert_str(published.generated_by()).is_empty()


func test_a_file_the_addon_refuses_is_refused_in_the_addon_s_words() -> void:
	assert_str(_but({"models": {}}).error).starts_with("M3 ")


func test_a_file_with_no_conventions_is_refused() -> void:
	var data: Dictionary = SOUND.duplicate(true)
	data.erase("feature_conventions")

	assert_str(TacticalWeights.from_dictionary(data, "the test").error).starts_with(
		"W6 the file publishes no feature_conventions block")


func test_a_radius_of_zero_is_refused() -> void:
	# Zero is what a missing key reads as the moment somebody writes
	# `get(name, 0)` on the other side, and it is a radius that counts nobody.
	assert_str(_but({"feature_conventions": {
		"nearby_radius": 0,
		"reinforcement_distance_when_alone": 15,
		"cheapest_ground": 1,
		"dearest_ground": 3,
	}}).error).starts_with("W6 feature_conventions.nearby_radius is 0")


func test_a_radius_with_a_fraction_is_refused() -> void:
	# The Python side publishes whole numbers and holds them to it; a radius
	# of 2.5 counts the same friends as 2, and says it counts more.
	assert_str(_but({"feature_conventions": {
		"nearby_radius": 2.5,
		"reinforcement_distance_when_alone": 15,
		"cheapest_ground": 1,
		"dearest_ground": 3,
	}}).error).starts_with("W6 feature_conventions.nearby_radius is 2.5")


func test_a_terrain_range_the_wrong_way_round_is_refused() -> void:
	# Both numbers are positive and the pair is nonsense. Unrefused, the
	# clamp in `BoardFeatures` runs with a minimum above its maximum, which
	# `clampi` answers rather than objects to.
	assert_str(_but({"feature_conventions": {
		"nearby_radius": 2,
		"reinforcement_distance_when_alone": 15,
		"cheapest_ground": 3,
		"dearest_ground": 1,
	}}).error).starts_with("W7 ")


func test_a_convention_nobody_publishes_answers_minus_one() -> void:
	assert_int(_published().convention("neerby_radius")).is_equal(-1)


func test_a_friend_further_away_than_the_sentinel_is_not_reported_as_absent() -> void:
	# The sentinel is a fallback, never a cap. Seeding the search with it made
	# "I am alone" and "my nearest friend is seventeen cells away" the same
	# number -- on a board wider than the one the data came from, which is the
	# board `make run` ships.
	var state := BoardState.new(GridGraph.new(20, 3), [
		Unit.new(1, 0, Vector2i(0, 0), 10, 3),
		Unit.new(2, 0, Vector2i(19, 1), 10, 3),
		Unit.new(3, 1, Vector2i(1, 0), 10, 3),
	] as Array[Unit], 0)

	var row: Dictionary = BoardFeatures.combat_row(
		state, state.unit_by_id(1), state.unit_by_id(3), _published())

	assert_int(row["reinforcement_distance"]).is_equal(20)


func test_a_unit_with_no_friends_left_reports_the_sentinel() -> void:
	var state := BoardState.new(GridGraph.new(20, 3), [
		Unit.new(1, 0, Vector2i(0, 0), 10, 3),
		Unit.new(3, 1, Vector2i(1, 0), 10, 3),
	] as Array[Unit], 0)

	var row: Dictionary = BoardFeatures.combat_row(
		state, state.unit_by_id(1), state.unit_by_id(3), _published())

	assert_int(row["reinforcement_distance"]).is_equal(15)


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


func test_enemy_units_counts_every_side_that_is_not_mine() -> void:
	# Deliberate, and a divergence: Python counts `living(1 - faction)`, which
	# is "the other side" and means nothing with three of them. Pinned here so
	# that the generalisation is a decision rather than an accident -- and
	# read the note on `capture_row` before relying on this feature at all on
	# a board with three sides.
	var state := BoardState.new(GridGraph.new(6, 6), [
		Unit.new(1, 0, Vector2i(0, 0), 10, 3),
		Unit.new(2, 1, Vector2i(1, 0), 10, 3),
		Unit.new(3, 2, Vector2i(2, 0), 10, 3),
		Unit.new(4, 2, Vector2i(3, 0), 10, 3),
	] as Array[Unit], 0)

	var row: Dictionary = BoardFeatures.capture_row(state, 0, Vector2i(5, 5), _published())

	assert_int(row["own_units"]).is_equal(1)
	assert_int(row["enemy_units"]).is_equal(3)


func test_a_side_with_nothing_on_the_board_produces_no_row() -> void:
	# An empty row rather than a row of zeros: zeros are a position, and a
	# side with no units does not have one.
	var state := BoardState.new(GridGraph.new(4, 4), [
		Unit.new(1, 0, Vector2i(2, 2), 10, 3),
	] as Array[Unit], 0)

	assert_dict(BoardFeatures.capture_row(state, 1, Vector2i(0, 0), _published())).is_empty()


# A sound published file, as the game would have loaded one.
func _published() -> TacticalWeights:
	return TacticalWeights.from_dictionary(SOUND.duplicate(true), "the test")


# The sound file with something replaced, for a rule to object to.
#
# Replaced, never removed: `merge` puts keys in. A test that needs a key gone
# builds the dictionary itself, which is a distinction this helper cost a
# green run to make.
func _but(changed: Dictionary) -> TacticalWeights:
	var data: Dictionary = SOUND.duplicate(true)
	data.merge(changed, true)
	return TacticalWeights.from_dictionary(data, "the test")

