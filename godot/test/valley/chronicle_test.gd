# The valley's chronicle (T166): what happened, derived from the record;
# the moments its patterns tell; and that telling changes nothing.
#
#   * the events are each night's changed facts, then that day's deeds;
#   * a burnt barn tells the market out of bread, the barn rebuilt and the
#     bread back, each line naming the events its pattern matched;
#   * the bridge pulled down three times tells the third time, once;
#   * telling leaves the record, the save and the game's world as they
#     were -- and a planted chronicle that writes a deed is caught by the
#     same comparison;
#   * every pattern in chronicle.json is sound and has a sentence, and
#     every sentence a pattern.
extends GdUnitTestSuite

const SCRATCH: String = "user://tmp/chronicle_test/deeds.json"

var _rules: ValleyRules


## Appends a deed of its own whenever it is asked to tell: a chronicle
## that writes to the record.
class Writing extends ValleyChronicle:
	func tell(rules: ValleyRules, record: DeedLog, day: int) -> Array[Dictionary]:
		record.append(DeedLog.make(day, "dig_well", "square"))
		return super(rules, record, day)


func before_test() -> void:
	_rules = ValleyRules.new()
	ValleySave.new(SCRATCH).erase()


func after_test() -> void:
	ValleySave.new(SCRATCH).erase()


func test_the_events_are_the_nights_changes_then_the_days_deeds() -> void:
	var events: Array[Dictionary] = ValleyChronicle.events(_rules, _record([[1, "burn", "barn"]]), 2)
	assert_array(events).is_equal([
		{"day": 1, "kind": "deed", "verb": "burn", "place": "barn"},
		{"day": 2, "kind": "night", "place": "market", "fact": "bread", "value": false,
			"cause_day": 1, "cause_verb": "burn", "cause_place": "barn"},
	])


# Review 189, finding 3: the mill burnt on day 1 takes two nights to empty
# the market, and the well dug on day 2 between them is not the cause.
func test_a_line_names_the_deed_that_caused_it_not_the_last_one() -> void:
	var told: Array[Dictionary] = ValleyChronicle.new().tell(_rules,
		_record([[1, "burn", "mill"], [2, "dig_well", "square"]]), 4)
	var lost: Array = told.filter(func(line: Dictionary) -> bool: return line["pattern"] == "no-bread")
	assert_int(lost.size()).is_equal(1)
	assert_dict(lost[0]["values"]).contains_key_value("verb", "burn").contains_key_value("place", "mill")
	assert_str(ValleyPanel.chronicle_words(lost[0])).is_equal(
		"The market ran out of bread on day 3, because of a deed on day 1: burn the mill.")


# Review 189, finding 9: a repair answers the burning just before it.
func test_rebuilt_names_only_the_burning_the_repair_answered() -> void:
	var told: Array[Dictionary] = ValleyChronicle.new().tell(_rules,
		_record([[1, "burn", "barn"], [2, "burn", "barn"], [3, "repair", "barn"]]), 3)
	var rebuilt: Array = told.filter(func(line: Dictionary) -> bool: return line["pattern"] == "rebuilt")
	assert_int(rebuilt.size()).is_equal(1)
	assert_int(int(rebuilt[0]["values"]["burned.day"])).is_equal(2)


# Review 189, finding 6: every change a night can make has its words.
func test_every_change_a_night_makes_is_worded() -> void:
	for rule: Dictionary in _rules.rules:
		for fact: String in rule["then"]:
			var change: String = "%s %s" % [fact, "true" if rule["then"][fact] else "false"]
			assert_bool(ValleyPanel.NIGHT.has(change)).override_failure_message(change).is_true()
	var night: Dictionary = {"day": 2, "kind": "night", "place": "market", "fact": "bread", "value": false}
	assert_str(ValleyPanel.event_words(night)).is_equal("day 2, the market had no bread")


