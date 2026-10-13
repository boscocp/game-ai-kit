## One fuzzy vector: the controller it describes, and the numbers it claims.
##
## Apart from the runner for the reason every family here learned: a runner is
## a `SceneTree`, hard to test, and a rule living there can be deleted with
## every gate green. `fuzzy_vector_test.gd` plants a case for each rule below.
##
## When not to use it: anything but `spec/vectors/fuzzy/`, whose README holds
## the shape.
class_name FuzzyVector
extends RefCounted

## The margin both languages allow, scaled by the size of the answer: it
## catches a different formula, never a different maths library.
const TOLERANCE: float = 1e-9

const KINDS: Array[String] = ["membership", "fuzzify", "evaluate"]


## Why this dictionary is not a usable vector, or "" when it is one.
static func why_not_a_vector(data: Dictionary) -> String:
	if not (data.get("cases") is Array) or (data["cases"] as Array).is_empty():
		return "V1 the vector claims nothing: `cases` is missing or empty"
	var controller: FuzzyRuleBase = controller_of(data)
	if controller == null:
		return "V3 the controller is not inputs, outputs and rules of the documented shape"
	if controller.problem() != "":
		return controller.problem()
	var earlier: Array[String] = []
	for index: int in range((data["cases"] as Array).size()):
		var wrong: String = _why_a_case_is_wrong(controller, data["cases"][index], earlier)
		if wrong != "":
			return "case %d: %s" % [index, wrong]
	return ""


## The controller this vector describes, or null when its shape is wrong.
##
## A controller of the right shape can still be unusable -- a rule naming a set
## nobody declared -- and that is `FuzzyRuleBase.problem`'s to say, not this.
static func controller_of(data: Dictionary) -> FuzzyRuleBase:
	var described: Variant = data.get("controller")
	if not (described is Dictionary):
		return null
	var inputs: Array[FuzzyVariable] = _variables(described.get("inputs"), false)
	var outputs: Array[FuzzyVariable] = _variables(described.get("outputs"), true)
	var rules: Array[FuzzyRule] = _rules(described.get("rules"))
	if inputs.is_empty() or outputs.is_empty() or rules.size() != _count(described.get("rules")):
		return null
	return FuzzyRuleBase.new(inputs, outputs, rules)


## Everything this vector claims, checked against the addon.
static func check(name: String, data: Dictionary) -> Array[String]:
	var controller: FuzzyRuleBase = controller_of(data)
	var failures: Array[String] = []
	var answers: Dictionary = {}
	for case: Dictionary in data["cases"]:
		var label: String = "%s: %s" % [name, case.get("name", case.get("why", "?"))]
		if case["kind"] == "evaluate":
			failures += _check_evaluation(label, controller, case, answers)
		else:
			failures += _check_degrees(label, controller, case)
	return failures


## Two numbers the same to the last places of a double; NAN expected is `null`.
static func close_enough(found: float, expected: Variant) -> bool:
	if expected == null:
		return is_nan(found)
	return absf(found - float(expected)) <= TOLERANCE * maxf(1.0, absf(float(expected)))


static func _check_degrees(label: String, controller: FuzzyRuleBase,
		case: Dictionary) -> Array[String]:
	var variable: FuzzyVariable = _input_named(controller, case["variable"])
	if case["kind"] == "membership":
		var found: float = variable.set_named(case["set"]).degree(float(case["value"]))
		if not close_enough(found, case["degree"]):
			return ["%s: degree %s, the vector says %s" % [label, found, case["degree"]]]
		return []
	return _compare_terms(label, variable.fuzzify(float(case["value"])), case["degrees"])


