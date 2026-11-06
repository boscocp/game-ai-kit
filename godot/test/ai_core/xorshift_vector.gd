## One core vector: seeds, and the draws, uniforms and picks a fresh
## generator makes from each.
##
## Apart from the runner, as every family here is: a runner is a `SceneTree`,
## hard to test, and a rule living there can be deleted with every gate
## green. `xorshift_test.gd` plants a case for each rule below, and
## generators that draw differently.
##
## When not to use it: anything but `spec/vectors/core/`, whose README holds
## the shape.
class_name XorshiftVector
extends RefCounted

## The margin a uniform may differ by. The division is exact in a double;
## the margin is for the decimal text the JSON carries, read back.
const TOLERANCE: float = 1e-12
const VECTOR_KEYS: Array[String] = ["cases", "description"]
const CASE_KEYS: Array[String] = ["draws", "picks", "picks_of", "seed", "uniforms"]


## Why this dictionary is not a usable core vector, or "" when it is one.
## A key nobody reads is refused: a misspelt claim would otherwise be dropped.
## So is a value of the wrong type, checked before anything reads it: a cast
## that fails in a `-s` script is a SCRIPT ERROR that skips the check and
## still lets the runner print "0 failure(s)" (CLAUDE.md, the traps).
static func why_not_a_vector(vector: Dictionary) -> String:
	if _sorted_keys(vector) != VECTOR_KEYS:
		return "X1 its keys are %s, not %s" % [_sorted_keys(vector), VECTOR_KEYS]
	if not vector["cases"] is Array:
		return "X6 its cases are not a list"
	if (vector["cases"] as Array).is_empty():
		return "X2 it claims nothing"
	for case: Variant in vector["cases"]:
		var why: String = _why_not_a_case(case)
		if why != "":
			return why
	return ""


# X3 to X6 for one case: its keys, its types, then its lengths.
static func _why_not_a_case(case: Variant) -> String:
	if not case is Dictionary:
		return "X6 a case is not an object"
	if _sorted_keys(case) != CASE_KEYS:
		return "X3 a case's keys are %s, not %s" % [_sorted_keys(case), CASE_KEYS]
	if not (case["seed"] is float or case["seed"] is int):
		return "X6 a case's seed is not a number"
	for key: String in ["draws", "picks", "picks_of", "uniforms"]:
		if not _numbers(case[key]):
			return "X6 seed %d: %s is not a list of numbers" % [int(case["seed"]), key]
	if (case["picks"] as Array).size() != (case["picks_of"] as Array).size():
		return "X4 seed %d: picks and picks_of differ in length" % int(case["seed"])
	if (case["draws"] as Array).is_empty() or (case["uniforms"] as Array).is_empty():
		return "X5 seed %d: no draw or no uniform to check" % int(case["seed"])
	return ""


static func _numbers(value: Variant) -> bool:
	if not value is Array:
		return false
	for number: Variant in value:
		if not (number is float or number is int):
			return false
	return true


## The generator `ai_core` builds, as a `make` for `wrong_claims`.
static func core_generator() -> Callable:
	return func(from_seed: int) -> GakXorshift: return GakXorshift.new(from_seed)


## Every claim in the vector that the generators `make` builds do not meet,
## each named by its seed and what it drew instead.
static func wrong_claims(vector: Dictionary, make: Callable) -> Array[String]:
	var wrong: Array[String] = []
	for case: Dictionary in vector["cases"]:
		var from_seed: int = int(case["seed"])
		var drawn: Array = _draws(make.call(from_seed), (case["draws"] as Array).size())
		if drawn != _whole(case["draws"]):
			wrong.append("seed %d: drew %s, not %s" % [from_seed, drawn, case["draws"]])
		var uniforms: Array = _uniforms(make.call(from_seed), (case["uniforms"] as Array).size())
		if not _near(uniforms, case["uniforms"]):
			wrong.append("seed %d: uniforms %s, not %s" % [from_seed, uniforms, case["uniforms"]])
		var picks: Array = _picks(make.call(from_seed), case["picks_of"])
		if picks != _whole(case["picks"]):
			wrong.append("seed %d: picked %s, not %s" % [from_seed, picks, case["picks"]])
	return wrong


static func _draws(generator: GakXorshift, count: int) -> Array:
	var drawn: Array = []
	for _draw: int in count:
		drawn.append(generator.next())
	return drawn


static func _uniforms(generator: GakXorshift, count: int) -> Array:
	var drawn: Array = []
	for _draw: int in count:
		drawn.append(generator.uniform())
	return drawn


static func _picks(generator: GakXorshift, counts: Array) -> Array:
	var picked: Array = []
	for count: Variant in counts:
		picked.append(generator.index(int(count)))
	return picked


static func _near(found: Array, claimed: Array) -> bool:
	if found.size() != claimed.size():
		return false
	for position: int in found.size():
		if absf(float(found[position]) - float(claimed[position])) > TOLERANCE:
			return false
	return true


static func _whole(numbers: Array) -> Array:
	return numbers.map(func(number: Variant) -> int: return int(number))


static func _sorted_keys(dictionary: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for key: Variant in dictionary.keys():
		keys.append(str(key))
	keys.sort()
	return keys