func test_a_burnt_and_rebuilt_barn_is_told_with_its_events() -> void:
	var told: Array[Dictionary] = ValleyChronicle.new().tell(_rules,
		_record([[1, "burn", "barn"], [3, "repair", "barn"]]), 5)
	assert_array(told.map(func(line: Dictionary) -> String: return line["pattern"])).is_equal(
		["no-bread", "rebuilt", "bread-again"])
	assert_dict(told[1]["values"]).is_equal({"place": "barn", "burned.day": 1, "rebuilt.day": 3})
	assert_array(told[1]["events"].map(func(event: Dictionary) -> String: return event["verb"])).is_equal(
		["burn", "repair"])
	assert_str(ValleyPanel.chronicle_words(told[1])).is_equal("On day 1 the barn burned, and on day 3 it was rebuilt.")


func test_the_third_time_is_told_once() -> void:
	var record: DeedLog = _record([[1, "pull_down", "bridge"], [2, "repair", "bridge"], [3, "pull_down", "bridge"],
		[4, "repair", "bridge"], [5, "pull_down", "bridge"], [6, "repair", "bridge"], [7, "pull_down", "bridge"]])
	var third: Array = ValleyChronicle.new().tell(_rules, record, 7).filter(
		func(line: Dictionary) -> bool: return line["pattern"] == "third-time")
	assert_int(third.size()).is_equal(2)
	assert_dict(third[0]["values"]).is_equal({"verb": "pull_down", "place": "bridge", "first.day": 1, "second.day": 3,
		"third.day": 5})
	assert_dict(third[1]["values"]).contains_key_value("verb", "repair")


func test_telling_changes_nothing_it_reads() -> void:
	var game := _played()
	assert_bool(_untouched(game, game.chronicle)).is_true()
	assert_array(game.chronicle_now()).is_not_empty()


func test_a_chronicle_that_writes_a_deed_is_caught() -> void:
	assert_bool(_untouched(_played(), Writing.new())).is_false()


func test_a_new_valley_has_nothing_to_tell() -> void:
	var game := ValleyGame.new(ValleySave.new(SCRATCH))
	var overlay: Dictionary = ValleyShown.overlay(game, 0)
	assert_array(overlay["chronicle"]).is_equal([ValleyShown.NONE])
	assert_str(ValleyPanel.chronicle(overlay)).contains("Nothing yet worth telling")


func test_every_pattern_is_sound_and_has_a_sentence() -> void:
	var names: Array[String] = []
	for pattern: Dictionary in ValleyChronicle.new().patterns:
		assert_str(SiftPattern.problem(pattern)).is_empty()
		names.append(pattern["name"])
	names.sort()
	var sentences: Array = ValleyPanel.CHRONICLE.keys()
	sentences.sort()
	assert_array(names).is_equal(sentences)


# A record of `deeds`, each [day, verb, place].
func _record(deeds: Array) -> DeedLog:
	var record: DeedLog = _rules.new_record()
	for deed: Array in deeds:
		assert_str(record.append(DeedLog.make(deed[0], deed[1], deed[2]))).is_empty()
	return record


# A game on the test's save with a few days played: the barn burnt, the
# bridge pulled down.
func _played() -> ValleyGame:
	var game := ValleyGame.new(ValleySave.new(SCRATCH))
	assert_str(game.act("burn", "barn")).is_empty()
	game.next_day()
	game.next_day()
	assert_str(game.act("pull_down", "bridge")).is_empty()
	game.next_day()
	return game


# Whether telling the chronicle `teller` left the game's record, its save
# and its world as they were.
func _untouched(game: ValleyGame, teller: ValleyChronicle) -> bool:
	var deeds: Array[Dictionary] = game.record.deeds()
	var saved: String = FileAccess.get_file_as_string(SCRATCH)
	var facts: Dictionary = game.world.facts.duplicate()
	teller.tell(game.rules, game.record, game.today)
	return game.record.deeds() == deeds and FileAccess.get_file_as_string(SCRATCH) == saved \
		and game.world.facts == facts
