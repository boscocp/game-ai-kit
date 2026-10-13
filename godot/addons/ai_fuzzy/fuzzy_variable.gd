## A quantity a controller reads or writes, and the terms that describe it.
##
## An input is clamped into its range before it is fuzzified: a guard should
## not stop worrying about a player for being further off than the designer
## drew. An output is sampled across its range, `samples` times, by the
## centroid. Fuzzifying costs one `FuzzySet.degree` per set.
##
## When not to use it: a value with two states. Two sets over it are a boolean.
class_name FuzzyVariable
extends RefCounted

var name: String
var minimum: float
var maximum: float
var sets: Array[FuzzySet]

## Where `FuzzyCentroid` measures this output. An input leaves it at 0.
var samples: int


func _init(variable_name: String, low: float, high: float,
		variable_sets: Array[FuzzySet], sample_count: int = 0) -> void:
	name = variable_name
	minimum = low
	maximum = high
	sets = variable_sets
	samples = sample_count


## Why this variable cannot be read or sampled, or "" when it can.
func problem(is_output: bool) -> String:
	if not minimum < maximum:
		return "F2 variable %s has an empty range" % name
	if sets.is_empty():
		return "F2 variable %s has no sets" % name
	var seen: Dictionary[String, bool] = {}
	for one: FuzzySet in sets:
		if seen.has(one.name):
			return "F2 variable %s names a set twice" % name
		seen[one.name] = true
	if is_output and samples < 2:
		return "F3 output %s needs at least two samples" % name
	for one: FuzzySet in sets:
		if one.problem() != "":
			return one.problem()
	return ""


## The set called `set_name`, or null.
func set_named(set_name: String) -> FuzzySet:
	for one: FuzzySet in sets:
		if one.name == set_name:
			return one
	return null


## Every set's degree for one crisp value, clamped into the range first.
func fuzzify(value: float) -> Dictionary[String, float]:
	var clamped: float = clampf(value, minimum, maximum)
	var degrees: Dictionary[String, float] = {}
	for one: FuzzySet in sets:
		degrees[one.name] = one.degree(clamped)
	return degrees
