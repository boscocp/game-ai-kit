# T99: the bandit opponent -- what it is paid, that it is paid only from the
# late fight it is handed, and ADR 0016's three conditions: it counts and
# keeps no mean, every fight starts it empty, and the recorded fight
# rebuilds the same counts twice.
extends GdUnitTestSuite

var _data: FightData

# English, whatever the machine speaks: these read the English the game
# writes (T80). The locale found is put back.
var _locale_before: String


func before() -> void:
	_locale_before = TranslationServer.get_locale()
	TranslationServer.set_locale("en")


func after() -> void:
	TranslationServer.set_locale(_locale_before)


func before_test() -> void:
	_data = FightData.read()


func test_the_payoff_is_the_change_of_lead_scaled_into_zero_to_one() -> void:
	assert_float(FightBanditOpponent.payoff(0, 0)).is_equal(0.5)
	assert_float(FightBanditOpponent.payoff(0, FightBanditOpponent.PAYOFF_RANGE)).is_equal(1.0)
	assert_float(FightBanditOpponent.payoff(50, 50 - FightBanditOpponent.PAYOFF_RANGE)).is_equal(0.0)
	assert_float(FightBanditOpponent.payoff(0, FightBanditOpponent.PAYOFF_RANGE / 2)).is_equal(0.75)
	assert_float(FightBanditOpponent.payoff(0, 5 * FightBanditOpponent.PAYOFF_RANGE)).is_equal(1.0)
	var state: FightState = FightState.starting(_data, "lancer", "lancer")
	state.fighters[1].health -= 40
	assert_int(FightBanditOpponent.lead(state, 0)).is_equal(40)
	assert_int(FightBanditOpponent.lead(state, 1)).is_equal(-40)


# The first decision is made on frame 0 and lands `reaction` frames later;
# it is paid only when the frame its window closes on is handed over, with
# the lead it gained in between -- here, a hit the other fighter took.
func test_an_option_is_paid_when_its_window_closes_on_the_frame_it_sees() -> void:
	var gambler := FightBanditOpponent.new("medium", _data)
	var state: FightState = FightState.starting(_data, "lancer", "lancer")
	gambler.choose(state, 1)
	var waiting: Dictionary = gambler._waiting[0]
	assert_int(waiting["lands"]).is_equal(gambler.reaction)
	var closes: int = waiting["closes"]
	var bandit: Bandit = gambler.current_bandit()
	for frame: int in range(1, closes):
		state.frame = frame
		if frame == waiting["lands"] + 1:
			state.fighters[0].health -= FightBanditOpponent.PAYOFF_RANGE / 2
		gambler.pay(state, 1)
	assert_int(bandit.total()).is_equal(0)
	state.frame = closes
	gambler.pay(state, 1)
	assert_int(bandit.total()).is_equal(1)
	assert_float(bandit.sums[gambler.chosen_arm]).is_equal(0.75)
	assert_float(gambler.last_paid["payoff"]).is_equal(0.75)


# Each situation has its own bandit, whose arms are the options its level
# knows there, in that order; and every one is tried once before any twice.
func test_a_bandit_a_situation_its_arms_the_levels_options() -> void:
	var gambler := FightBanditOpponent.new("hard", _data)
	var state: FightState = FightState.starting(_data, "lancer", "lancer")
	var tried: Array[String] = []
	for decision: int in range(FightOpponent.SITUATIONS["neutral"].size()):
		gambler._decide(state, 1)
		tried.append(gambler.options_of["neutral"][gambler.chosen_arm])
		gambler.current_bandit().reward(gambler.chosen_arm, 0.5)
	var expected: Array = FightOpponent.SITUATIONS["neutral"].map(func(option: Array) -> String: return option[0])
	assert_array(tried).is_equal(expected)
	assert_array(gambler.bandits.keys()).is_equal(["neutral"])


# ADR 0016's first condition, as its amendment words it: counts and sums,
# no mean kept. The bandit has no field a mean could be updated in.
func test_it_keeps_pulls_and_sums_and_no_mean() -> void:
	var fields: Array = Bandit.new(2).get_property_list().map(func(property: Dictionary) -> String: return property["name"])
	assert_array(fields).contains(["pulls", "sums"])
	assert_array(fields).not_contains(["means", "_means", "values", "_values"])


# The second: every fight starts with no bandit -- whether a seat sees the
# fight start again or the scene restarts.
func test_every_fight_starts_with_no_bandit() -> void:
	var gambler := FightBanditOpponent.new("medium", _data)
	var seat := FightDelay.new(gambler, 1)
	var state: FightState = FightState.starting(_data, "lancer", "dancer")
	for frame: int in range(240):
		seat.input_for(state)
		state = FightRules.step(state, [FightInput.LIGHT_PUNCH if frame % 30 == 0 else 0, 0] as Array[int], _data)
	assert_dict(gambler.bandits).is_not_empty()
	seat.input_for(FightState.starting(_data, "lancer", "dancer"))
	assert_dict(gambler.bandits).is_empty()
	assert_array(gambler._waiting).is_empty()
	var scene: FightingExample = auto_free(load("res://game/fighting/fighting.tscn").instantiate())
	add_child(scene)
	scene.dummy_mode = "bandit: medium"
	for frame: int in range(120):
		scene.step_decision_with(0)
	assert_dict(scene.opponent.bandits).is_not_empty()
	scene.restart()
	assert_dict(scene.opponent.bandits).is_empty()


# The third: the recorded fight, played twice through a bandit opponent
# seated from its first frame, rebuilds the same counts twice.
func test_the_recorded_fight_rebuilds_the_same_counts_twice() -> void:
	var input_log: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://test/fighting/fight_log.json"))
	var counts: Array[String] = []
	for run: int in range(2):
		var gambler := FightBanditOpponent.new("medium", _data)
		var seat := FightDelay.new(gambler, 1)
		var state: FightState = FightState.starting(_data, "lancer", "dancer")
		for pair: Array in input_log["inputs"]:
			seat.input_for(state)
			state = FightRules.step(state, [int(pair[0]), int(pair[1])] as Array[int], _data)
		counts.append(_counts_of(gambler))
	assert_str(counts[0]).contains("pulls")
	assert_str(counts[0]).is_equal(counts[1])


func test_the_panel_shows_the_bandit_that_chose() -> void:
	var scene: FightingExample = auto_free(load("res://game/fighting/fighting.tscn").instantiate())
	add_child(scene)
	scene.paused = true
	scene.dummy_mode = "bandit: medium"
	for frame: int in range(200):
		scene.step_decision_with(FightInput.LIGHT_PUNCH if frame % 35 == 0 else 0)
	var shown: Dictionary = scene.opponent_overlay()
	assert_array(shown["arms"]).is_not_empty()
	assert_int(shown["chosen_arm"]).is_between(0, (shown["arms"] as Array).size() - 1)
	var panel: String = FightingPanel.describe(scene.state, _data, true, scene.seat)
	assert_str(panel).contains("its bandit for")
	assert_str(panel).contains("> ")
	assert_str(panel).contains("bound")


func _counts_of(gambler: FightBanditOpponent) -> String:
	var lines: PackedStringArray = []
	for situation: String in gambler.bandits:
		var bandit: Bandit = gambler.bandits[situation]
		lines.append("%s %s pulls %s sums %s" % [situation, gambler.options_of[situation], bandit.pulls, bandit.sums])
	return "\n".join(lines)
