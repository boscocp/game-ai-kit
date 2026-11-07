# T114: the learner with a random forest reading you -- the published forest
# is the one the game reads you with, the same situation gets the same votes,
# a unanimous vote leans the whole weight, and the votes are shown.
extends GdUnitTestSuite

var _data: FightData
var _locale_before: String


func before() -> void:
	_locale_before = TranslationServer.get_locale()
	TranslationServer.set_locale("en")


func after() -> void:
	TranslationServer.set_locale(_locale_before)


func before_test() -> void:
	_data = FightData.read()


# A model file publishing one forest, `trees` its trees, over the situation's words.
func _file_with(trees: Array) -> ModelFile:
	return ModelFile.from_dictionary({"models": {FightForestOpponent.MODEL_NAME: {"kind": "forest",
		"features": FightSituation.FEATURES, "classes": FightAction.ACTIONS, "trees": trees}}}, "the test")


func _published() -> ModelFile:
	return ModelFile.load_from(FightForestOpponent.FOREST_PATH)


func test_the_published_forest_reads_the_situation_the_rows_were_cut_with() -> void:
	var published: ModelFile = _published()
	assert_str(published.error).is_empty()
	var forest: LearnedForest = published.forest(FightForestOpponent.MODEL_NAME)
	assert_int(forest.trees.size()).is_equal(25)
	assert_array(Array(forest.features)).is_equal(FightSituation.FEATURES)
	assert_array(Array(forest.classes)).is_equal(FightAction.ACTIONS)


func test_the_same_situation_gets_the_same_votes_every_time() -> void:
	var voter := FightForestOpponent.new("medium", _published(), _data)
	var state: FightState = FightState.starting(_data, "lancer", "dancer")
	var votes: Array = []
	for time: int in range(3):
		voter._decide(state, 1)
		votes.append(Array(voter.cast))
		assert_int(voter.cast.size()).is_equal(25)
		assert_str(voter.expected).is_equal(voter.forest.likeliest(voter.person_situation))
	assert_array(votes[1]).is_equal(votes[0])
	assert_array(votes[2]).is_equal(votes[0])


func test_a_unanimous_vote_leans_the_whole_weight_towards_its_answers() -> void:
	var voter := FightForestOpponent.new("hard", _file_with([[{"counts": {"high": 5}}], [{"counts": {"high": 1}}]]), _data)
	var unsure: Array = FightOpponent.SITUATIONS["neutral"]
	voter._decide(FightState.starting(_data, "lancer", "dancer"), 1)
	var sure: Array = voter._weighted_options("neutral", "lancer")
	assert_str(voter.expected).is_equal("high")
	assert_float(voter.confidence).is_equal(1.0)
	for index: int in range(sure.size()):
		var gained: int = int(sure[index][1]) - int(unsure[index][1])
		var answers: bool = sure[index][0] in FightModelOpponent.ANSWERS["high"]
		assert_int(gained).is_equal(FightModelOpponent.LEAN if answers else 0)


func test_a_split_vote_leans_by_its_share() -> void:
	var voter := FightForestOpponent.new("hard", _file_with([[{"counts": {"high": 5}}], [{"counts": {"low": 1}}]]), _data)
	voter._decide(FightState.starting(_data, "lancer", "dancer"), 1)
	assert_dict(voter.tally).is_equal({"high": 1, "low": 1})
	assert_str(voter.expected).is_equal("high")
	assert_float(voter.confidence).is_equal(0.5)


# The planted case for the refusal: a broken file seats an opponent that
# expects nothing and says why, rather than one that asks half a forest.
func test_a_refused_forest_expects_nothing_and_says_why() -> void:
	var voter := FightForestOpponent.new("medium", _file_with([[{"counts": {"high": 1}}], []]), _data)
	assert_object(voter.forest).is_null()
	assert_str(voter.refusal).starts_with("M16")
	voter._decide(FightState.starting(_data, "lancer", "dancer"), 1)
	assert_str(voter.expected).is_equal("nothing yet")
	assert_bool(voter.has_read()).is_false()
	var seat := FightDelay.new(voter, 1)
	var panel: String = FightingPanel.describe(FightState.starting(_data, "lancer", "dancer"), _data, true, seat)
	assert_str(panel).contains("it reads you with no forest: M16")


func test_a_file_with_only_a_tree_by_that_name_is_said_so() -> void:
	var tree_file := ModelFile.load_from(FightTreeOpponent.PUBLISHED_PATH)
	assert_str(FightForestOpponent.new("medium", tree_file, _data).refusal).contains("no forest named")


func test_its_guesses_are_scored_when_you_start_a_new_action() -> void:
	var voter := FightForestOpponent.new("medium", _file_with([[{"counts": {"high": 5}}]]), _data)
	var state: FightState = FightState.starting(_data, "lancer", "dancer")
	voter._decide(state, 1)
	state.fighters[0].move = "jab"
	voter.watch(state, 1)
	assert_array(voter.forest_score()).is_equal([1, 1])
	voter.new_fight()
	assert_array(voter.tree_guesses).is_empty()
	assert_bool(voter.has_read()).is_false()
	assert_dict(voter.tally).is_empty()


func test_the_training_mode_shows_every_vote_and_the_tally() -> void:
	var scene: FightingExample = auto_free(load("res://game/fighting/fighting.tscn").instantiate())
	add_child(scene)
	scene.paused = true
	scene.dummy_mode = "forest: medium"
	for frame: int in range(150):
		var press: int = FightInput.LIGHT_PUNCH if frame % 35 == 0 else 0
		scene.state = FightRules.step(scene.state, [press, scene._dummy_input()] as Array[int], _data)
	var shown: Dictionary = scene.opponent_overlay()
	assert_bool(shown["forest_votes"] is Array).is_true()
	assert_int((shown["forest_votes"] as Array).size()).is_equal(25)
	assert_bool(shown["tally"] is Dictionary).is_true()
	assert_str(shown["expects"]).is_not_empty()
	var panel: String = FightingPanel.describe(scene.state, _data, true, scene.seat)
	assert_str(panel).contains("its random forest of 25 trees, right").contains("  trees 21 to 25 voted: ") \
		.contains("  tally: ").contains("% of the votes; the n-gram expects")
