## One conformance vector of `spec/vectors/perception/`, answered by
## ai_perception.
##
## A vector is a query and the answer it must get; this builds the addon's
## objects from the query, asks the technique, and compares every value
## with the file. The rules for what a vector is live here, so
## `perception_vector_test.gd` can hand this broken vectors and watch it
## object.
##
## When not to use it: anything but perception vectors.
class_name PerceptionVector
extends RefCounted

## Shared with `python/tests/test_perception_vectors.py`.
const TOLERANCE: float = 1e-9
const KINDS: Array[String] = ["shape", "loudness", "awareness", "phase", "belief", "particles"]
## The types each kind reads, beside the keys every vector has, checked
## before anything reads them (T121): a cast that fails in a `-s` script is
## a SCRIPT ERROR the run survives. `expect` is left to `differences`, which
## compares any value without casting it.
const SHAPES: Dictionary = {
	"shape": {
		"shape": {"zones": [{"name": VectorShape.TEXT, "near": VectorShape.NUMBER, "far": VectorShape.NUMBER,
				"half_angle": VectorShape.NUMBER, "certainty": VectorShape.NUMBER}],
				"dark_share": VectorShape.NUMBER, "motion_bonus": VectorShape.NUMBER},
		"query": {"looks": [{"distance": VectorShape.NUMBER, "angle": VectorShape.NUMBER,
				"points": [VectorShape.FLAG], "needed": VectorShape.NUMBER, "light": VectorShape.NUMBER,
				"moving": VectorShape.FLAG, "hidden": VectorShape.NUMBER}]},
	},
	"awareness": {
		"row": {"peak": VectorShape.NUMBER, "decay": VectorShape.NUMBER, "phases": [{"name": VectorShape.TEXT,
				"at": VectorShape.NUMBER, "decay?": VectorShape.NUMBER}],
				"caution": {"floor": VectorShape.NUMBER, "seconds": VectorShape.NUMBER}},
		"query": {"steps": [{"perceived": VectorShape.FLAG, "rate": VectorShape.NUMBER,
				"seconds": VectorShape.NUMBER, "now": VectorShape.NUMBER}]},
	},
	"belief": {
		"query": {"neighbours": [[VectorShape.NUMBER]], "steps": [{"collapse?": VectorShape.NUMBER,
				"seen?": [VectorShape.NUMBER], "spread?": VectorShape.NUMBER}]},
	},
	"loudness": {
		"query": {"heard": [[VectorShape.NUMBER]]},
	},
	"particles": {
		"query": {"neighbours": [[VectorShape.NUMBER]], "count": VectorShape.NUMBER, "seed": VectorShape.NUMBER,
				"knobs": {"walk_on": VectorShape.NUMBER, "turn": VectorShape.NUMBER,
				"unheard": VectorShape.NUMBER}, "steps": [{"collapse?": VectorShape.NUMBER,
				"seen?": [VectorShape.NUMBER], "unheard?": [VectorShape.NUMBER]}]},
	},
	"phase": {
		"row": {"peak": VectorShape.NUMBER, "decay": VectorShape.NUMBER, "phases": [{"name": VectorShape.TEXT,
				"at": VectorShape.NUMBER}], "caution": {"floor": VectorShape.NUMBER,
				"seconds": VectorShape.NUMBER}},
		"query": {"numbers": [VectorShape.NUMBER]},
	},
}


## Why `vector` is not a perception vector, or "" when it is one.
static func why_not_a_vector(vector: Dictionary) -> String:
	for key: String in ["name", "why", "kind", "query", "expect"]:
		if not vector.has(key):
			return "it has no %s" % key
	if not (str(vector["kind"]) in KINDS):
		return "its kind %s is none of %s" % [vector["kind"], KINDS]
	var types: String = VectorShape.why_not(vector, SHAPES[str(vector["kind"])])
	if types != "":
		return types
	if not (vector["expect"] is Dictionary) or (vector["expect"] as Dictionary).is_empty():
		return "it expects nothing"
	return ""


## Every way this side's answer differs from the file's, one line each.
static func check(label: String, vector: Dictionary) -> Array[String]:
	var found: Array[String] = []
	differences(vector["expect"], answer_to(vector), label, found)
	return found


## This side's answer to `vector`'s query.
static func answer_to(vector: Dictionary) -> Dictionary:
	match str(vector["kind"]):
		"shape":
			return _shape(vector)
		"loudness":
			return _loudness(vector)
		"awareness":
			return _awareness(vector)
		"phase":
			return _phase(vector)
		"particles":
			return _particles(vector)
	return _belief(vector)


