# T37: the fixed opponent's knobs, and the rule that it is handed only the
# past. Every level sees the fight at least 15 frames late; the opponent is
# handed a frame exactly its reaction time old; a planted opponent that asks
# for the present is refused. Whether the levels are ordered is
# `opponent_levels.gd`'s, which plays the fights.
extends GdUnitTestSuite

var _data: FightData


## A planted opponent: it asks to see `asked` frames late, and writes down
## the frame of every fight it is handed.
class Recording extends FightOpponent:
	var handed: Array[int] = []

	func _init(asked: int, data: FightData) -> void:
		super("planted", data)
		reaction = asked

	func choose(seen: FightState, _me: int) -> int:
		handed.append(seen.frame)
		return 0


## A planted opponent that knocks out the fighter it is handed: if that were
## the fight itself and not a copy, the fight would be over.
class Meddling extends FightOpponent:
	func _init(data: FightData) -> void:
		super("planted", data)

	func choose(seen: FightState, _me: int) -> int:
		seen.fighters[0].health = 0
		return 0


func before_test() -> void:
	_data = FightData.read()


# --- the knobs ---------------------------------------------------------------

func test_every_level_sees_the_fight_at_least_15_frames_late() -> void:
	for level: String in FightOpponent.LEVELS:
		assert_int(FightOpponent.new(level, _data).reaction).is_greater_equal(FightDelay.MINIMUM_REACTION)
	assert_int(FightDelay.MINIMUM_REACTION).is_equal(15)


func test_the_knobs_get_better_from_easy_to_hard_and_never_worse() -> void:
	for pair: Array in [["easy", "medium"], ["medium", "hard"]]:
		var below: Dictionary = FightOpponent.LEVELS[pair[0]]
		var above: Dictionary = FightOpponent.LEVELS[pair[1]]
		assert_int(above["reaction"]).is_less_equal(below["reaction"])
		assert_int(above["tactics"]).is_greater_equal(below["tactics"])
		assert_int(above["execution"]).is_greater_equal(below["execution"])


func test_a_level_draws_only_the_options_its_tactics_allow() -> void:
	var easy := FightOpponent.new("easy", _data, 7)
	var tactics: int = int(FightOpponent.LEVELS["easy"]["tactics"])
	var neutral: FightState = FightState.starting(_data, "lancer", "dancer")
	var allowed: Array = FightOpponent.SITUATIONS["neutral"].slice(0, tactics).map(func(option: Array) -> String:
			return option[0])
	for decision: int in range(200):
		easy._decide(neutral, 1)
		var known: bool = allowed.any(func(option: String) -> bool: return easy.choice.begins_with(option))
		assert_bool(known).override_failure_message("easy drew %s, past its first %d" % [easy.choice, tactics]).is_true()
	assert_int(FightOpponent.SITUATIONS["neutral"].size()).is_greater(tactics)


func test_each_level_fumbles_as_often_as_its_execution_says() -> void:
	for level: String in FightOpponent.LEVELS:
		var expected: int = 1000 - 10 * int(FightOpponent.LEVELS[level]["execution"])
		var found: int = _fumbles(level)
		var message: String = "%s fumbled %d in 1000, expected about %d" % [level, found, expected]
		assert_int(found).override_failure_message(message).is_between(maxi(0, expected - 40), expected + 40)


# How many of 1000 decisions in a neutral fight a level fumbles.
func _fumbles(level: String) -> int:
	var neutral: FightState = FightState.starting(_data, "lancer", "dancer")
	var opponent := FightOpponent.new(level, _data, 3)
	var fumbled: int = 0
	for decision: int in range(1000):
		opponent._decide(neutral, 1)
		fumbled += 1 if "fumbled" in opponent.choice else 0
	return fumbled


func test_a_late_fumble_holds_nothing_before_what_was_chosen() -> void:
	var easy := FightOpponent.new("easy", _data, 5)
	var neutral: FightState = FightState.starting(_data, "lancer", "dancer")
	easy._decide(neutral, 1)
	while not "(fumbled: late)" in easy.choice:
		easy._decide(neutral, 1)
	var held: Array[int] = easy._plan.slice(0, FightOpponent.HESITATION_FRAMES)
	assert_bool(held.all(func(input: int) -> bool: return input == 0)).is_true()
	assert_int(easy._plan.size()).is_greater(FightOpponent.HESITATION_FRAMES)
	assert_bool(easy._plan.slice(FightOpponent.HESITATION_FRAMES).any(func(input: int) -> bool: return input != 0)) \
			.is_true()


