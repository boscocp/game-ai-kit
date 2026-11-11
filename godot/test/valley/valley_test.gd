# The valley's record, save, rules and standing (T164, ADR 0025).
#
# What ADR 0025 says a test holds, because N20's net cannot: the record is
# appended to and never edited (a deed appended, the first read back
# unchanged, the old text still the file's beginning); it carries its
# version (a record with another and one with none, both refused by
# name); and the world and the standing rebuild the same from it, twice,
# and a record cut at day n gives day n. And the schema's one refusal that
# matters most: a deed whose target is a person, planted, is refused by
# name and never reaches the disk. An append reads the file it appends to,
# and refuses -- writing nothing -- a day out of order with the file, a
# record in memory unlike it, and a file of another version, torn or empty.
#
# Every save here is the test's own, under user://tmp/, erased after each
# test; gdUnit4 clears user://tmp after the suite as well.
extends GdUnitTestSuite

const SCRATCH: String = "user://tmp/valley_test/deeds_under_test.json"
const LAST_DAY: int = 12

var _rules: ValleyRules
var _standing: Standing


func before_test() -> void:
	_rules = ValleyRules.new()
	_standing = Standing.new()


func after_test() -> void:
	ValleySave.new(SCRATCH).erase()


func test_a_person_as_a_target_is_refused_by_name() -> void:
	var record: DeedLog = _rules.new_record()
	var planted: Dictionary = {"verb": "burn", "target": "villager_3"}
	assert_str(record.append(planted)).contains("target")
	assert_str(record.append(DeedLog.make(1, "burn", "villager_3"))).contains("villager_3")
	assert_int(record.size()).is_equal(0)


func test_an_unknown_verb_is_refused_by_name() -> void:
	var record: DeedLog = _rules.new_record()
	assert_str(record.append(DeedLog.make(1, "kick", "barn"))).contains("kick")
	assert_str(record.append(DeedLog.make(1, "burn", "river"))).contains("river")
	assert_int(record.size()).is_equal(0)


func test_a_refused_deed_never_reaches_the_disk() -> void:
	var save := ValleySave.new(SCRATCH)
	var planted: Dictionary = {"day": 1, "verb": "burn", "place": "barn", "target": "villager_3"}
	assert_str(save.append(_rules.new_record(), planted)).contains("target")
	assert_bool(FileAccess.file_exists(SCRATCH)).is_false()


func test_the_record_is_appended_to_and_never_edited() -> void:
	var save := ValleySave.new(SCRATCH)
	var record: DeedLog = _rules.new_record()
	assert_str(save.append(record, DeedLog.make(1, "burn", "barn"))).is_empty()
	var before: String = FileAccess.get_file_as_string(SCRATCH)
	assert_str(save.append(record, DeedLog.make(2, "repair", "barn"))).is_empty()
	var after: String = FileAccess.get_file_as_string(SCRATCH)
	assert_bool(after.begins_with(before)).override_failure_message("the old record is not the new one's beginning").is_true()
	assert_bool(after.length() > before.length()).is_true()
	var read_back: DeedLog = _rules.new_record()
	assert_str(save.load_into(read_back)).is_empty()
	assert_int(read_back.size()).is_equal(2)
	assert_dict(read_back.deeds()[0]).is_equal(DeedLog.make(1, "burn", "barn"))
	assert_dict(read_back.deeds()[1]).is_equal(DeedLog.make(2, "repair", "barn"))


func test_the_first_line_is_the_header_and_each_other_one_deed() -> void:
	var save := ValleySave.new(SCRATCH)
	var record: DeedLog = _rules.new_record()
	save.append(record, DeedLog.make(1, "dig_well", "square"))
	var lines: PackedStringArray = FileAccess.get_file_as_string(SCRATCH).split("\n", false)
	assert_int(lines.size()).is_equal(2)
	assert_str(ValleySave.header_refusal(lines[0])).is_empty()
	assert_dict(JSON.parse_string(lines[1])).is_equal({"day": 1.0, "verb": "dig_well", "place": "square"})


func test_a_record_of_another_version_or_none_is_refused_by_name() -> void:
	var deed_line: String = JSON.stringify(DeedLog.make(1, "plant", "field"))
	_write_scratch(PackedStringArray([JSON.stringify({"version": 2}), deed_line]))
	assert_str(ValleySave.new(SCRATCH).load_into(_rules.new_record())).contains("version 2")
	_write_scratch(PackedStringArray([deed_line]))
	assert_str(ValleySave.new(SCRATCH).load_into(_rules.new_record())).contains("no version")
	_write_scratch(PackedStringArray([JSON.stringify({"version": 1}), deed_line]))
	assert_str(ValleySave.new(SCRATCH).load_into(_rules.new_record())).is_empty()


