# The boss fight's three levels (T158), each played on seeded, headless,
# scripted runs: the pools the run saw are the level's, every telegraph the
# boss ran is at least the level's minimum (and the boss table's), no kind
# stands above the level's cap, and the director's waves keep their turn --
# with T157's promises still held at every level. Each is first shown a
# planted case it must reject: a level whose telegraph is below the
# minimum, an unknown level name, a level that gives the wrong pool, a
# wave bigger than the level's, and the file's other mistakes.
extends GdUnitTestSuite

const Audit: GDScript = preload("res://test/bossfight/fight_audit.gd")
const SEEDS: Array[int] = [1, 2, 3, 5, 8, 13, 21, 34]


# A fight whose pool is not its level's: one melee token more than the
# file says, as a fight that read the wrong level would have.
class OffThePools:
	extends BossFight

	func _init(seed_value: int, level: String) -> void:
		var difficulty: BossDifficulty = BossDifficulty.read()
		var rules: BossFightRules = difficulty.rules_for(level)
		var fields: Dictionary = difficulty.level(level).duplicate(true)
		fields["tokens"]["pools"]["melee"] += 1
		rules.apply(level, fields)
		super(rules, difficulty.table_for(level), seed_value)


# A fight whose waves fill each kind up to its cap, whatever the level's
# wave says.
class FillsToTheCap:
	extends BossFight

	func _init(seed_value: int) -> void:
		super(BossFightRules.read(), BossDifficulty.read().table_for(""), seed_value)

	func _missing(kind: String) -> int:
		return maxi(0, rules.wave_cap.get(kind, 0) - alive_of(kind))


func test_the_shipped_levels_are_sound() -> void:
	var difficulty: BossDifficulty = BossDifficulty.read()
	assert_str(difficulty.refusal).is_empty()
	assert_array(difficulty.names()).contains_exactly(["easy", "normal", "hard"])
	assert_array(difficulty.names()).contains_exactly(BossfightText.LEVEL_NAMES)
	assert_str(difficulty.default_level).is_equal("normal")
	assert_str(BossFight.shipped(1).rules.level).is_equal("normal")


func test_every_level_keeps_its_table_on_every_seed() -> void:
	var difficulty: BossDifficulty = BossDifficulty.read()
	var floor_seconds: float = BossTable.from_file().minimum_telegraph
	for level: String in difficulty.names():
		var fields: Dictionary = difficulty.level(level)
		var seen: Dictionary = {"pool full": 0, "at the cap": 0, "telegraphs": 0, "waves": 0}
		for seed_value: int in SEEDS:
			var fight := BossFight.shipped(seed_value, level)
			var trace: Dictionary = Audit.new(seed_value).run(fight)
			var said: String = "%s, seed %d: " % [level, seed_value]
			assert_array(Audit.off_the_pools(trace, fields)).override_failure_message(said + "pools").is_empty()
			assert_array(Audit.telegraphs_under(fight, float(fields["minimum_telegraph"]))).override_failure_message(said + "under the level's minimum").is_empty()
			assert_array(Audit.telegraphs_under(fight, floor_seconds)).override_failure_message(said + "under the table's minimum").is_empty()
			assert_array(Audit.above_the_cap(fight, trace)).override_failure_message(said + "above the cap").is_empty()
			assert_array(Audit.waves_too_big(fight)).override_failure_message(said + "a wave too big").is_empty()
			assert_array(Audit.over_the_pool(trace)).override_failure_message(said + "over the pool").is_empty()
			assert_array(Audit.fired_under_pressure(trace)).override_failure_message(said + "fired under pressure").is_empty()
			assert_array(Audit.left_waiting(trace)).override_failure_message(said + "left waiting").is_empty()
			assert_array(Audit.waves_out_of_turn(fight, trace)).override_failure_message(said + "a wave out of turn").is_empty()
			assert_array(Audit.short_reliefs(fight)).override_failure_message(said + "a relief cut short").is_empty()
			_count(fight, trace, fields, seen)
		# Not vacuous: at each level the melee pool filled, a kind reached its
		# cap, the boss telegraphed, and the director sent waves after the first.
		for what: String in seen:
			assert_int(seen[what]).override_failure_message("%s never saw: %s" % [level, what]).is_greater(0)


func test_a_wave_bigger_than_the_level_s_is_caught() -> void:
	var caught: int = 0
	for seed_value: int in SEEDS:
		var fight := FillsToTheCap.new(seed_value)
		Audit.new(seed_value).run(fight)
		caught += Audit.waves_too_big(fight).size()
	assert_int(caught).is_greater(0)


