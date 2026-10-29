## One conformance vector of `spec/vectors/utility/`, answered by ai_utility.
##
## A vector is a query and the answer it must get; this builds the addon's
## own objects from the query, asks the choice, and compares every value
## with the file. The rules for what a vector is live here, so
## `utility_test.gd` can hand this broken vectors and watch it object.
class_name UtilityVector
extends RefCounted

## Shared with `python/tests/test_utility_vectors.py`.
const TOLERANCE: float = 1e-4
const KINDS: Array[String] = ["action", "errands"]


## Why `vector` is not a utility vector, or "" when it is one.
static func why_not_a_vector(vector: Dictionary) -> String:
	for key: String in ["name", "why", "kind", "query", "expect"]:
		if not vector.has(key):
			return "it has no %s" % key
	if not (str(vector["kind"]) in KINDS):
		return "its kind %s is none of %s" % [vector["kind"], KINDS]
	if not (vector["expect"] is Dictionary) or (vector["expect"] as Dictionary).is_empty():
		return "it expects nothing"
	return ""


## Every way this side's answer differs from the file's, one line each.
static func check(label: String, vector: Dictionary) -> Array[String]:
	var answer: Dictionary = answer_to(vector)
	var found: Array[String] = []
	differences(vector["expect"], answer, label, found)
	return found


## This side's answer to `vector`'s query.
static func answer_to(vector: Dictionary) -> Dictionary:
	if str(vector["kind"]) == "action":
		return _action(vector)
	return _errands(vector)


## Append to `found` every place `answer` differs from `expected`. Numbers
## agree within TOLERANCE; a whole number in JSON is a float in GDScript, so
## numbers are compared as numbers whatever their type.
static func differences(expected: Variant, answer: Variant, where: String, found: Array[String]) -> void:
	if expected is Dictionary:
		var keys_differ: bool = not (answer is Dictionary) or (answer as Dictionary).keys().size() != (expected as Dictionary).keys().size()
		if keys_differ:
			found.append("%s: %s, the file says %s" % [where, answer, expected])
			return
		for key: Variant in expected:
			differences(expected[key], (answer as Dictionary).get(key), "%s.%s" % [where, key], found)
	elif expected is Array:
		if not (answer is Array) or (answer as Array).size() != (expected as Array).size():
			found.append("%s: %s, the file says %s" % [where, answer, expected])
			return
		for index: int in range((expected as Array).size()):
			differences(expected[index], answer[index], "%s[%d]" % [where, index], found)
	elif _is_number(expected) and _is_number(answer):
		if absf(float(answer) - float(expected)) > TOLERANCE:
			found.append("%s: %s, the file says %s" % [where, answer, expected])
	elif str(answer) != str(expected) or typeof(answer) == TYPE_NIL:
		found.append("%s: %s, the file says %s" % [where, answer, expected])


static func _is_number(value: Variant) -> bool:
	return (value is float or value is int) and not (value is bool)


static func _action(vector: Dictionary) -> Dictionary:
	var actions: Array[ActionChoice.Action] = ActionChoice.actions_from(vector["query"]["actions"])
	var scores: Array = []
	var answers: Array = []
	var chosen: Array = []
	for percepts: Dictionary in vector["query"]["percepts"]:
		var choice: ActionChoice.Choice = ActionChoice.choose(actions, percepts)
		scores.append(Array(choice.scores))
		answers.append(choice.answers.map(func(found: PackedFloat64Array) -> Array: return Array(found)))
		chosen.append(choice.chosen)
	return {"scores": scores, "answers": answers, "chosen": chosen}


static func _errands(vector: Dictionary) -> Dictionary:
	var weights := ErrandChoice.Weights.new()
	for key: String in vector["weights"]:
		weights.set(key, float(vector["weights"][key]))
	var query: Dictionary = vector["query"]
	var back: Array = []
	for fields: Dictionary in query["resupply"]:
		var facts := ErrandChoice.Resupply.new()
		for key: String in fields:
			facts.set(key, fields[key])
		back.append(Array(ErrandChoice.weigh_resupply(facts, weights)))
	var out: Array = []
	for fields: Dictionary in query["fetch"]:
		var facts := ErrandChoice.Fetch.new()
		for key: String in fields:
			facts.set(key, int(fields[key]) if key == "enemies_near" else fields[key])
		out.append(Array(ErrandChoice.weigh_fetch(facts, weights)))
	var hidden: Array = []
	for fields: Dictionary in query["hide"]:
		var facts := ErrandChoice.Hide.new()
		for key: String in fields:
			facts.set(key, fields[key])
		hidden.append(Array(ErrandChoice.weigh_hide(facts, weights)))
	var sent: Array = (query["teams"] as Array).map(func(scores: Array) -> int:
		return ErrandChoice.fetcher(PackedFloat64Array(scores)))
	# A pair is [back, fetch], or [back, fetch, hide].
	var chosen: Array = (query["pairs"] as Array).map(func(pair: Array) -> String:
		return ErrandChoice.choose(float(pair[0]), float(pair[1]), float(pair[2]) if pair.size() > 2 else 0.0))
	return {"resupply": back, "fetch": out, "hide": hidden, "fetcher": sent, "chosen": chosen}