func test_erasing_starts_again_from_the_first_day() -> void:
	var save := ValleySave.new(SCRATCH)
	save.append(_rules.new_record(), DeedLog.make(1, "burn", "barn"))
	assert_int(save.erase()).is_equal(OK)
	assert_bool(FileAccess.file_exists(SCRATCH)).is_false()
	var record: DeedLog = _rules.new_record()
	assert_str(save.load_into(record)).is_empty()
	assert_int(record.size()).is_equal(0)


func test_rebuilding_twice_gives_the_same_world() -> void:
	for number: int in range(20):
		var record: DeedLog = _random_record(number)
		var once: ValleyWorld = _rules.rebuild(record, LAST_DAY)
		var twice: ValleyWorld = _rules.rebuild(record, LAST_DAY)
		assert_dict(twice.facts).override_failure_message("seed %d" % number).is_equal(once.facts)
		assert_dict(twice.because).override_failure_message("seed %d" % number).is_equal(once.because)
		assert_dict(_standing.of(record)).is_equal(_standing.of(record))


func test_a_record_cut_at_day_n_gives_day_n() -> void:
	for number: int in range(10):
		var record: DeedLog = _random_record(number)
		for day: int in range(LAST_DAY + 1):
			var cut: DeedLog = record.cut(day)
			var message: String = "seed %d, day %d" % [number, day]
			assert_dict(_rules.rebuild(cut, day).facts).override_failure_message(message).is_equal(_rules.rebuild(record, day).facts)
			assert_dict(_standing.of(cut)).override_failure_message(message).is_equal(_sum_by_hand(record, day))


func test_the_standing_names_the_deeds_that_sum_to_each_virtue() -> void:
	var record: DeedLog = _rules.new_record()
	for deed: Dictionary in [DeedLog.make(1, "burn", "barn"), DeedLog.make(2, "dig_well", "square"),
			DeedLog.make(3, "plant", "field")]:
		record.append(deed)
	var care: Array[Dictionary] = _standing.contributions(record, "care")
	var fear: Array[Dictionary] = _standing.contributions(record, "fear")
	assert_array(care.map(func(found: Dictionary) -> String: return found["deed"]["verb"])).is_equal(["burn", "dig_well", "plant"])
	assert_array(fear.map(func(found: Dictionary) -> String: return found["deed"]["verb"])).is_equal(["burn"])
	for virtue: String in ["care", "fear"]:
		var total: int = 0
		for found: Dictionary in _standing.contributions(record, virtue):
			assert_str(str(found["why"])).is_not_empty()
			total += int(found["weight"])
		assert_int(total).is_equal(int(_standing.of(record)[virtue]))


func test_the_world_says_why_a_fact_changed() -> void:
	var record: DeedLog = _rules.new_record()
	record.append(DeedLog.make(2, "burn", "barn"))
	var world: ValleyWorld = _rules.rebuild(record, 3)
	assert_bool(world.fact("market.bread")).is_false()
	assert_str(str(world.because["market.bread"])).contains("burnt barn")
	assert_str(str(world.because["barn.standing"])).contains("day 2, burn the barn")


func test_a_reason_is_kept_until_the_fact_changes() -> void:
	# The barn burns on day 1, and the bread fails on day 2 for it. On day 2
	# the river is diverted, the mill stops on day 3, and from the night
	# after, a second rule writes the bread false too: the fact does not
	# change, so its reason stays the barn's.
	var record: DeedLog = _rules.new_record()
	record.append(DeedLog.make(1, "burn", "barn"))
	record.append(DeedLog.make(2, "divert_water", "river"))
	var world: ValleyWorld = _rules.rebuild(record, 5)
	assert_bool(world.fact("mill.turning")).is_false()
	assert_str(str(world.because["market.bread"])).contains("burnt barn")


func test_a_deed_read_out_cannot_change_the_record() -> void:
	var record: DeedLog = _rules.new_record()
	record.append(DeedLog.make(1, "burn", "barn"))
	var copy: Array[Dictionary] = record.deeds()
	copy[0]["place"] = "mill"
	copy.clear()
	assert_int(record.size()).is_equal(1)
	assert_dict(record.deeds()[0]).is_equal(DeedLog.make(1, "burn", "barn"))


