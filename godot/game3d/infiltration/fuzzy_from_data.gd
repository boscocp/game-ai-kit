## A fuzzy rule base from the JSON shape `spec/vectors/fuzzy/README.md`
## documents: inputs and outputs with their sets, and rules of `if`,
## `connective` and `then`.
##
## The same shape the fuzzy vectors use, so `gameaikit.fuzzy.loading` reads
## a guard type's rate controller with no new code, and the Python twin of
## the rate is the fuzzy package itself. The rule base checks what it was
## given (`FuzzyRuleBase.problem`); this only builds it. Linear in the data.
##
## When not to use it: a controller a designer writes by hand in code to be
## read aloud, as `Suspicion.build_controller` does. Data is for rows that
## change per guard type.
class_name FuzzyFromData
extends RefCounted


## The rule base `data` describes.
static func rule_base(data: Dictionary) -> FuzzyRuleBase:
	return FuzzyRuleBase.new(_variables(data["inputs"], false), _variables(data["outputs"], true), _rules(data["rules"]))


static func _variables(entries: Array, is_output: bool) -> Array[FuzzyVariable]:
	var found: Array[FuzzyVariable] = []
	for entry: Dictionary in entries:
		var sets: Array[FuzzySet] = []
		for set_name: String in entry["sets"]:
			sets.append(FuzzySet.new(set_name, PackedFloat64Array(entry["sets"][set_name])))
		var samples: int = int(entry["samples"]) if is_output else 0
		found.append(FuzzyVariable.new(entry["name"], float(entry["minimum"]), float(entry["maximum"]), sets, samples))
	return found


static func _rules(entries: Array) -> Array[FuzzyRule]:
	var found: Array[FuzzyRule] = []
	for entry: Dictionary in entries:
		var conditions: Array[PackedStringArray] = []
		for condition: Array in entry["if"]:
			conditions.append(PackedStringArray(condition))
		found.append(FuzzyRule.new(conditions, PackedStringArray(entry["then"]), str(entry.get("connective", FuzzyRule.AND))))
	return found
