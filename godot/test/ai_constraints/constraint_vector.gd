## One constraint vector from spec/vectors/constraints: whether it is one,
## the problem and solver it describes, and which of its claims a solver
## fails. The runner and `constraint_vector_test.gd` both read through it, so
## the rules the suite plants broken vectors against are the runner's rules.
class_name ConstraintVector
extends RefCounted

const KEYS: Array[String] = ["assigned", "assignments", "backtracks", "binary", "description", "global", "lcv",
		"mrv", "propagate", "pruned", "seed", "solution", "variables"]
const RELATIONS: Array[String] = ["different", "less", "queens"]
const GLOBALS: Array[String] = ["sum-at-most", "some-equals"]
## The types this reads, checked before anything reads them (T121). A
## domain is numbers or names, never both: the solver compares its values
## with `!=` and `<`, and a name beside a number is a SCRIPT ERROR there.
## V8 holds that, which the shape cannot say. An assigned value is only
## compared whole with the solver's, so it may be either.
const SHAPE: Dictionary = {
	"assigned": [[VectorShape.TEXT, VectorShape.ANY]], "assignments": VectorShape.NUMBER, "backtracks": VectorShape.NUMBER,
	"binary": [{"between": [VectorShape.TEXT], "relation": VectorShape.TEXT, "apart?": VectorShape.NUMBER}],
	"global": [{"over": [VectorShape.TEXT], "relation": VectorShape.TEXT, "limit?": VectorShape.NUMBER,
			"value?": VectorShape.NUMBER}],
	"lcv": VectorShape.FLAG, "mrv": VectorShape.FLAG, "propagate": VectorShape.FLAG, "pruned": VectorShape.NUMBER,
	"seed": VectorShape.NUMBER, "solution": VectorShape.OBJECT_OR_NULL,
	"variables": [{"name": VectorShape.TEXT, "values": VectorShape.LIST}],
}


## Why `vector` is not a usable vector, or "" when it is one -- the same
## rules, V1 to V6, as `test_constraints_vectors.py`, and V7, its types.
static func why_not_a_vector(vector: Dictionary, file: String = "the file") -> String:
	var keys: Array = vector.keys()
	keys.sort()
	if keys != KEYS:
		return "V1 its keys are %s, not %s" % [keys, KEYS]
	var types: String = VectorShape.why_not(vector, SHAPE, file)
	if types != "":
		return "V7 " + types
	for variable: Dictionary in vector["variables"]:
		if not _one_kind(variable["values"]):
			return "V8 %s's values are not all numbers or all names" % variable["name"]
	if (vector["binary"] as Array).any(func(entry: Dictionary) -> bool: return not RELATIONS.has(entry.get("relation"))):
		return "V2 a binary constraint names a relation neither side knows"
	if (vector["global"] as Array).any(func(entry: Dictionary) -> bool: return not GLOBALS.has(entry.get("relation"))):
		return "V3 a global constraint names a relation neither side knows"
	var declared: String = problem_of(vector).problem()
	if declared != "":
		return "V4 its problem cannot be declared: %s" % declared
	if (vector["assigned"] as Array).size() != int(vector["assignments"]):
		return "V5 its assignments do not count the values it claims were assigned"
	if vector["solution"] != null and (vector["solution"] as Dictionary).size() != (vector["variables"] as Array).size():
		return "V6 its solution does not name every variable"
	return ""


## The problem the vector declares, in its order.
static func problem_of(vector: Dictionary) -> ConstraintProblem:
	var problem := ConstraintProblem.new()
	for variable: Dictionary in vector["variables"]:
		problem.add_variable(variable["name"], variable["values"])
	for entry: Dictionary in vector["binary"]:
		problem.add_binary(entry["between"][0], entry["between"][1], _allowed_by(entry), entry["relation"])
	for entry: Dictionary in vector["global"]:
		var names: Array[String] = []
		names.assign(entry["over"])
		problem.add_global(names, _holds_by(entry, names), entry["relation"])
	return problem


## The solver the vector's settings describe, recording its steps; `solver`
## is a planted subclass's instance to configure instead, when given.
static func solver_of(vector: Dictionary, solver: ConstraintSolver = null) -> ConstraintSolver:
	var made: ConstraintSolver = solver if solver != null else ConstraintSolver.new(problem_of(vector), int(vector["seed"]))
	made.seed_value = int(vector["seed"])
	made.mrv = vector["mrv"]
	made.lcv = vector["lcv"]
	made.propagate = vector["propagate"]
	made.record = true
	return made


## Every claim of `vector` that `solver` does not reproduce.
static func wrong_claims(vector: Dictionary, solver: ConstraintSolver) -> Array[String]:
	var found: Dictionary = solver.solve()
	var assigned: Array = []
	for event: Dictionary in solver.trace:
		if event["event"] == "assign":
			assigned.append([event["variable"], event["value"]])
	var wanted: Variant = vector["solution"] if vector["solution"] != null else {}
	var claims: Array = [["solution", found, wanted], ["assigned", assigned, vector["assigned"]],
			["assignments", solver.assignments, int(vector["assignments"])],
			["backtracks", solver.backtracks, int(vector["backtracks"])], ["pruned", solver.pruned, int(vector["pruned"])]]
	var wrong: Array[String] = []
	for claim: Array in claims:
		if claim[1] != claim[2]:
			wrong.append("%s: %s, the vector says %s" % claim)
	return wrong


# True when every value is a number, or every value is a name.
static func _one_kind(values: Array) -> bool:
	var numbers: bool = values.all(func(value: Variant) -> bool: return value is float or value is int)
	var names: bool = values.all(func(value: Variant) -> bool: return value is String)
	return numbers or names


# The sum of the values `names` have been given so far.
static func _sum_of(partial: Dictionary, names: Array[String]) -> float:
	var total: float = 0.0
	for name: String in names:
		total += float(partial.get(name, 0.0))
	return total


static func _allowed_by(entry: Dictionary) -> Callable:
	match entry["relation"]:
		"different":
			return func(first: Variant, second: Variant) -> bool: return first != second
		"less":
			return func(first: Variant, second: Variant) -> bool: return first < second
	var apart: float = float(entry.get("apart", 0))
	return func(first: Variant, second: Variant) -> bool: return first != second and absf(first - second) != apart


static func _holds_by(entry: Dictionary, names: Array[String]) -> Callable:
	if entry["relation"] == "sum-at-most":
		var most: float = float(entry["limit"])
		return func(partial: Dictionary) -> bool: return _sum_of(partial, names) <= most
	var wanted: Variant = entry["value"]
	return func(partial: Dictionary) -> bool:
		return names.any(func(name: String) -> bool: return not partial.has(name) or partial[name] == wanted)
