## What a solution is, declared: variables, the values each may take, and
## the constraints between them -- a constraint satisfaction problem (AIMA
## 4th ed., 6.1).
##
## The lesson is the other way round from a generator. A generator says
## *how* to make something and hopes it is good; a problem says *what* good
## is and leaves the how to a solver (`ConstraintSolver`). Three things are
## declared:
##
## * a **variable** and its **domain**, the finite list of values it may
##   take -- here anything `==` can compare: a colour, a digit, the index of
##   a candidate place;
## * a **binary constraint** on two variables: a test of a pair of values,
##   `allowed(first_value, second_value) -> bool`. These are the ones the
##   solver propagates, crossing out values that no value at the other end
##   allows (AC-3);
## * a **global constraint** on any number of variables: a test of a
##   *partial* assignment, `holds(assignment: Dictionary) -> bool`. It must
##   answer false only when no way of assigning the rest could satisfy it --
##   "the exit cannot be reached" is false as soon as the boxes placed so far
##   wall it off, since more boxes never open a way -- and true while it
##   cannot yet tell. The solver checks these after each assignment; it does
##   not propagate them. It must not change the assignment it is shown.
##   A game supplies them: reachability, sight and light are the game's.
##
## Complexity: declaring is linear in what is declared.
##
## When not to use it: when any answer will do and the first draw is
## usually good -- generate and test is simpler. When a constraint is soft
## ("rather far than near"): this is yes or no; a score is a utility, and an
## optimiser's job.
class_name ConstraintProblem
extends RefCounted

## Every variable, in the order declared.
var variables: Array[String] = []
## Variable -> the values it may take, in the order declared.
var domains: Dictionary = {}
## Each binary constraint: `first`, `second`, `allowed` (a Callable on the
## first's value then the second's) and `label`, in the order added.
var binaries: Array[Dictionary] = []
## Each global constraint: `names`, `holds` (a Callable on a partial
## assignment) and `label`, in the order added.
var globals: Array[Dictionary] = []
var _touching: Dictionary = {}
var _mistakes: Array[String] = []


## Declare `name`, which may take any of `values`, in that order.
func add_variable(name: String, values: Array) -> void:
	if domains.has(name):
		_mistakes.append("the variable '%s' is declared twice" % name)
		return
	variables.append(name)
	domains[name] = values.duplicate()
	_touching[name] = PackedInt32Array()


## Only pairs for which `allowed.call(first_value, second_value)` is true
## may stand together.
func add_binary(first: String, second: String, allowed: Callable, label: String = "") -> void:
	if not domains.has(first) or not domains.has(second) or first == second:
		_mistakes.append("the constraint '%s' needs two declared variables, not '%s' and '%s'" % [label, first, second])
		return
	_touching[first].append(binaries.size())
	_touching[second].append(binaries.size())
	binaries.append({"first": first, "second": second, "allowed": allowed, "label": label})


## `holds.call(partial_assignment)` must not answer false while some way of
## assigning the rest would satisfy it.
func add_global(names: Array[String], holds: Callable, label: String = "") -> void:
	var missing: Array[String] = names.filter(func(name: String) -> bool: return not domains.has(name))
	if names.is_empty() or not missing.is_empty():
		_mistakes.append("the constraint '%s' names no declared variable, or %s" % [label, missing])
		return
	globals.append({"names": names.duplicate(), "holds": holds, "label": label})


## The binary constraints on `name`, as indices into `binaries`, in the order
## added: what the solver walks to find a variable's neighbours.
func touching(name: String) -> PackedInt32Array:
	return _touching[name]


## The variable at the other end of binary constraint `index` from `name`.
func other_end(index: int, name: String) -> String:
	var binary: Dictionary = binaries[index]
	return binary["second"] if name == binary["first"] else binary["first"]


## Whether binary constraint `index` lets `name` = `value` stand beside its
## other end = `other_value`, whichever end `name` is.
func allows(index: int, name: String, value: Variant, other_value: Variant) -> bool:
	var binary: Dictionary = binaries[index]
	if name == binary["first"]:
		return binary["allowed"].call(value, other_value)
	return binary["allowed"].call(other_value, value)


## What is wrong with the declaration, or "" when nothing is. Call it after
## declaring: a misspelt variable is refused here rather than ignored.
func problem() -> String:
	if not _mistakes.is_empty():
		return _mistakes[0]
	if variables.is_empty():
		return "a problem needs at least one variable"
	for name: String in variables:
		if (domains[name] as Array).is_empty():
			return "the variable '%s' has no value it may take" % name
	return ""
