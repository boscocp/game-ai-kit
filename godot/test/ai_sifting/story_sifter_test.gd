# StorySifter and SiftPattern: what the vectors do not say on their own.
#
# The sifter only reads (T166): a record handed to it is the same
# afterwards, and a planted sifter that marks the events it used is caught
# by the same check. Each of P1-P5 refuses a planted pattern.
extends GdUnitTestSuite

const RECORD: Array[Dictionary] = [
	{"day": 1, "kind": "deed", "verb": "burn", "place": "barn"},
	{"day": 2, "kind": "night", "place": "market", "fact": "bread", "value": false},
	{"day": 3, "kind": "deed", "verb": "repair", "place": "barn"},
	{"day": 4, "kind": "deed", "verb": "burn", "place": "mill"},
]
const REBUILT: Dictionary = {
	"name": "rebuilt",
	"find": [{"as": "burned", "where": {"verb": "burn", "place": "?place"}},
		{"as": "rebuilt", "where": {"verb": "repair", "place": "?place"}}],
	"before": [["burned", "rebuilt"]],
}


## Marks every event it matched as told: a sifter that writes.
class Marking extends StorySifter:
	func sift(events: Array, pattern: Dictionary) -> Array[Dictionary]:
		var found: Array[Dictionary] = super(events, pattern)
		for match: Dictionary in found:
			for index: Variant in (match["events"] as Dictionary).values():
				events[int(index)]["told"] = true
		return found


## Whether sifting changed the record it was handed.
func _writes_into_the_record(sifter: StorySifter) -> bool:
	var record: Array = RECORD.duplicate(true)
	sifter.sift(record, REBUILT)
	return record != RECORD.duplicate(true)


func test_a_match_names_its_events_and_bindings() -> void:
	var found: Array[Dictionary] = StorySifter.new().sift(RECORD, REBUILT)
	assert_int(found.size()).is_equal(1)
	assert_dict(found[0]["events"]).is_equal({"burned": 0, "rebuilt": 2})
	assert_dict(found[0]["bindings"]).is_equal({"place": "barn"})


func test_the_sifter_leaves_the_record_as_it_was() -> void:
	assert_bool(_writes_into_the_record(StorySifter.new())).is_false()


func test_a_sifter_that_marks_what_it_used_is_caught() -> void:
	assert_bool(_writes_into_the_record(Marking.new())).is_true()


func test_sifting_twice_gives_the_same_matches() -> void:
	var sifter := StorySifter.new()
	assert_array(sifter.sift(RECORD, REBUILT)).is_equal(sifter.sift(RECORD, REBUILT))


func test_each_rule_refuses_its_planted_pattern() -> void:
	var planted: Dictionary = {
		"P1": {"name": "x", "find": []},
		"P2": {"name": "x", "find": [{"as": "a", "where": {}}, {"as": "a", "where": {}}]},
		"P3": {"name": "x", "find": [{"as": "a", "where": {}}], "before": [["a", "a"]]},
		"P4": {"name": "x", "find": [{"as": "a", "where": {}}], "unless": [{"after": "a"}]},
		"P5": {"name": "x", "find": [{"as": "a", "where": {"day": null}}]},
	}
	for rule: String in planted:
		assert_str(SiftPattern.problem(planted[rule])).override_failure_message(rule).starts_with(rule)
		assert_array(StorySifter.new().sift(RECORD, planted[rule])).is_empty()
	assert_str(SiftPattern.problem(REBUILT)).is_empty()


func test_matching_does_not_change_the_bindings_it_is_given() -> void:
	var bound: Dictionary = {"place": "barn"}
	assert_that(StorySifter.bindings_if_matches(RECORD[3], {"place": "?place"}, bound)).is_null()
	assert_dict(StorySifter.bindings_if_matches(RECORD[3], {"verb": "?verb"}, bound)).is_equal(
		{"place": "barn", "verb": "burn"})
	assert_dict(bound).is_equal({"place": "barn"})


func test_a_flag_is_never_a_number() -> void:
	assert_bool(SiftPattern.same(true, 1)).is_false()
	assert_bool(SiftPattern.same(0, false)).is_false()
	assert_bool(SiftPattern.same(1, 1.0)).is_true()
	assert_bool(SiftPattern.same(null, null)).is_false()
