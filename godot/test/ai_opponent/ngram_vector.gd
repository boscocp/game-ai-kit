## One n-gram vector: the predictor it describes, and what it claims the
## predictor says after so many actions.
##
## Apart from the runner, as every family here is: a runner is a `SceneTree`,
## hard to test, and a rule living there can be deleted with every gate
## green. `ngram_vector_test.gd` plants a case for each rule below.
##
## When not to use it: anything but `spec/vectors/ngram/`, whose README holds
## the shape.
class_name NGramVector
extends RefCounted

## The margin both languages allow: a different formula, never a different
## maths library.
const TOLERANCE: float = 1e-9
const VECTOR_KEYS: Array[String] = ["actions", "cases", "decay", "description", "order", "prior", "sequence"]
const CASE_KEYS: Array[String] = ["context", "likeliest", "probabilities", "seen"]
## The types this reads, checked before anything reads them (T121): the
## file's after its keys, each case's after its own.
const SHAPE: Dictionary = {
	"actions": [VectorShape.TEXT], "cases": [VectorShape.OBJECT], "decay": VectorShape.NUMBER,
	"order": VectorShape.NUMBER, "prior": VectorShape.NUMBER, "sequence": [VectorShape.TEXT],
}
const CASE_SHAPE: Dictionary = {
	"context": VectorShape.TEXT, "likeliest": VectorShape.TEXT, "probabilities": {"*": VectorShape.NUMBER},
	"seen": VectorShape.NUMBER,
}


## Why this dictionary is not a usable vector, or "" when it is one. A key
## nobody reads is refused: a misspelt claim would otherwise be dropped.
static func why_not_a_vector(vector: Dictionary, file: String = "the file") -> String:
	if _sorted_keys(vector) != VECTOR_KEYS:
		return "V1 its keys are %s, not %s" % [_sorted_keys(vector), VECTOR_KEYS]
	var types: String = VectorShape.why_not(vector, SHAPE, file)
	if types != "":
		return "V10 " + types
	if (vector["cases"] as Array).is_empty():
		return "V2 it claims nothing"
	if predictor_of(vector).problem() != "":
		return "V9 its settings cannot work: " + predictor_of(vector).problem()
	for action: Variant in vector["sequence"]:
		if not action in vector["actions"]:
			return "V8 its sequence holds %s, which is not one of its actions" % action
	var seen: Array = []
	for case: Dictionary in vector["cases"]:
		var wrong: String = _why_a_case_is_wrong(case, vector)
		if wrong == "" and case["seen"] in seen:
			wrong = "V7 two cases claim the same moment, after %s actions" % case["seen"]
		if wrong != "":
			return wrong
		seen.append(case["seen"])
	return ""


static func _why_a_case_is_wrong(case: Dictionary, vector: Dictionary) -> String:
	if _sorted_keys(case) != CASE_KEYS:
		return "V3 a case's keys are %s, not %s" % [_sorted_keys(case), CASE_KEYS]
	var types: String = VectorShape.why_not(case, CASE_SHAPE, "a case")
	if types != "":
		return "V10 " + types
	var named: Array = (case["probabilities"] as Dictionary).keys()
	named.sort()
	var actions: Array = (vector["actions"] as Array).duplicate()
	actions.sort()
	if named != actions:
		return "V4 a case's probabilities do not name every action"
	var total: float = 0.0
	for chance: float in (case["probabilities"] as Dictionary).values():
		total += chance
	if absf(total - 1.0) > TOLERANCE:
		return "V5 a case's probabilities do not sum to 1"
	var after: Variant = case["seen"]
	if not (after is float or after is int) or float(after) != floorf(float(after)):
		return "V6 a case's `seen` is not a whole number of actions"
	if int(after) < 0 or int(after) > (vector["sequence"] as Array).size():
		return "V6 a case is after more actions than the sequence has"
	return ""


## The predictor the vector describes, before it has seen anything.
static func predictor_of(vector: Dictionary) -> NGramPredictor:
	var actions: Array[String] = []
	actions.assign(vector["actions"])
	return NGramPredictor.new(int(vector["order"]), actions, float(vector["decay"]), float(vector["prior"]))


## Every claim in the vector that `predictor`, fed its sequence, does not meet.
static func wrong_claims(vector: Dictionary, predictor: NGramPredictor) -> Array[String]:
	var claims: Dictionary = {}
	for case: Dictionary in vector["cases"]:
		claims[int(case["seen"])] = case
	var sequence: Array = vector["sequence"]
	var wrong: Array[String] = []
	for seen: int in range(sequence.size() + 1):
		if claims.has(seen):
			wrong.append_array(_against(predictor, claims[seen]))
		if seen < sequence.size():
			predictor.observe(sequence[seen])
	return wrong


static func _against(predictor: NGramPredictor, case: Dictionary) -> Array[String]:
	var found: Dictionary = predictor.probabilities()
	var wrong: Array[String] = []
	var after: String = "after %d" % int(case["seen"])
	if predictor.context() != case["context"]:
		wrong.append("%s: context %s, not %s" % [after, predictor.context(), case["context"]])
	for action: String in case["probabilities"]:
		if absf(float(found[action]) - float(case["probabilities"][action])) > TOLERANCE:
			wrong.append("%s: %s %s, not %s" % [after, action, found[action], case["probabilities"][action]])
	if predictor.likeliest() != case["likeliest"]:
		wrong.append("%s: likeliest %s, not %s" % [after, predictor.likeliest(), case["likeliest"]])
	return wrong


static func _sorted_keys(table: Dictionary) -> Array:
	var keys: Array = table.keys()
	keys.sort()
	return keys
