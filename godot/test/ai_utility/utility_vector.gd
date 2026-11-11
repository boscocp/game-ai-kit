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
const KINDS: Array[String] = ["action", "errands", "aim"]
## The types each kind reads, beside the keys every vector has, checked
## before anything reads them (T121): a cast that fails in a `-s` script is
## a SCRIPT ERROR the run survives. `expect` is left to `differences`, which
## compares any value without casting it.
const SHAPES: Dictionary = {
	"action": {
		"query": {
			"actions": [{
				"name": VectorShape.TEXT, "weight": VectorShape.NUMBER,
				"considerations": [{
					"percept": VectorShape.TEXT, "curve": VectorShape.TEXT, "slope?": VectorShape.NUMBER,
					"intercept?": VectorShape.NUMBER, "at?": VectorShape.NUMBER, "below?": VectorShape.NUMBER,
					"above?": VectorShape.NUMBER,
				}],
			}],
			"percepts": [{"*": VectorShape.NUMBER}],
		},
	},
	"aim": {
		"query": {
			"spread": VectorShape.NUMBER,
			"zones": [{
				"name": VectorShape.TEXT, "multiplier": VectorShape.NUMBER, "aim": [VectorShape.NUMBER],
				"rects": [[VectorShape.NUMBER]], "exposure": VectorShape.NUMBER,
			}],
			"rolls": [VectorShape.NUMBER],
		},
	},
	"errands": {
		"weights": {
			"resupply_walk": VectorShape.NUMBER, "leave_holding": VectorShape.NUMBER,
			"leave_attacking": VectorShape.NUMBER, "health_worth": VectorShape.NUMBER,
			"power_worth": VectorShape.NUMBER, "power_walk": VectorShape.NUMBER,
			"power_danger": VectorShape.NUMBER, "hide_second": VectorShape.NUMBER,
		},
		"query": {
			"resupply": [{
				"spent": VectorShape.NUMBER, "hurt": VectorShape.NUMBER, "exposure": VectorShape.NUMBER,
				"earned_power": VectorShape.FLAG, "walk_seconds": VectorShape.NUMBER,
				"attacking": VectorShape.FLAG, "empty": VectorShape.FLAG,
			}],
			"fetch": [{
				"available": VectorShape.FLAG, "walk_seconds": VectorShape.NUMBER,
				"enemies_near": VectorShape.NUMBER,
			}],
			"hide": [{
				"available": VectorShape.FLAG, "hurt": VectorShape.NUMBER, "exposure": VectorShape.NUMBER,
				"walk_seconds": VectorShape.NUMBER, "wait_seconds": VectorShape.NUMBER,
				"attacking": VectorShape.FLAG,
			}],
			"teams": [[VectorShape.NUMBER]], "pairs": [[VectorShape.NUMBER]],
		},
	},
}


## Why `vector` is not a utility vector, or "" when it is one.
static func why_not_a_vector(vector: Dictionary, file: String = "the file") -> String:
	for key: String in ["name", "why", "kind", "query", "expect"]:
		if not vector.has(key):
			return "it has no %s" % key
	if not (str(vector["kind"]) in KINDS):
		return "its kind %s is none of %s" % [vector["kind"], KINDS]
	var types: String = VectorShape.why_not(vector, SHAPES[str(vector["kind"])], file)
	if types != "":
		return types
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
	match str(vector["kind"]):
		"action":
			return _action(vector)
		"aim":
			return _aim(vector)
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


static func _aim(vector: Dictionary) -> Dictionary:
	var zones: Array[AimChoice.Zone] = []
	for fields: Dictionary in vector["query"]["zones"]:
		var zone := AimChoice.Zone.new()
		zone.name = str(fields["name"])
		zone.multiplier = float(fields["multiplier"])
		zone.aim = _vector2(fields["aim"])
		zone.exposure = float(fields["exposure"])
		for corners: Array in fields["rects"]:
			var low := Vector2(float(corners[0]), float(corners[1]))
			zone.rects.append(Rect2(low, Vector2(float(corners[2]), float(corners[3])) - low))
		zones.append(zone)
	var choice: AimChoice.Choice = AimChoice.choose(zones, float(vector["query"]["spread"]))
	var landed: Array = []
	for roll: Variant in vector["query"]["rolls"]:
		landed.append(AimChoice.land(choice.chances, float(roll)))
	return {"own_chances": Array(choice.own_chances), "expected": Array(choice.expected), "aimed": choice.aimed,
			"chances": Array(choice.chances), "landed": landed}


static func _vector2(pair: Array) -> Vector2:
	return Vector2(float(pair[0]), float(pair[1]))