static func _check_evaluation(label: String, controller: FuzzyRuleBase,
		case: Dictionary, answers: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	var strengths: Dictionary = controller.activations(case["inputs"])
	for output: String in case["activations"]:
		var expected: Dictionary = case["activations"][output]
		failures += _compare_terms(label + " " + output, strengths.get(output, {}), expected)
	var found: Dictionary = controller.evaluate(case["inputs"])
	answers[case["name"]] = found
	for output: String in case["outputs"]:
		var claimed: Variant = case["outputs"][output]
		if not close_enough(found[output], claimed):
			failures.append("%s: %s is %s, the vector says %s" % [label, output, found[output], claimed])
		failures += _check_between(label, output, found, case, answers)
	return failures


# The claim T13 asks for: an answer strictly between two others. Both of the
# others are earlier cases, so their answers are already in `answers`.
static func _check_between(label: String, output: String, found: Dictionary,
		case: Dictionary, answers: Dictionary) -> Array[String]:
	if not case.has("between"):
		return []
	var low: float = answers[case["between"][0]][output]
	var high: float = answers[case["between"][1]][output]
	if low > high:
		var swap: float = low
		low = high
		high = swap
	if low < found[output] and found[output] < high:
		return []
	return ["%s: %s is %s, not strictly between %s and %s" % [
		label, output, found[output], low, high]]


static func _compare_terms(label: String, found: Dictionary, expected: Dictionary) -> Array[String]:
	if found.keys().size() != expected.keys().size():
		return ["%s: terms %s, the vector says %s" % [label, found.keys(), expected.keys()]]
	var failures: Array[String] = []
	for term: String in expected:
		if not found.has(term) or not close_enough(found[term], expected[term]):
			var message: String = "%s: %s is %s, the vector says %s"
			failures.append(message % [label, term, found.get(term), expected[term]])
	return failures


static func _why_a_case_is_wrong(controller: FuzzyRuleBase, case: Variant,
		earlier: Array[String]) -> String:
	if not (case is Dictionary) or not (case.get("kind") in KINDS):
		return "V2 a case is an object whose kind is one of %s" % [KINDS]
	if case["kind"] == "evaluate":
		return _why_an_evaluation_is_wrong(controller, case, earlier)
	var variable: FuzzyVariable = _input_named(controller, str(case.get("variable", "")))
	if variable == null or not (case.get("value") is float):
		return "V4 a %s case names an input and a value" % case["kind"]
	if case["kind"] == "fuzzify":
		return "" if case.get("degrees") is Dictionary else "V4 a fuzzify case claims `degrees`"
	if variable.set_named(str(case.get("set", ""))) == null or not (case.get("degree") is float):
		return "V4 a membership case names one of the input's sets and claims a `degree`"
	return ""


static func _why_an_evaluation_is_wrong(controller: FuzzyRuleBase, case: Dictionary,
		earlier: Array[String]) -> String:
	for field: String in ["inputs", "activations", "outputs"]:
		if not (case.get(field) is Dictionary):
			return "V5 an evaluate case carries `%s`" % field
	if not (case.get("name") is String) or case["name"] in earlier:
		return "V5 an evaluate case has a `name` no earlier case used"
	if controller.fuzzify(case["inputs"]).is_empty():
		return "V5 an evaluate case gives every input a value"
	for output: FuzzyVariable in controller.outputs:
		if not case["outputs"].has(output.name) or not case["activations"].has(output.name):
			return "V5 an evaluate case claims every output, %s included" % output.name
	if case.has("between"):
		var named: Variant = case["between"]
		if not (named is Array) or named.size() != 2 or not (named[0] in earlier and named[1] in earlier):
			return "V6 `between` names two earlier evaluate cases"
	earlier.append(case["name"])
	return ""


static func _input_named(controller: FuzzyRuleBase, variable_name: String) -> FuzzyVariable:
	for variable: FuzzyVariable in controller.inputs:
		if variable.name == variable_name:
			return variable
	return null


static func _count(entries: Variant) -> int:
	return (entries as Array).size() if entries is Array else -1


static func _variables(entries: Variant, is_output: bool) -> Array[FuzzyVariable]:
	var found: Array[FuzzyVariable] = []
	if not (entries is Array):
		return found
	for entry: Variant in entries:
		var variable: FuzzyVariable = _variable(entry, is_output)
		if variable == null:
			return [] as Array[FuzzyVariable]
		found.append(variable)
	return found


static func _variable(entry: Variant, is_output: bool) -> FuzzyVariable:
	if not (entry is Dictionary) or not (entry.get("sets") is Dictionary):
		return null
	for field: String in ["minimum", "maximum"] + (["samples"] if is_output else []):
		if not (entry.get(field) is float):
			return null
	var sets: Array[FuzzySet] = []
	for set_name: String in entry["sets"]:
		if not (entry["sets"][set_name] is Array):
			return null
		sets.append(FuzzySet.new(set_name, PackedFloat64Array(entry["sets"][set_name])))
	var samples: int = int(entry["samples"]) if is_output else 0
	return FuzzyVariable.new(str(entry.get("name", "")), entry["minimum"], entry["maximum"],
			sets, samples)


static func _rules(entries: Variant) -> Array[FuzzyRule]:
	var found: Array[FuzzyRule] = []
	if not (entries is Array):
		return found
	for entry: Variant in entries:
		var rule: FuzzyRule = _rule(entry)
		if rule == null:
			return found
		found.append(rule)
	return found


static func _rule(entry: Variant) -> FuzzyRule:
	if not (entry is Dictionary):
		return null
	if not (entry.get("if") is Array) or not (entry.get("then") is Array):
		return null
	var conditions: Array[PackedStringArray] = []
	for condition: Variant in entry["if"]:
		conditions.append(PackedStringArray(condition if condition is Array else []))
	var connective: String = str(entry.get("connective", FuzzyRule.AND))
	return FuzzyRule.new(conditions, PackedStringArray(entry["then"]), connective)
