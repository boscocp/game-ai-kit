# The minions' director (T158): build-up sends a wave every `wave_every`
# seconds until every kind stands at its cap; a summoning phase brings one at
# once and the peak; the peak lasts until few stand, or `peak_seconds` at
# most; the relief is a pause of
# `relief_seconds`; and no wave comes while a heavy blow is underway. Then,
# over seeded fights, the director goes all the way round, and the planted
# directors -- one deaf to the heavy blow, one whose relief is no pause, one
# that sends waves in the peak -- are caught by the audit that holds the
# shipped one.
extends GdUnitTestSuite

const Audit: GDScript = preload("res://test/bossfight/fight_audit.gd")
const SEEDS: Array[int] = [1, 2, 3, 5, 8, 13, 21, 34]
const NUMBERS: Dictionary = {"wave_every": 8.0, "relief_at": 2, "peak_seconds": 15.0, "relief_seconds": 6.0}
const STEP: float = 0.1
const SUMMON: Array[Dictionary] = [{"what": "phase", "summon": true}]
const NO_SUMMON: Array[Dictionary] = [{"what": "phase", "summon": false}]


# Deaf to the boss: told every step that no heavy blow is underway.
class DeafToHeavy:
	extends BossDirector

	func step(now: float, entered: Array[Dictionary], standing: int, full: bool, _heavy: bool) -> bool:
		return super(now, entered, standing, full, false)


# A relief that is over at once.
class NoPause:
	extends BossDirector

	func _init(numbers: Dictionary) -> void:
		super(numbers)
		relief_seconds = 0.0


# Sends its waves in the peak, as in build-up.
class WavesInThePeak:
	extends BossDirector

	func step(now: float, entered: Array[Dictionary], standing: int, full: bool, heavy: bool) -> bool:
		var sent: bool = super(now, entered, standing, full, heavy)
		if not sent and state == PEAK and now - last_wave_at >= wave_every:
			return _wave(false)
		return sent


func test_the_director_s_numbers_are_checked_and_refused_by_name() -> void:
	var shipped: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BossFightRules.FILE))["director"]
	assert_str(BossDirector.why_not_numbers(shipped)).is_empty()
	var mistakes: Dictionary = {"wave_every": 0.0, "peak_seconds": -1.0, "relief_seconds": "soon", "relief_at": 1.5}
	for key: String in mistakes:
		var numbers: Dictionary = NUMBERS.duplicate()
		numbers[key] = mistakes[key]
		assert_str(BossDirector.why_not_numbers(numbers)).override_failure_message(key).contains(key)
	var unpaced: Dictionary = NUMBERS.duplicate()
	unpaced.erase("wave_every")
	assert_str(BossDirector.why_not_numbers(unpaced)).contains("wave_every")


func test_a_summon_late_in_a_peak_starts_its_seconds_over() -> void:
	var director := BossDirector.new(NUMBERS)
	director.step(1.0, [], 6, true, false)
	director.step(14.0, SUMMON, 6, true, false)
	assert_float(director.since).is_equal(14.0)
	director.step(16.5, [], 6, true, false)
	assert_str(director.state).is_equal(BossDirector.PEAK)


func test_a_heavy_blow_is_named_only_when_a_wave_is_due() -> void:
	var director := BossDirector.new(NUMBERS)
	director.step(2.0, [], 3, false, true)
	assert_str(director.waits_for()).is_equal(BossDirector.WAITS_FOR_TIME)
	director.step(8.5, [], 3, false, true)
	assert_str(director.waits_for()).is_equal(BossDirector.WAITS_FOR_HEAVY)


func test_build_up_sends_a_wave_every_few_seconds() -> void:
	var director := BossDirector.new(NUMBERS)
	var waves: Array[float] = _run(director, 0.0, 170, 3, false, false)
	assert_array(waves).has_size(2)
	assert_float(waves[0]).is_equal_approx(8.0, STEP)
	assert_float(waves[1]).is_equal_approx(16.0, STEP)
	assert_str(director.state).is_equal(BossDirector.BUILD_UP)


func test_a_full_group_is_the_peak_and_few_standing_the_relief() -> void:
	var director := BossDirector.new(NUMBERS)
	director.step(1.0, [], 6, true, false)
	assert_str(director.state).is_equal(BossDirector.PEAK)
	assert_array(_run(director, 1.0, 100, 3, true, false)).is_empty()
	assert_str(director.waits_for()).is_equal(BossDirector.WAITS_FOR_FEWER)
	director.step(11.1, [], 2, false, false)
	assert_str(director.state).is_equal(BossDirector.RELIEF)
	assert_str(director.waits_for()).is_equal(BossDirector.WAITS_FOR_RELIEF)


