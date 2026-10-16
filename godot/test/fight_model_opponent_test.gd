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


# At chance it leans nothing; as sure as its decay lets it be, the whole of
# `LEAN` -- and only towards the answers.
func test_a_sure_prediction_leans_its_full_weight_towards_its_answers() -> void:
	var learner := FightModelOpponent.new("hard", _data)
	var unsure: Array = learner._weighted_options("neutral", "lancer")
	assert_array(unsure).is_equal(FightOpponent.SITUATIONS["neutral"])
	for count: int in range(20):
		learner.model.observe("high")
	var sure: Array = learner._weighted_options("neutral", "lancer")
	assert_str(learner.expected).is_equal("high")
	assert_bool(learner.answered).is_true()
	for index: int in range(sure.size()):
		var gained: int = int(sure[index][1]) - int(unsure[index][1])
		var answers: bool = sure[index][0] in FightModelOpponent.ANSWERS["high"]
		assert_int(gained).is_equal(FightModelOpponent.LEAN if answers else 0)
	# Enough to make each answer heavier than any option that is not one:
	# the likely draw, not merely a likelier one.
	var heaviest_other: int = 0
	for option: Array in sure:
		if not option[0] in FightModelOpponent.ANSWERS["high"]:
			heaviest_other = maxi(heaviest_other, int(option[1]))
	for option: Array in sure:
		if option[0] in FightModelOpponent.ANSWERS["high"]:
			assert_int(int(option[1])).is_greater(heaviest_other)


# Easy knows two options a situation; against a high it has no answer, and
# says so rather than seeming to lean.
func test_a_level_with_no_answer_says_so() -> void:
	var easy := FightModelOpponent.new("easy", _data)
	for count: int in range(20):
		easy.model.observe("high")
	assert_array(easy._weighted_options("neutral", "lancer")).is_equal(FightOpponent.SITUATIONS["neutral"].slice(0, 2))
	assert_bool(easy.answered).is_false()


# The answers are the ones the rules make true: a low is stopped crouching,
# an overhead and a mid standing, a throw by a strike, a guard by what goes
# round it.
func test_the_answers_are_what_the_rules_say_beats_each_action() -> void:
	assert_array(FightModelOpponent.ANSWERS["low"]).contains(["guard crouching"])
	assert_array(FightModelOpponent.ANSWERS["overhead"]).contains(["guard standing"])
	assert_array(FightModelOpponent.ANSWERS["throw"]).contains(["high"])
	assert_array(FightModelOpponent.ANSWERS["guard standing"]).contains(["low", "throw"])
	assert_array(FightModelOpponent.ANSWERS["guard crouching"]).contains(["overhead", "throw"])
	assert_array(FightModelOpponent.ANSWERS["low"]).not_contains(["guard standing"])
	assert_array(FightModelOpponent.ANSWERS["overhead"]).not_contains(["guard crouching"])


# ADR 0016's first condition: every fight starts with an empty table --
# whether the training mode seats a new learner or a seat sees the fight
# start again.
func test_every_fight_starts_with_an_empty_table() -> void:
	var learner := FightModelOpponent.new("medium", _data)
	var seat := FightDelay.new(learner, 1)
	var state: FightState = FightState.starting(_data, "lancer", "dancer")
	for frame: int in range(120):
		seat.input_for(state)
		state = FightRules.step(state, [FightInput.LIGHT_PUNCH if frame % 30 == 0 else 0, 0] as Array[int], _data)
	assert_array(Array(learner.model.rows())).is_not_empty()
	seat.input_for(FightState.starting(_data, "lancer", "dancer"))
	assert_array(Array(learner.model.rows())).is_empty()
	assert_array(learner.guesses).is_empty()
	var scene: FightingExample = auto_free(load("res://game/fighting/fighting.tscn").instantiate())
	add_child(scene)
	scene.dummy_mode = "learner: medium"
	scene.opponent.model.observe("high")
	scene.opponent.model.observe("low")
	scene.restart()
	assert_array(Array(scene.opponent.model.rows())).is_empty()


# ADR 0016's second: the table is what the fight showed, so the recorded
# log, played twice through a learner seated from its first frame, builds
# the same table twice.
func test_the_recorded_fight_builds_the_same_table_twice() -> void:
	var input_log: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://test/fight_log.json"))
	var tables: Array[String] = []
	for run: int in range(2):
		var learner := FightModelOpponent.new("medium", _data)
		var seat := FightDelay.new(learner, 1)
		var state: FightState = FightState.starting(_data, "lancer", "dancer")
		for pair: Array in input_log["inputs"]:
			seat.input_for(state)
			state = FightRules.step(state, [int(pair[0]), int(pair[1])] as Array[int], _data)
		tables.append("\n".join(learner.model.rows()))
	assert_str(tables[0]).is_not_empty()
	assert_str(tables[0]).is_equal(tables[1])


# An answer it knows in some situation: the long strike that answers a
# backdash is an option where backdashes happen -- "it blocked", "it evaded"
# -- and not in neutral (T40).
func test_every_action_has_answers_the_opponent_knows() -> void:
	var options: Array = []
	for situation: String in FightOpponent.SITUATIONS:
		options.append_array(FightOpponent.SITUATIONS[situation].map(func(option: Array) -> String: return option[0]))
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