func test_a_strike_out_of_reach_becomes_a_step_in() -> void:
	var hard := FightOpponent.new("hard", _data)
	var state: FightState = FightState.starting(_data, "lancer", "dancer")
	hard.choice = "mid"
	var far: Array[int] = hard._inputs_for("mid", state, 0)
	assert_str(hard.choice).contains("out of reach: steps in")
	assert_bool(far.all(func(input: int) -> bool: return input == FightInput.RIGHT)).is_true()
	state.fighters[1].x = state.fighters[0].x + 80
	hard.choice = "mid"
	var near: Array[int] = hard._inputs_for("mid", state, 0)
	assert_str(hard.choice).is_equal("mid -- low_jab")
	assert_int(near[0]).is_equal(FightInput.LIGHT_PUNCH | FightInput.DOWN)


# --- handed only the past ----------------------------------------------------

func test_the_opponent_is_handed_the_fight_exactly_its_reaction_time_old() -> void:
	for asked: int in [15, 22]:
		var recording := Recording.new(asked, _data)
		var seat := FightDelay.new(recording, 1)
		assert_str(seat.refusal).is_empty()
		var state: FightState = FightState.starting(_data, "lancer", "dancer")
		var presents: Array[int] = []
		for frame: int in range(60):
			presents.append(state.frame)
			seat.input_for(state)
			state = FightRules.step(state, [FightInput.RIGHT, 0] as Array[int], _data)
		assert_int(recording.handed.size()).is_equal(60 - asked)
		for index: int in range(recording.handed.size()):
			assert_int(recording.handed[index]).is_equal(presents[index + asked] - asked)


func test_an_opponent_asking_for_the_present_is_refused_and_handed_nothing() -> void:
	for asked: int in [0, 1, 14]:
		var recording := Recording.new(asked, _data)
		var seat := FightDelay.new(recording, 1)
		assert_str(seat.refusal).contains("at least 15 frames late")
		var state: FightState = FightState.starting(_data, "lancer", "dancer")
		for frame: int in range(40):
			assert_int(seat.input_for(state)).is_equal(0)
			state = FightRules.step(state, [0, 0] as Array[int], _data)
		assert_array(recording.handed).is_empty()


func test_a_caller_that_steps_one_state_in_place_still_hands_over_the_past() -> void:
	var recording := Recording.new(15, _data)
	var seat := FightDelay.new(recording, 1)
	var state: FightState = FightState.starting(_data, "lancer", "dancer")
	for frame: int in range(30):
		seat.input_for(state)
		state.frame += 1
	assert_array(recording.handed).is_equal(range(15) as Array[int])


func test_the_training_mode_seats_the_opponent_and_shows_what_it_saw() -> void:
	var scene: FightingExample = auto_free(load("res://game/fighting/fighting.tscn").instantiate())
	add_child(scene)
	scene.paused = true
	var first: FightOpponent = scene.opponent
	for frame: int in range(40):
		scene.step_decision()
	var seen: Dictionary = scene.decision_overlay()["opponent"]
	assert_int(seen["seen_frame"]).is_between(0, scene.state.frame - 1 - scene.seat.reaction)
	assert_str(seen["situation"]).is_not_equal("nothing seen yet")
	scene.restart()
	assert_object(scene.opponent).is_not_same(first)
	assert_int(scene.decision_overlay()["opponent"]["seen_frame"]).is_equal(-1)


func test_shortening_the_reaction_after_being_seated_changes_nothing() -> void:
	var recording := Recording.new(15, _data)
	var seat := FightDelay.new(recording, 1)
	recording.reaction = 0
	var state: FightState = FightState.starting(_data, "lancer", "dancer")
	for frame: int in range(20):
		seat.input_for(state)
		state = FightRules.step(state, [0, 0] as Array[int], _data)
	assert_array(recording.handed).is_equal([0, 1, 2, 3, 4])


func test_what_the_opponent_is_handed_is_a_copy_it_cannot_change_the_fight_through() -> void:
	var seat := FightDelay.new(Meddling.new(_data), 1)
	var state: FightState = FightState.starting(_data, "lancer", "dancer")
	var played: Array[FightState] = []
	for frame: int in range(30):
		played.append(state)
		seat.input_for(state)
		state = FightRules.step(state, [0, 0] as Array[int], _data)
	assert_bool(played.all(func(seen: FightState) -> bool: return seen.fighters[0].health > 0)).is_true()