func test_hard_is_faster_than_normal_and_easy_slower() -> void:
	var difficulty: BossDifficulty = BossDifficulty.read()
	var tells: Dictionary = {}
	for level: String in difficulty.names():
		tells[level] = difficulty.table_for(level).telegraph_of("swipe", 0)
	assert_float(tells["hard"]).is_less(tells["normal"])
	assert_float(tells["easy"]).is_greater(tells["normal"])
	assert_float(tells["normal"]).is_equal_approx(BossTable.from_file().telegraph_of("swipe", 0), 0.0001)


func test_a_fight_off_its_level_s_pools_is_caught() -> void:
	var fight := OffThePools.new(1, "normal")
	var trace: Dictionary = Audit.new(1).run(fight)
	assert_array(Audit.off_the_pools(trace, BossDifficulty.read().level("normal"))).contains_exactly(["melee: [3]"])


func test_a_level_whose_minimum_is_under_the_table_s_is_refused() -> void:
	var data: Dictionary = _shipped()
	data["levels"][2]["minimum_telegraph"] = 0.3
	var difficulty := BossDifficulty.from_data(data, _table())
	assert_str(difficulty.refusal).contains("level hard").contains("0.30").contains("0.40")
	# The rule holds across the whole table: the other levels go with it.
	assert_str(difficulty.rules_for("easy").refusal).is_equal(difficulty.refusal)
	assert_str(difficulty.table_for("easy").refusal).is_not_empty()


func test_a_level_whose_tells_go_under_its_minimum_is_refused() -> void:
	var data: Dictionary = _shipped()
	data["levels"][2]["telegraph_scale"] = 0.7
	var refusal: String = BossDifficulty.from_data(data, _table()).refusal
	assert_str(refusal).contains("level hard").contains("swipe").contains("under the minimum")


func test_an_unknown_level_is_refused_by_name() -> void:
	var fight := BossFight.shipped(1, "nightmare")
	assert_str(fight.refusal()).contains("nightmare").contains("easy, normal, hard")
	fight.step(BossFightIntent.new())
	assert_float(fight.time).is_equal(0.0)
	assert_str(BossfightText.panel(fight, true)).contains("nightmare")
	assert_str(BossDifficulty.asked(PackedStringArray(["--open=x", "--difficulty=nightmare"]))).is_equal("nightmare")
	assert_str(BossDifficulty.asked(PackedStringArray())).is_empty()


func test_the_file_s_other_mistakes_are_refused_by_name() -> void:
	var capped: Dictionary = _shipped()
	capped["levels"][0]["wave_cap"]["melee"] = 1
	assert_str(BossDifficulty.from_data(capped, _table()).refusal).contains("level easy").contains("cap")
	var empty_pool: Dictionary = _shipped()
	empty_pool["levels"][1]["tokens"]["pools"]["ranged"] = 0
	assert_str(BossDifficulty.from_data(empty_pool, _table()).refusal).contains("level normal").contains("pool")
	var unnamed: Dictionary = _shipped()
	unnamed["default"] = "nightmare"
	assert_str(BossDifficulty.from_data(unnamed, _table()).refusal).contains("nightmare")
	var twice: Dictionary = _shipped()
	twice["levels"][2]["name"] = "easy"
	assert_str(BossDifficulty.from_data(twice, _table()).refusal).contains("easy")


func test_the_key_goes_round_the_levels() -> void:
	var difficulty: BossDifficulty = BossDifficulty.read()
	assert_str(difficulty.after("easy")).is_equal("normal")
	assert_str(difficulty.after("hard")).is_equal("easy")


func test_the_overlay_shows_the_level_s_numbers() -> void:
	var fight := BossFight.shipped(1, "hard")
	var shown: Dictionary = BossFightShown.overlay(fight)["difficulty"]
	assert_str(shown["level"]).is_equal("hard")
	assert_int(shown["melee"]["pool"]).is_equal(3)
	assert_int(shown["ranged"]["cap"]).is_equal(3)
	assert_float(shown["telegraph_scale"]).is_equal(0.8)
	assert_str(BossfightText.panel(fight, false)).contains("hard")


func _count(fight: BossFight, trace: Dictionary, fields: Dictionary, seen: Dictionary) -> void:
	for sample: Dictionary in trace["loads"]:
		if sample["load"] == int(fields["tokens"]["pools"]["melee"]):
			seen["pool full"] += 1
	for kind: String in BossDifficulty.KINDS:
		if trace["most_alive"].get(kind, 0) == int(fields["wave_cap"][kind]):
			seen["at the cap"] += 1
	seen["telegraphs"] += fight.boss.events.filter(func(event: Dictionary) -> bool: return event["what"] == "attack").size()
	seen["waves"] += fight.director.waves - 1


func _shipped() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(BossDifficulty.FILE))


func _table() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(BossTable.FILE))
