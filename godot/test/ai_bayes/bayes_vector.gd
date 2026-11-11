## One Bayesian network vector: a network, and either the rule it must be
## refused by or the questions asked of it with their answers -- each
## query's distribution and what each piece of its evidence did.
##
## Apart from the runner, as every family here is: a runner is a `SceneTree`,
## hard to test, and a rule living there can be deleted with every gate
## green. `bayes_vector_test.gd` plants a case for each rule below.
##
## When not to use it: anything but `spec/vectors/bayes/`, whose README
## holds the shape.
class_name BayesVector
extends RefCounted

## The margin allowed on a chance. `derive.py` summed the full joint, in
## another order than enumeration sums, so the last bits may differ.
const TOLERANCE: float = 1e-12
const VECTOR_KEYS: Array[String] = ["description", "network", "problem", "queries"]
const QUERY_KEYS: Array[String] = ["distribution", "evidence", "influence", "query", "value"]
## The types this reads, checked before anything reads them (T121): the
## file's after its keys, each query's after its own.
const SHAPE: Dictionary = {
	"network": {"variables": [{
		"name": VectorShape.TEXT, "values": [VectorShape.TEXT], "parents": [VectorShape.TEXT],
		"table": [[VectorShape.NUMBER]],
	}]},
	"problem": VectorShape.TEXT,
	"queries": [VectorShape.OBJECT],
}
const QUERY_SHAPE: Dictionary = {
	"distribution": [VectorShape.NUMBER], "evidence": {"*": VectorShape.TEXT},
	"influence": {"*": VectorShape.NUMBER}, "query": VectorShape.TEXT, "value": VectorShape.TEXT,
}


## Why this dictionary is not a usable vector, or "" when it is one. A key
## nobody reads is refused: a misspelt claim would otherwise be dropped.
static func why_not_a_vector(vector: Dictionary, file: String = "the file") -> String:
	if _sorted_keys(vector) != VECTOR_KEYS:
		return "V1 its keys are %s, not %s" % [_sorted_keys(vector), VECTOR_KEYS]
	var types: String = VectorShape.why_not(vector, SHAPE, file)
	if types != "":
		return "V6 " + types
	if (str(vector["problem"]) != "") == not (vector["queries"] as Array).is_empty():
		return "V2 it must either name the rule a network is refused by, or ask it something -- one, not both"
	for asked: Dictionary in vector["queries"]:
		if _sorted_keys(asked) != QUERY_KEYS:
			return "V3 a query's keys are %s, not %s" % [_sorted_keys(asked), QUERY_KEYS]
		types = VectorShape.why_not(asked, QUERY_SHAPE, "a query")
		if types != "":
			return "V6 " + types
		var distribution: Array = asked["distribution"]
		if not distribution.is_empty() and absf(_sum(distribution) - 1.0) > 1e-9:
			return "V4 a distribution does not sum to 1"
		if not distribution.is_empty() and (asked["influence"] as Dictionary).keys() != (asked["evidence"] as Dictionary).keys():
			return "V5 an influence does not name exactly the evidence, in its order"
	return ""


## The network the vector describes.
static func network_of(vector: Dictionary) -> BayesNetwork:
	return BayesNetwork.new(vector["network"])


## Every claim in `vector` that `network` does not meet; empty when all hold.
static func wrong_claims(vector: Dictionary, network: BayesNetwork) -> Array[String]:
	var wrong: Array[String] = []
	var refused: String = str(vector["problem"])
	if refused != "":
		if not network.problem().begins_with(refused):
			wrong.append("refused with '%s', not %s" % [network.problem(), refused])
		return wrong
	if network.problem() != "":
		wrong.append("refused a sound network: %s" % network.problem())
		return wrong
	for index: int in range((vector["queries"] as Array).size()):
		wrong.append_array(_wrong_answer(index, vector["queries"][index], network))
	return wrong


# What query `index`, `asked`, gets wrong from `network`.
static func _wrong_answer(index: int, asked: Dictionary, network: BayesNetwork) -> Array[String]:
	var wrong: Array[String] = []
	var distribution: PackedFloat64Array = network.ask(asked["query"], asked["evidence"])
	if not _close(Array(distribution), asked["distribution"]):
		wrong.append("query %d: %s, not %s" % [index, distribution, asked["distribution"]])
	var moved: Dictionary = network.influence(asked["query"], asked["value"], asked["evidence"])
	var claimed: Dictionary = asked["influence"]
	if moved.keys() != claimed.keys() or not _close(moved.values(), claimed.values()):
		wrong.append("query %d: influence %s, not %s" % [index, moved, claimed])
	return wrong


static func _close(found: Array, claimed: Array) -> bool:
	if found.size() != claimed.size():
		return false
	for index: int in range(found.size()):
		if absf(float(found[index]) - float(claimed[index])) > TOLERANCE:
			return false
	return true


static func _sum(chances: Array) -> float:
	var total: float = 0.0
	for chance: Variant in chances:
		total += float(chance)
	return total


static func _sorted_keys(vector: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for key: Variant in vector.keys():
		keys.append(str(key))
	keys.sort()
	return keys
