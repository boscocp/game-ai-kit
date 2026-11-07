# T113: the learner with a decision tree reading you -- the published tree
# is the one the game reads you with, a situation is answered the same way
# every time, a sure leaf leans its whole weight, and the path is shown.
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


# A model file publishing one tree, `nodes` its nodes, over the situation's words.
func _file_with(nodes: Array) -> ModelFile:
	return ModelFile.from_dictionary({"models": {FightTreeOpponent.MODEL_NAME: {"kind": "tree",
		"features": FightSituation.FEATURES, "classes": FightAction.ACTIONS, "nodes": nodes}}}, "the test")


func test_the_published_tree_reads_the_situation_the_rows_were_cut_with() -> void:
	var published := ModelFile.load_from(FightTreeOpponent.PUBLISHED_PATH)
	assert_str(published.error).is_empty()
	var tree: LearnedTree = published.tree(FightTreeOpponent.MODEL_NAME)
	assert_array(Array(tree.features)).is_equal(FightSituation.FEATURES)
	assert_array(Array(tree.classes)).is_equal(FightAction.ACTIONS)


# The manual check's half a command can hold: the same situation, three
# times, takes the same path to the leaf that predicts the answer.
func test_the_same_situation_is_answered_the_same_way_every_time() -> void:
	var reader := FightTreeOpponent.new("medium", ModelFile.load_from(FightTreeOpponent.PUBLISHED_PATH), _data)
	var state: FightState = FightState.starting(_data, "lancer", "dancer")
	var paths: Array = []
	for time: int in range(3):
		reader._decide(state, 1)
		paths.append(reader.walked.map(func(step: Dictionary) -> int: return step["node"]))
		var leaf: Dictionary = reader.walked.back()
		assert_bool(leaf.has("counts")).is_true()
		assert_str(reader.expected).is_equal(reader.reader.likeliest(reader.person_situation))
	assert_array(paths[1]).is_equal(paths[0])
	assert_array(paths[2]).is_equal(paths[0])


func test_it_reads_your_situation_not_its_own() -> void:
	var reader := FightTreeOpponent.new("medium", ModelFile.load_from(FightTreeOpponent.PUBLISHED_PATH), _data)
	var state: FightState = FightState.starting(_data, "lancer", "dancer")
	state.fighters[0].move = "jab"
	reader.choose(state, 1)
	assert_dict(reader.person_situation).is_equal(FightSituation.of(state, 0, "high", _data))


func test_a_leaf_that_saw_one_action_leans_the_whole_weight_towards_its_answers() -> void:
	var reader := FightTreeOpponent.new("hard", _file_with([{"counts": {"high": 5}}]), _data)
	var unsure: Array = FightOpponent.SITUATIONS["neutral"]
	reader._decide(FightState.starting(_data, "lancer", "dancer"), 1)
	var sure: Array = reader._weighted_options("neutral", "lancer")
	assert_str(reader.expected).is_equal("high")
	assert_float(reader.confidence).is_equal(1.0)
	for index: int in range(sure.size()):
		var gained: int = int(sure[index][1]) - int(unsure[index][1])
		var answers: bool = sure[index][0] in FightModelOpponent.ANSWERS["high"]
		assert_int(gained).is_equal(FightModelOpponent.LEAN if answers else 0)


func test_a_leaf_no_surer_than_chance_leans_nothing() -> void:
	var even: Dictionary = {}
	for action: String in FightAction.ACTIONS:
		even[action] = 1
	var reader := FightTreeOpponent.new("hard", _file_with([{"counts": even}]), _data)
	reader._decide(FightState.starting(_data, "lancer", "dancer"), 1)
	assert_array(reader._weighted_options("neutral", "lancer")).is_equal(FightOpponent.SITUATIONS["neutral"])


# The planted case for the refusal: a broken file seats an opponent that
# expects nothing and says why, rather than one that walks half a tree.
func test_a_refused_tree_expects_nothing_and_says_why() -> void:
	var reader := FightTreeOpponent.new("medium", _file_with([{"feature": "corner", "is": "yes", "yes": 0, "no": 0}]), _data)
	assert_object(reader.reader).is_null()
	assert_str(reader.refusal).starts_with("M14")
	reader._decide(FightState.starting(_data, "lancer", "dancer"), 1)
	assert_str(reader.expected).is_equal("nothing yet")
	assert_bool(reader.answered).is_false()
	var seat := FightDelay.new(reader, 1)
	var panel: String = FightingPanel.describe(FightState.starting(_data, "lancer", "dancer"), _data, true, seat)
	assert_str(panel).contains("it reads you with no tree: M14")


func test_a_file_with_no_tree_by_that_name_is_said_so() -> void:
	var weighted := ModelFile.from_dictionary({"models": {"chance": {"kind": "linear", "features": ["one"],
		"weights": [1.0], "bias": 0.0}}}, "the test")
	assert_str(FightTreeOpponent.new("medium", weighted, _data).refusal).contains("no tree named")


func test_its_guesses_are_scored_when_you_start_a_new_action() -> void:
	var reader := FightTreeOpponent.new("medium", _file_with([{"counts": {"high": 5}}]), _data)
	var state: FightState = FightState.starting(_data, "lancer", "dancer")
	reader._decide(state, 1)
	state.fighters[0].move = "jab"
	reader.watch(state, 1)
	state.fighters[0].move = ""
	state.fighters[0].held_before = FightInput.RIGHT
	reader.watch(state, 1)
	assert_array(reader.tree_score()).is_equal([1, 2])
	reader.new_fight()
	assert_array(reader.tree_guesses).is_empty()
	assert_array(reader.walked).is_empty()


func test_the_training_mode_shows_the_path_and_the_leaf() -> void:
	var scene: FightingExample = auto_free(load("res://game/fighting/fighting.tscn").instantiate())
	add_child(scene)
	scene.paused = true
	scene.dummy_mode = "tree: medium"
	for frame: int in range(150):
		var press: int = FightInput.LIGHT_PUNCH if frame % 35 == 0 else 0
		scene.state = FightRules.step(scene.state, [press, scene._dummy_input()] as Array[int], _data)
	var shown: Dictionary = scene.opponent_overlay()
	assert_bool(shown["tree_path"] is Array).is_true()
	assert_bool(shown["leaf"] is Dictionary).is_true()
	assert_str(shown["expects"]).is_not_empty()
	var panel: String = FightingPanel.describe(scene.state, _data, true, scene.seat)
	assert_str(panel).contains("its decision tree, right").contains("  leaf: ").contains("the n-gram expects")
