# Three sessions in the valley, played headless by a seeded, scripted
# player (T165's acceptance, ADR 0025).
#
# Each session opens the same save, plays a few whole days -- a deed most
# days, chosen by the dice among those offered -- and is dropped, as a
# closed game is. The test keeps its own copy of every deed it saw kept,
# and holds three things:
#
#   * the world of session 3 is the one that copy rebuilds, fact and
#     reason, and the one the file on disk rebuilds;
#   * nothing but the record is on disk: one file, a header and one
#     `{day, verb, place}` a line, no villager and no standing in it;
#   * erasing returns to day one, in the session and in the next.
#
# And it is not vacuous: deeds were kept in every session, session 3's
# world is not the first day's, and each session starts the day after
# the last deed. The save is the test's own, under user://tmp/.
extends GdUnitTestSuite

const FOLDER: String = "user://tmp/valley_three_sessions"
const SCRATCH: String = FOLDER + "/deeds.json"
const SESSIONS: int = 3
const DAYS_EACH: int = 3
const SEEDS: Array[int] = [1, 7, 42]

var _rules: ValleyRules


func before_test() -> void:
	_rules = ValleyRules.new()
	ValleySave.new(SCRATCH).erase()


func after_test() -> void:
	ValleySave.new(SCRATCH).erase()


func test_session_three_is_the_world_the_record_rebuilds() -> void:
	for seed_used: int in SEEDS:
		ValleySave.new(SCRATCH).erase()
		var seen: DeedLog = _play_sessions(seed_used, SESSIONS)
		var third := ValleyGame.new(ValleySave.new(SCRATCH))
		var from_copy: ValleyWorld = _rules.rebuild(seen, third.today)
		assert_dict(third.world.facts).is_equal(from_copy.facts)
		assert_dict(third.world.because).is_equal(from_copy.because)
		var from_disk: DeedLog = _rules.new_record()
		assert_str(ValleySave.read_text(FileAccess.get_file_as_string(SCRATCH), from_disk)).is_empty()
		assert_dict(_rules.rebuild(from_disk, third.today).facts).is_equal(from_copy.facts)
		assert_dict(third.standing_now()).is_equal(Standing.new().of(seen))
		var again := ValleyGame.new(ValleySave.new(SCRATCH))
		for index: int in range(third.villagers.size()):
			assert_dict(again.villagers[index].plans).is_equal(third.villagers[index].plans)
		assert_bool(third.world.facts == _rules.start).override_failure_message(
			"seed %d: three sessions of deeds left the valley as it began" % seed_used).is_false()


func test_each_session_starts_the_day_after_the_last_deed() -> void:
	var dice := GakXorshift.new(SEEDS[0])
	var seen: DeedLog = _rules.new_record()
	for session: int in range(SESSIONS):
		var game := ValleyGame.new(ValleySave.new(SCRATCH))
		var kept: Array[Dictionary] = seen.deeds()
		assert_int(game.today).is_equal(int(kept[-1]["day"]) + 1 if not kept.is_empty() else 1)
		var before: int = seen.size()
		_play_days(game, dice, seen)
		assert_int(seen.size()).override_failure_message(
			"session %d kept no deed" % (session + 1)).is_greater(before)


func test_nothing_but_the_record_is_on_disk() -> void:
	_play_sessions(SEEDS[1], SESSIONS)
	assert_array(Array(DirAccess.get_files_at(FOLDER))).contains_exactly(["deeds.json"])
	assert_array(Array(DirAccess.get_directories_at(FOLDER))).is_empty()
	var lines: PackedStringArray = FileAccess.get_file_as_string(SCRATCH).strip_edges().split("\n")
	assert_str(ValleySave.header_refusal(lines[0])).is_empty()
	assert_int(lines.size()).is_greater(SESSIONS)
	for index: int in range(1, lines.size()):
		var line: Dictionary = JSON.parse_string(lines[index])
		assert_array(line.keys()).contains_exactly_in_any_order(DeedLog.KEYS)
	var text: String = FileAccess.get_file_as_string(SCRATCH)
	for word: String in _words_never_saved():
		assert_str(text).override_failure_message("the save holds %s" % word).not_contains(word)


func test_erasing_returns_to_day_one() -> void:
	_play_sessions(SEEDS[2], SESSIONS)
	var game := ValleyGame.new(ValleySave.new(SCRATCH))
	assert_int(game.today).is_greater(1)
	assert_int(game.forget()).is_equal(OK)
	assert_bool(FileAccess.file_exists(SCRATCH)).is_false()
	assert_int(game.today).is_equal(1)
	assert_int(game.record.size()).is_equal(0)
	assert_dict(game.world.facts).is_equal(_rules.start)
	var next := ValleyGame.new(ValleySave.new(SCRATCH))
	assert_int(next.today).is_equal(1)
	assert_dict(next.world.facts).is_equal(_rules.start)
	assert_dict(next.standing_now()).is_equal({"care": 0, "fear": 0})


# `sessions` sessions on the scratch save with the dice from `seed_used`;
# the deeds the test saw kept, in order.
func _play_sessions(seed_used: int, sessions: int) -> DeedLog:
	var dice := GakXorshift.new(seed_used)
	var seen: DeedLog = _rules.new_record()
	for _session: int in range(sessions):
		_play_days(ValleyGame.new(ValleySave.new(SCRATCH)), dice, seen)
	return seen


# A few whole days of one session: most days a deed the dice choose among
# those offered, then every turn of the day and the night.
func _play_days(game: ValleyGame, dice: GakXorshift, seen: DeedLog) -> void:
	for _day: int in range(DAYS_EACH):
		var offered: Array[Dictionary] = game.offered()
		if not offered.is_empty() and dice.index(4) != 0:
			var chosen: Dictionary = offered[dice.index(offered.size())]
			assert_str(game.act(str(chosen["verb"]), str(chosen["place"]))).is_empty()
			assert_str(seen.append(chosen)).is_empty()
		for _turn: int in range(game.day_turns + 1):
			game.step_turn()


# What the record must never hold: a virtue, a villager's name, a plan's
# step, a fact derived from the deeds.
func _words_never_saved() -> Array[String]:
	var words: Array[String] = ["care", "fear", "standing", "has_", "reachable", "market.bread"]
	for villager: ValleyVillager in ValleyVillager.everyone():
		words.append(villager.name)
	for action: Dictionary in ValleyVillager.table()["actions"]:
		words.append(str(action["name"]))
	return words