func test_a_peak_nobody_clears_still_fades_after_its_seconds() -> void:
	var director := BossDirector.new(NUMBERS)
	director.step(1.0, [], 6, true, false)
	assert_array(_run(director, 1.0, 139, 6, true, false)).is_empty()
	assert_str(director.state).is_equal(BossDirector.PEAK)
	director.step(16.0, [], 6, true, false)
	assert_str(director.state).is_equal(BossDirector.RELIEF)


func test_the_relief_is_a_pause_then_build_up() -> void:
	var director := BossDirector.new(NUMBERS)
	director.step(1.0, [], 6, true, false)
	director.step(2.0, [], 1, false, false)
	assert_str(director.state).is_equal(BossDirector.RELIEF)
	assert_array(_run(director, 2.0, 59, 1, false, false)).is_empty()
	assert_str(director.state).is_equal(BossDirector.RELIEF)
	assert_bool(director.step(8.0, [], 1, false, false)).is_true()
	assert_str(director.state).is_equal(BossDirector.BUILD_UP)


func test_a_summoning_phase_brings_a_wave_at_once_and_the_peak() -> void:
	var director := BossDirector.new(NUMBERS)
	assert_bool(director.step(1.0, NO_SUMMON, 5, false, false)).is_false()
	assert_bool(director.step(1.1, SUMMON, 5, false, false)).is_true()
	assert_str(director.state).is_equal(BossDirector.PEAK)
	assert_bool(director.events[-1]["summon"]).is_true()


func test_no_wave_comes_during_a_heavy_blow() -> void:
	var director := BossDirector.new(NUMBERS)
	assert_bool(director.step(1.0, SUMMON, 5, false, true)).is_false()
	assert_str(director.waits_for()).is_equal(BossDirector.WAITS_FOR_HEAVY)
	assert_float(director.next_wave_in()).is_equal(-1.0)
	assert_bool(director.step(1.1, [], 5, false, true)).is_false()
	assert_bool(director.step(1.2, [], 5, false, false)).is_true()
	var building := BossDirector.new(NUMBERS)
	assert_bool(building.step(8.5, [], 3, false, true)).is_false()
	assert_bool(building.step(8.6, [], 3, false, false)).is_true()


func test_the_shipped_director_goes_round_on_the_seeds() -> void:
	var seen: Dictionary = {"peak": 0, "relief": 0, "build-up again": 0, "summoned wave": 0, "timed wave": 0}
	for seed_value: int in SEEDS:
		var fight := BossFight.shipped(seed_value)
		var trace: Dictionary = Audit.new(seed_value).run(fight)
		assert_array(Audit.waves_out_of_turn(fight, trace)).override_failure_message("seed %d" % seed_value).is_empty()
		assert_array(Audit.short_reliefs(fight)).override_failure_message("seed %d" % seed_value).is_empty()
		_count(fight, seen)
	for what: String in seen:
		assert_int(seen[what]).override_failure_message("never seen: " + what).is_greater(0)


func test_a_director_deaf_to_the_heavy_blow_is_caught() -> void:
	assert_int(_caught_with(DeafToHeavy)).is_greater(0)


func test_a_relief_with_no_pause_is_caught() -> void:
	var caught: int = 0
	for seed_value: int in SEEDS:
		var fight := BossFight.shipped(seed_value)
		fight.director = NoPause.new(fight.rules.director)
		Audit.new(seed_value).run(fight)
		caught += Audit.short_reliefs(fight).size()
	assert_int(caught).is_greater(0)


func test_waves_in_the_peak_are_caught() -> void:
	assert_int(_caught_with(WavesInThePeak)).is_greater(0)


# Over the seeds, the waves out of turn of fights whose director is `planted`.
func _caught_with(planted: GDScript) -> int:
	var caught: int = 0
	for seed_value: int in SEEDS:
		var fight := BossFight.shipped(seed_value)
		fight.director = planted.new(fight.rules.director)
		var trace: Dictionary = Audit.new(seed_value).run(fight)
		caught += Audit.waves_out_of_turn(fight, trace).size()
	return caught


# Steps `director` `steps` times of STEP after `start`, the group as given;
# when a wave came.
func _run(director: BossDirector, start: float, steps: int, standing: int, full: bool, heavy: bool) -> Array[float]:
	var waves: Array[float] = []
	for count: int in range(1, steps + 1):
		if director.step(start + count * STEP, [], standing, full, heavy):
			waves.append(start + count * STEP)
	return waves


func _count(fight: BossFight, seen: Dictionary) -> void:
	var before: String = BossDirector.BUILD_UP
	for event: Dictionary in fight.director.events:
		if event["what"] == "wave":
			seen["summoned wave" if event["summon"] else "timed wave"] += 1
			continue
		if event["state"] == BossDirector.BUILD_UP and before == BossDirector.RELIEF:
			seen["build-up again"] += 1
		elif event["state"] != BossDirector.BUILD_UP:
			seen[event["state"]] += 1
		before = event["state"]