func test_an_append_before_a_load_cannot_put_a_day_out_of_order() -> void:
	ValleySave.new(SCRATCH).append(_rules.new_record(), DeedLog.make(5, "plant", "field"))
	var before: String = FileAccess.get_file_as_string(SCRATCH)
	var why: String = ValleySave.new(SCRATCH).append(_rules.new_record(), DeedLog.make(1, "burn", "barn"))
	assert_str(why).contains("day 1 comes after day 5")
	assert_str(FileAccess.get_file_as_string(SCRATCH)).is_equal(before)
	why = ValleySave.new(SCRATCH).append(_rules.new_record(), DeedLog.make(6, "burn", "barn"))
	assert_str(why).contains("load it before appending")
	assert_str(FileAccess.get_file_as_string(SCRATCH)).is_equal(before)


func test_an_append_to_a_file_this_game_refuses_writes_nothing() -> void:
	var deed_line: String = JSON.stringify(DeedLog.make(1, "plant", "field"))
	var unreadable: Dictionary = {
		"version 2": JSON.stringify({"version": 2}) + "\n",
		"torn": JSON.stringify({"version": 1}) + "\n" + deed_line.left(12),
		"empty": "",
	}
	for named: String in unreadable:
		_write_text(unreadable[named])
		var why: String = ValleySave.new(SCRATCH).append(_rules.new_record(), DeedLog.make(2, "burn", "barn"))
		assert_str(why).override_failure_message("%s: %s" % [named, why]).contains(named)
		assert_str(FileAccess.get_file_as_string(SCRATCH)).is_equal(unreadable[named])


func test_a_blank_line_in_the_file_is_refused() -> void:
	var deed_line: String = JSON.stringify(DeedLog.make(1, "plant", "field"))
	_write_scratch(PackedStringArray([JSON.stringify({"version": 1}), deed_line, "", deed_line]))
	assert_str(ValleySave.new(SCRATCH).load_into(_rules.new_record())).contains("line 3 is not a deed")


# A seeded record: up to two deeds a day, each a verb on a place it acts on.
func _random_record(number: int) -> DeedLog:
	var draw := RandomNumberGenerator.new()
	draw.seed = number
	var record: DeedLog = _rules.new_record()
	var verbs: Array = _rules.verbs.keys()
	verbs.sort()
	for day: int in range(1, LAST_DAY + 1):
		for _count: int in range(draw.randi_range(0, 2)):
			var verb: String = verbs[draw.randi_range(0, verbs.size() - 1)]
			var places: Array = (_rules.verbs[verb] as Dictionary).keys()
			assert_str(record.append(DeedLog.make(day, verb, places[draw.randi_range(0, places.size() - 1)]))).is_empty()
	return record


# Each virtue summed by hand over the deeds done by `day`, so the cut's
# standing is compared with something other than itself.
func _sum_by_hand(record: DeedLog, day: int) -> Dictionary:
	var sums: Dictionary = {"care": 0, "fear": 0}
	for deed: Dictionary in record.deeds():
		if int(deed["day"]) > day:
			continue
		for virtue: String in sums:
			sums[virtue] += _standing.weight(deed, virtue)
	return sums


func _write_scratch(lines: PackedStringArray) -> void:
	_write_text("\n".join(lines) + "\n")


func _write_text(text: String) -> void:
	DirAccess.make_dir_recursive_absolute(SCRATCH.get_base_dir())
	var file: FileAccess = FileAccess.open(SCRATCH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


# T121: the valley vectors runner refuses a file of the wrong types before
# it reads one. Deeds, worlds or lines given as text, in a copy of a real
# file, would be a SCRIPT ERROR that skipped the check.
func test_a_valley_vector_of_the_wrong_types_is_refused() -> void:
	var runner: GDScript = preload("res://test/valley/valley_vectors_runner.gd")
	var rebuilt: Dictionary = VectorShape.read_spec("vectors/valley/a-burnt-barn-leaves-the-market-without-bread-the-next-day.json")
	assert_str(VectorShape.why_not(rebuilt, runner.SHAPES["rebuilt"])).is_empty()
	var paths: Array = [["deeds"], ["deeds", 0, "day"], ["worlds"], ["worlds", 0], ["standing"]]
	for path: Array in paths:
		var why: String = VectorShape.why_not(VectorShape.planted(rebuilt, path, "x"), runner.SHAPES["rebuilt"])
		assert_str(why).override_failure_message(str(path)).is_not_empty()
	var refused: Dictionary = VectorShape.read_spec("vectors/valley/a-deed-out-of-order-is-refused.json")
	assert_str(VectorShape.why_not(refused, runner.SHAPES["refused"])).is_empty()
	var why_lines: String = VectorShape.why_not(VectorShape.planted(refused, ["lines"], "x"), runner.SHAPES["refused"])
	assert_str(why_lines).is_not_empty()