func test_a_restarted_fight_starts_its_memory_again() -> void:
	var recording := Recording.new(15, _data)
	var seat := FightDelay.new(recording, 1)
	var state: FightState = FightState.starting(_data, "lancer", "dancer")
	for frame: int in range(20):
		seat.input_for(state)
		state = FightRules.step(state, [0, 0] as Array[int], _data)
	recording.handed.clear()
	state = FightState.starting(_data, "lancer", "dancer")
	for frame: int in range(15):
		seat.input_for(state)
		state = FightRules.step(state, [0, 0] as Array[int], _data)
	assert_array(recording.handed).is_empty()


# --- what it sees and what it does -------------------------------------------

func test_the_situations_are_read_off_the_fight_it_was_handed() -> void:
	var state: FightState = FightState.starting(_data, "lancer", "dancer")
	assert_str(FightOpponent.situation_of(state, 1, _data)).is_equal("neutral")
	state.fighters[0].crouching = true
	assert_str(FightOpponent.situation_of(state, 1, _data)).is_equal("it crouches")
	state.fighters[0].crouching = false
	state.fighters[0].move = "thrust"
	state.fighters[0].move_frame = 20
	assert_str(FightOpponent.situation_of(state, 1, _data)).is_equal("it whiffed")
	state.fighters[0].connected = true
	assert_str(FightOpponent.situation_of(state, 1, _data)).is_equal("neutral")
	state.fighters[1].stun_kind = "block"
	assert_str(FightOpponent.situation_of(state, 1, _data)).is_equal("after blocking")
	state.fighters[1].stun_kind = "hit"
	assert_str(FightOpponent.situation_of(state, 1, _data)).is_equal("after being hit")


func test_a_strike_is_the_quickest_move_at_its_height_and_the_dancer_has_no_overhead() -> void:
	assert_str(FightOpponent.strike_for(_data, "lancer", "low")).is_equal("low_kick")
	assert_str(FightOpponent.strike_for(_data, "lancer", "high")).is_equal("jab")
	assert_str(FightOpponent.strike_for(_data, "lancer", "overhead")).is_equal("axe_kick")
	assert_str(FightOpponent.strike_for(_data, "dancer", "overhead")).is_empty()


func test_a_crouching_strike_holds_down_from_the_press_to_the_end() -> void:
	var hard := FightOpponent.new("hard", _data)
	var inputs: Array[int] = hard._pressed("low_kick", "lancer")
	assert_int(inputs.size()).is_equal(_data.length_of("lancer", "low_kick"))
	assert_int(inputs[0]).is_equal(FightInput.LIGHT_KICK | FightInput.DOWN)
	assert_bool(inputs.slice(1).all(func(input: int) -> bool: return input == FightInput.DOWN)).is_true()


func test_the_same_seed_plays_the_same_fight() -> void:
	var runs: Array[String] = []
	for run: int in range(2):
		var easy := FightDelay.new(FightOpponent.new("easy", _data, 11), 0)
		var hard := FightDelay.new(FightOpponent.new("hard", _data, 12), 1)
		var state: FightState = FightState.starting(_data, "lancer", "dancer")
		for frame: int in range(600):
			state = FightRules.step(state, [easy.input_for(state), hard.input_for(state)] as Array[int], _data)
		runs.append(state.digest())
	assert_str(runs[0]).is_equal(runs[1])


# Every situation the fixed opponent can name, every stand-in has something
# to do in: T40 added two, and a stand-in without them stopped dead on the
# first evade it saw.
func test_every_stand_in_has_options_in_every_situation() -> void:
	for habit: String in StandInPlayer.HABITS:
		var stand_in := StandInPlayer.new(habit, _data)
		for situation: String in FightOpponent.SITUATIONS:
			var lancer: Array = stand_in._weighted_options(situation, "lancer")
			var dancer: Array = stand_in._weighted_options(situation, "dancer")
			assert_array(lancer).override_failure_message("%s in %s as the lancer" % [habit, situation]).is_not_empty()
			assert_array(dancer).override_failure_message("%s in %s as the dancer" % [habit, situation]).is_not_empty()
