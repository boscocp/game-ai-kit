## One story sifting vector: a record of events, a pattern, and the matches
## it claims -- or the rule that refuses the pattern.
##
## Apart from the runner, as every family here is: a runner is a `SceneTree`,
## hard to test, and a rule living there can be deleted with every gate
## green. `sift_vector_test.gd` plants a case for each rule below.
##
## When not to use it: anything but `spec/vectors/sifting/`, whose README
## holds the shape.
class_name SiftVector
extends RefCounted

const VECTOR_KEYS: Array[String] = ["description", "events", "matches", "pattern", "refused"]
## The rules a refused vector may name.
const RULES: Array[String] = ["P1", "P2", "P3", "P4", "P5"]
## The types this reads, checked before anything reads them (T121).
const SHAPE: Dictionary = {
	"description": VectorShape.TEXT, "events": [VectorShape.OBJECT], "pattern": VectorShape.OBJECT,
	"refused": VectorShape.TEXT, "matches": [{"events": {"*": VectorShape.NUMBER}, "bindings": VectorShape.OBJECT}],
}


## Why this dictionary is not a usable vector, or "" when it is one. A key
## nobody reads is refused: a misspelt claim would otherwise be dropped.
static func why_not_a_vector(vector: Dictionary, file: String = "the file") -> String:
	if _sorted_keys(vector) != VECTOR_KEYS:
		return "V1 its keys are %s, not %s" % [_sorted_keys(vector), VECTOR_KEYS]
	var types: String = VectorShape.why_not(vector, SHAPE, file)
	if types != "":
		return "V8 " + types
	var refused: String = vector["refused"]
	if refused != "" and not refused in RULES:
		return "V2 it is refused by %s, which is no rule" % refused
	var matches: Array = vector["matches"]
	if refused != "" and not matches.is_empty():
		return "V3 a refused pattern claims a match"
	var names: Array = _names_to_find(vector["pattern"])
	for match: Dictionary in matches:
		var wrong: String = _match_problem(match, names, (vector["events"] as Array).size())
		if wrong != "":
			return wrong
	return ""


# Why a claimed match cannot be one of this pattern's over a record of
# `size` events, or "".
static func _match_problem(match: Dictionary, names: Array, size: int) -> String:
	if _sorted_keys(match["events"]) != names:
		return "V4 a match %s does not name every event to find" % match
	for index: Variant in (match["events"] as Dictionary).values():
		if int(index) < 0 or int(index) >= size:
			return "V5 a match %s names an event the record does not have" % match
	return ""


## Every claim in the vector that `sifter` does not meet.
static func wrong_claims(vector: Dictionary, sifter: StorySifter) -> Array[String]:
	var wrong: Array[String] = []
	var problem: String = SiftPattern.problem(vector["pattern"])
	if vector["refused"] != "" and not problem.begins_with(vector["refused"]):
		wrong.append("refused by %s, not %s" % [JSON.stringify(problem), vector["refused"]])
	if vector["refused"] != "":
		return wrong
	if problem != "":
		wrong.append("the pattern is refused: " + problem)
		return wrong
	var found: Array[Dictionary] = sifter.sift(vector["events"], vector["pattern"])
	var claimed: Array = vector["matches"]
	if found.size() != claimed.size():
		wrong.append("%d match(es), not %d: %s" % [found.size(), claimed.size(), found])
		return wrong
	for place: int in range(found.size()):
		var events_held: bool = same_table(found[place]["events"], claimed[place]["events"])
		if not (events_held and same_table(found[place]["bindings"], claimed[place]["bindings"])):
			wrong.append("match %d: %s, not %s" % [place, found[place], claimed[place]])
	return wrong


## Whether two tables have the same keys, each with the same value.
static func same_table(found: Dictionary, claimed: Dictionary) -> bool:
	if _sorted_keys(found) != _sorted_keys(claimed):
		return false
	for key: Variant in claimed:
		if not SiftPattern.same(found[key], claimed[key]):
			return false
	return true


# The names of the pattern's events to find, sorted; an empty list when it
# has none to read (a refused pattern may not).
static func _names_to_find(pattern: Dictionary) -> Array:
	var names: Array = []
	if not pattern.get("find") is Array:
		return names
	for clause: Variant in pattern["find"]:
		if clause is Dictionary and clause.has("as"):
			names.append(clause["as"])
	names.sort()
	return names


static func _sorted_keys(table: Dictionary) -> Array:
	var keys: Array = table.keys()
	keys.sort()
	return keys
