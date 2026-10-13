## A complete fuzzy controller: inputs, outputs, and the rules between them.
##
## Evaluating is three steps -- fuzzify every input, give every rule a strength
## and every output term its strongest rule, defuzzify -- and costs one pass
## over the rules plus the centroid's samples x sets per output.
##
## When not to use it: past a dozen rules, or over discrete inputs. Twenty
## overlapping rules are a system nobody can predict, since every change moves
## every output a little; a decision tree says the same more plainly.
class_name FuzzyRuleBase
extends RefCounted

var inputs: Array[FuzzyVariable]
var outputs: Array[FuzzyVariable]
var rules: Array[FuzzyRule]


func _init(controller_inputs: Array[FuzzyVariable], controller_outputs: Array[FuzzyVariable],
		controller_rules: Array[FuzzyRule]) -> void:
	inputs = controller_inputs
	outputs = controller_outputs
	rules = controller_rules


## Why this controller cannot be evaluated, or "" when it can.
##
## Found afresh on every call rather than once at construction: the three
## arrays are public, and a cached answer went on saying "" after a rule
## naming a set nobody declared was appended. Checking costs about what one
## evaluation does. The codes `F1`-`F7` are the Python side's; Python's `F8`,
## a missing or non-finite input, is answered here by `fuzzify` returning {}.
func problem() -> String:
	return _find_problem()


## Every input's degrees, by variable and then set; {} when an input is
## missing, or is not a finite number.
##
## Missing is refused rather than read as zero: a guard given no distance is
## not a guard who saw the player at distance zero. A string is refused rather
## than converted, because `float("abc")` is 0.0 and would be read as one.
func fuzzify(values: Dictionary) -> Dictionary:
	var degrees: Dictionary = {}
	for variable: FuzzyVariable in inputs:
		var value: Variant = values.get(variable.name)
		if not (value is float or value is int) or not is_finite(float(value)):
			return {}
		degrees[variable.name] = variable.fuzzify(float(value))
	return degrees


## How strongly each output term is concluded -- the *why* of a decision.
##
## Every term of every output appears, at 0 when nothing concluded it, so an
## overlay drawn from this shows the rules that did not fire as well. {} when
## the controller has a problem or an input is missing.
func activations(values: Dictionary) -> Dictionary:
	var degrees: Dictionary = fuzzify(values)
	if degrees.is_empty() or problem() != "":
		return {}
	var strengths: Dictionary = {}
	for output: FuzzyVariable in outputs:
		var terms: Dictionary[String, float] = {}
		for one: FuzzySet in output.sets:
			terms[one.name] = 0.0
		strengths[output.name] = terms
	for rule: FuzzyRule in rules:
		var terms: Dictionary = strengths[rule.conclusion[0]]
		terms[rule.conclusion[1]] = maxf(terms[rule.conclusion[1]], rule.strength(degrees))
	return strengths


## One number per output: NAN where no rule reached it, and NAN for every
## output when the controller has a problem or an input is missing.
func evaluate(values: Dictionary) -> Dictionary[String, float]:
	var strengths: Dictionary = activations(values)
	var answers: Dictionary[String, float] = {}
	for output: FuzzyVariable in outputs:
		if strengths.is_empty():
			answers[output.name] = NAN
		else:
			answers[output.name] = FuzzyCentroid.of(output, strengths[output.name])
	return answers


func _find_problem() -> String:
	for variable: FuzzyVariable in inputs:
		if variable.problem(false) != "":
			return variable.problem(false)
	for variable: FuzzyVariable in outputs:
		if variable.problem(true) != "":
			return variable.problem(true)
		var unsampled: String = _unsampled_set(variable)
		if unsampled != "":
			return "F3 output %s: no sample point falls inside set %s" % [variable.name, unsampled]
	var names: Dictionary[String, bool] = {}
	for variable: FuzzyVariable in inputs + outputs:
		if names.has(variable.name):
			return "F4 two variables share the name %s" % variable.name
		names[variable.name] = true
	if rules.is_empty():
		return "F5 a controller with no rules concludes nothing"
	for index: int in range(rules.size()):
		var wrong: String = _rule_problem(index + 1, rules[index])
		if wrong != "":
			return wrong
	return ""


# The first set of this output that no sample point lands inside, or "".
#
# Such a set can be concluded at full strength and add nothing to the pile,
# and the answer is then NAN -- which everywhere else here means no rule fired.
func _unsampled_set(output: FuzzyVariable) -> String:
	for one: FuzzySet in output.sets:
		var reached: bool = false
		for index: int in range(output.samples):
			reached = reached or one.degree(FuzzyCentroid.sample_point(output, index)) > 0.0
		if not reached:
			return one.name
	return ""


func _rule_problem(number: int, rule: FuzzyRule) -> String:
	if not rule.connective in FuzzyRule.CONNECTIVES:
		return "F6 rule %d joins with %s" % [number, rule.connective]
	if rule.conditions.is_empty():
		return "F6 rule %d has no conditions" % number
	for condition: PackedStringArray in rule.conditions:
		if not _names_a_set(inputs, condition):
			return "F7 rule %d tests %s, which is no input's set" % [number, " IS ".join(condition)]
	if not _names_a_set(outputs, rule.conclusion):
		return "F7 rule %d concludes %s, which is no output's set" % [
			number, " IS ".join(rule.conclusion)]
	return ""


func _names_a_set(variables: Array[FuzzyVariable], pair: PackedStringArray) -> bool:
	if pair.size() != 2:
		return false
	for variable: FuzzyVariable in variables:
		if variable.name == pair[0]:
			return variable.set_named(pair[1]) != null
	return false
