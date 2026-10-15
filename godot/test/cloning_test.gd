# T18: the situation in words, a recording cut into rows, the cloned player's
# refusals, and the opponent that imitates it.
extends GdUnitTestSuite

var _data: FightData


func before_test() -> void:
	_data = FightData.read()


func test_a_situation_is_six_words_read_off_the_fight() -> void:
	var state: FightState = FightState.starting(_data, "lancer", "dancer")
	var situation: Dictionary = FightSituation.of(state, 0, "", _data)
	assert_array(situation.keys()).contains_exactly_in_any_order(FightSituation.FEATURES)
	assert_dict(situation).is_equal({"last": "nothing", "other": "nothing", "me": "free", "distance": "far",
			"health": "even", "corner": "no"})
	state.fighters[0].x = 40
	state.fighters[1].x = 100
	state.fighters[0].health -= 300
	state.fighters[1].crouching = true
	situation = FightSituation.of(state, 0, "low", _data)
	assert_dict(situation).is_equal({"last": "low", "other": "crouch", "me": "free", "distance": "close",
			"health": "behind", "corner": "yes"})


func test_a_recording_is_cut_at_each_new_action_from_what_was_seen_a_reaction_before() -> void:
	var inputs: Array = []
	for frame: int in range(40):
		inputs.append([FightInput.RIGHT if frame < 30 else FightInput.DOWN, 0])
	var rows: Array[Dictionary] = FightRecording.rows_of({"characters": ["lancer", "dancer"], "inputs": inputs}, _data)
	assert_array(rows.map(func(row: Dictionary) -> String: return row["action"])).is_equal(["step in", "crouch"])
	assert_str(rows[1]["situation"]["last"]).is_equal("step in")
	# The crouch began on frame 31; what the player saw was frame 16, still walking in.
	assert_str(rows[1]["situation"]["distance"]).is_equal("far")


func test_a_fight_too_short_to_be_one_is_not_kept() -> void:
	var folder: String = "user://recordings_test"
	assert_str(FightRecording.save([[0, 0]], ["lancer", "dancer"] as Array[String], "stand", "person", folder)).is_empty()


func test_a_recording_missing_what_it_needs_is_named() -> void:
	assert_str(FightRecording.why_not_a_recording([])).contains("not a JSON object")
	assert_str(FightRecording.why_not_a_recording({"player": "p", "inputs": []})).contains("characters")
	assert_str(FightRecording.why_not_a_recording({"player": "p", "characters": ["a"], "inputs": []})).contains("two")


func test_each_refusal_of_a_cloned_player_has_its_code() -> void:
	assert_str(ClonedPlayer.load_from("res://nowhere.json").error).starts_with("C1")
	assert_str(ClonedPlayer.from_dictionary([]).error).starts_with("C3")
	var good: Dictionary = _small_player()
	var planted: Dictionary = good.duplicate(true)
	planted.erase("cases")
	assert_str(ClonedPlayer.from_dictionary(planted).error).starts_with("C3")
	planted = good.duplicate(true)
	planted["model"]["bias"] = [0.0]
	assert_str(ClonedPlayer.from_dictionary(planted).error).starts_with("C5")
	planted = good.duplicate(true)
	planted["model"]["weights"][0][0] = "heavy"
	assert_str(ClonedPlayer.from_dictionary(planted).error).starts_with("C6")
	var loaded: ClonedPlayer = ClonedPlayer.from_dictionary(good)
	assert_str(loaded.error).is_empty()
	assert_object(loaded.model).is_not_null()


func test_the_published_player_loads() -> void:
	var published: ClonedPlayer = ClonedPlayer.load_from()
	assert_str(published.error).is_empty()
	assert_int(published.cases.cases.size()).is_greater(0)


func test_the_clone_does_what_its_player_did_and_says_where_it_found_it() -> void:
	var player: ClonedPlayer = ClonedPlayer.from_dictionary(_small_player())
	var state: FightState = FightState.starting(_data, "lancer", "lancer")
	for source: String in FightCloneOpponent.SOURCES:
		var clone := FightCloneOpponent.new(source, player, _data, 3)
		clone.choose(state, 1)
		assert_str(clone.found).is_not_equal("nothing seen yet")
		assert_array(clone.considered.map(func(option: Array) -> String: return option[0])).contains(["step in"])


func test_an_unloaded_player_makes_an_opponent_that_guards_and_says_why() -> void:
	var clone := FightCloneOpponent.new("clone", ClonedPlayer.load_from("res://nowhere.json"), _data)
	clone.choose(FightState.starting(_data, "lancer", "lancer"), 1)
	assert_str(clone.found).contains("no recorded player")
	assert_array(clone.considered).is_equal([["guard standing", 1]])


# A cloned player that only ever stepped in, far away.
func _small_player() -> Dictionary:
	var key: String = "nothing | nothing | free | far | even | no"
	return {"generated_by": "a test", "trained_on": {"player": "someone", "recordings": []},
			"features": FightSituation.FEATURES, "classes": ["step in", "throw"],
			"model": {"kind": "softmax", "columns": ["distance=far"], "weights": [[2.0], [-2.0]], "bias": [0.0, 0.0]},
			"cases": {key: {"step in": 3}}}
