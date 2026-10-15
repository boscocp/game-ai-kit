# T17: the learner -- what it reads as an action, that it learns only from
# the late fight it is handed, and how far a prediction leans its choices.
extends GdUnitTestSuite

var _data: FightData


func before_test() -> void:
	_data = FightData.read()


func test_an_action_is_read_off_the_fighter_as_it_was_drawn() -> void:
	var state: FightState = FightState.starting(_data, "lancer", "dancer")
	var lancer: FighterState = state.fighters[0]
	assert_str(FightModelOpponent.action_of(state, 0, _data)).is_empty()
	lancer.held_before = FightInput.RIGHT
	assert_str(FightModelOpponent.action_of(state, 0, _data)).is_equal("step in")
	lancer.held_before = FightInput.LEFT
	assert_str(FightModelOpponent.action_of(state, 0, _data)).is_equal("step out")
	lancer.crouching = true
	assert_str(FightModelOpponent.action_of(state, 0, _data)).is_equal("crouch")
	lancer.stun = 5
	lancer.stun_kind = "block"
	assert_str(FightModelOpponent.action_of(state, 0, _data)).is_equal("guard crouching")
	lancer.stun_kind = "hit"
	assert_str(FightModelOpponent.action_of(state, 0, _data)).is_empty()
	lancer.stun = 0
	lancer.move = "axe_kick"
	assert_str(FightModelOpponent.action_of(state, 0, _data)).is_equal("overhead")
	lancer.jump_frame = 3
	assert_str(FightModelOpponent.action_of(state, 0, _data)).is_equal("jump")


func test_an_action_held_over_frames_is_one_and_a_pause_makes_the_next_another() -> void:
	var learner := FightModelOpponent.new("medium", _data)
	var state: FightState = FightState.starting(_data, "lancer", "dancer")
	state.fighters[0].move = "jab"
	for frame: int in range(5):
		learner.watch(state, 1)
	state.fighters[0].move = ""
	learner.watch(state, 1)
	state.fighters[0].move = "jab"
	learner.watch(state, 1)
	assert_int(learner.guesses.size()).is_equal(2)


# Behind its seat it learns from what was on screen `reaction` frames ago:
# an action begun in front of it is not in its table until then.
func test_it_learns_only_from_the_late_fight_it_is_handed() -> void:
	var learner := FightModelOpponent.new("medium", _data)
	var seat := FightDelay.new(learner, 1)
	var state: FightState = FightState.starting(_data, "lancer", "dancer")
	var pressed_on: int = seat.reaction + 1
	for frame: int in range(seat.reaction + 2):
		seat.input_for(state)
		var press: int = FightInput.LIGHT_PUNCH if frame == pressed_on else 0
		state = FightRules.step(state, [press, 0] as Array[int], _data)
	assert_array(learner.guesses).is_empty()
	for frame: int in range(seat.reaction + 1):
		seat.input_for(state)
		state = FightRules.step(state, [0, 0] as Array[int], _data)
	assert_int(learner.guesses.size()).is_equal(1)


func test_a_sure_prediction_leans_towards_its_answers_and_chance_does_not() -> void:
	var learner := FightModelOpponent.new("hard", _data)
	var unsure: Array = learner._weighted_options("neutral", "lancer")
	assert_array(unsure).is_equal(FightOpponent.SITUATIONS["neutral"])
	for count: int in range(12):
		learner.model.observe("high")
	var sure: Array = learner._weighted_options("neutral", "lancer")
	assert_str(learner.expected).is_equal("high")
	for index: int in range(sure.size()):
		var gained: int = int(sure[index][1]) - int(unsure[index][1])
		if sure[index][0] in FightModelOpponent.ANSWERS["high"]:
			assert_int(gained).is_between(1, FightModelOpponent.LEAN)
		else:
			assert_int(gained).is_equal(0)


func test_every_action_has_answers_the_opponent_knows() -> void:
	var options: Array = FightOpponent.SITUATIONS["neutral"].map(func(option: Array) -> String: return option[0])
	for action: String in FightModelOpponent.ACTIONS:
		assert_array(FightModelOpponent.ANSWERS[action]).is_not_empty()
		for answer: String in FightModelOpponent.ANSWERS[action]:
			assert_array(options).contains([answer])


func test_the_training_mode_shows_the_table_it_is_learning() -> void:
	var scene: FightingExample = auto_free(load("res://game/fighting/fighting.tscn").instantiate())
	add_child(scene)
	scene.paused = true
	scene.dummy_mode = "learner: medium"
	for frame: int in range(150):
		var press: int = FightInput.LIGHT_PUNCH if frame % 35 == 0 else 0
		scene.state = FightRules.step(scene.state, [press, scene._dummy_input()] as Array[int], _data)
	var shown: Dictionary = scene.opponent_overlay()
	assert_str(shown["expects"]).is_not_empty()
	assert_str(str(shown["table"])).contains("high")
	assert_str(FightingPanel.describe(scene.state, _data, true, scene.seat)).contains("its model (order 2")