## Append to `found` every place `answer` differs from `expected`; numbers
## within TOLERANCE, whatever their JSON type.
static func differences(expected: Variant, answer: Variant, where: String, found: Array[String]) -> void:
	if expected is Dictionary or expected is Array:
		_differences_in(expected, answer, where, found)
	elif expected is bool or answer is bool:
		if not (answer is bool) or answer != expected:
			found.append("%s: %s, the file says %s" % [where, answer, expected])
	elif not (answer is float or answer is int) or absf(float(answer) - float(expected)) > TOLERANCE:
		found.append("%s: %s, the file says %s" % [where, answer, expected])


static func _differences_in(expected: Variant, answer: Variant, where: String, found: Array[String]) -> void:
	if typeof(answer) != typeof(expected) or answer.size() != expected.size():
		found.append("%s: %s, the file says %s" % [where, answer, expected])
		return
	if expected is Dictionary:
		for key: Variant in expected:
			differences(expected[key], answer.get(key), "%s.%s" % [where, key], found)
		return
	for index: int in range((expected as Array).size()):
		differences(expected[index], answer[index], "%s[%d]" % [where, index], found)


static func _shape(vector: Dictionary) -> Dictionary:
	var shape: VisionShape = VisionShape.from_row(vector["shape"])
	var zones: Array = []
	var certainties: Array = []
	for look: Dictionary in vector["query"]["looks"]:
		var points: Array[bool] = []
		for point: bool in look["points"]:
			points.append(point)
		var seen: VisionPercept = shape.percept(float(look["distance"]), float(look["angle"]), points,
			int(look["needed"]), float(look["light"]), bool(look["moving"]), float(look["hidden"]))
		zones.append(seen.zone)
		certainties.append(seen.certainty)
	return {"zones": zones, "certainties": certainties}


static func _loudness(vector: Dictionary) -> Dictionary:
	var heard: Array = []
	for each: Array in vector["query"]["heard"]:
		heard.append(PathHearing.loudness(float(each[0]), float(each[1]), float(each[2])))
	return {"loudness": heard}


static func _awareness(vector: Dictionary) -> Dictionary:
	var number := Awareness.new()
	var values: Array = []
	var phases: Array = []
	for each: Dictionary in vector["query"]["steps"]:
		number.step(vector["row"], bool(each["perceived"]), float(each["rate"]), float(each["seconds"]), float(each["now"]))
		values.append(number.value)
		phases.append(Awareness.phase(number.value, vector["row"]))
	return {"values": values, "phases": phases}


static func _phase(vector: Dictionary) -> Dictionary:
	var phases: Array = []
	for each: float in vector["query"]["numbers"]:
		phases.append(Awareness.phase(each, vector["row"]))
	return {"phases": phases}


static func _belief(vector: Dictionary) -> Dictionary:
	var held := BeliefMap.new(_neighbours(vector["query"]["neighbours"]))
	var shares: Array = []
	var reseeded: Array = []
	for each: Dictionary in vector["query"]["steps"]:
		if each.has("collapse"):
			held.collapse(int(each["collapse"]))
		else:
			held.step_unseen(PackedInt32Array(each["seen"]), float(each["spread"]))
		shares.append(Array(held.shares))
		reseeded.append(held.reseeded)
	return {"shares": shares, "reseeded": reseeded}


static func _particles(vector: Dictionary) -> Dictionary:
	var query: Dictionary = vector["query"]
	var cloud := ParticleBelief.new(_neighbours(query["neighbours"]), int(query["count"]), int(query["seed"]))
	cloud.walk_on = float(query["knobs"]["walk_on"])
	cloud.turn = float(query["knobs"]["turn"])
	cloud.unheard = float(query["knobs"]["unheard"])
	var found: Dictionary = {"nodes": [], "weights": [], "shares": [], "emptied": [], "reseeded": []}
	for each: Dictionary in query["steps"]:
		if each.has("collapse"):
			cloud.collapse(int(each["collapse"]))
		else:
			cloud.step_unseen(PackedInt32Array(each["seen"]), PackedInt32Array(each["unheard"]))
		found["nodes"].append(Array(cloud.nodes))
		found["weights"].append(Array(cloud.weights))
		found["shares"].append(Array(cloud.shares))
		found["emptied"].append(Array(cloud.emptied))
		found["reseeded"].append(cloud.reseeded)
	return found


static func _neighbours(lists: Array) -> Array[PackedInt32Array]:
	var typed: Array[PackedInt32Array] = []
	for each: Array in lists:
		typed.append(PackedInt32Array(each))
	return typed
