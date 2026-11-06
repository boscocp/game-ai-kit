## An assignment that breaks none of a `ConstraintProblem`'s constraints,
## or the news that there is none: backtracking search with the three
## choices AIMA 4th ed. names (6.3, fig. 6.5), and AC-3 (6.2.2, fig. 6.3).
##
## It reads top to bottom as the book's pseudocode:
##
## 1. **AC-3 once, before searching.** An *arc* is one direction of a binary
##    constraint, X towards Y. To *revise* it is to cross out each value of
##    X that no value left of Y allows. When X loses a value, every arc into
##    X is revised again. A domain emptied means no solution, and no search.
## 2. **Choose a variable** by *minimum remaining values* (MRV): the one with
##    fewest values left, which fails soonest if it is going to. Of equal
##    ones, the one on most constraints with unassigned variables (the
##    *degree heuristic*); then the first in the seeded order.
## 3. **Order its values** by *least constraining value* (LCV): first the
##    value that crosses out fewest values of its unassigned neighbours,
##    leaving them most room. Of equal ones, the seeded order.
## 4. **Try each value**: refused when it breaks a binary constraint with an
##    assigned variable, or a global constraint on the partial assignment.
##    Otherwise assign it and *maintain arc consistency*: AC-3 again, from
##    the arcs into it. Search on; if that fails, undo the assignment and
##    everything it crossed out, and try the next value.
## 5. **Backtrack** when every value has failed: go back to the variable
##    before. `backtracks` counts those.
##
## Each choice can be switched off (`mrv`, `lcv`, `propagate`) to see what
## it is worth -- the same problem, the backtracks counted both ways.
##
## **Ties go the seed's way.** Before searching, the variables and then each
## domain are shuffled once by `ConstraintDraws`; every tie after that goes
## to whichever came first. The same problem and seed give the same
## assignment and the same counts here and in `gameaikit.constraints`, which
## `spec/vectors/constraints/` holds.
##
## With `record` on, every step is kept in `trace` -- chosen, assigned,
## refused, crossed out, undone, backtracked -- so a view can show the
## decisions that built the answer, not only the answer.
##
## Complexity: exponential in the variables in the worst case, as any
## complete search of a CSP is; AC-3 is O(c d^3) for c binary constraints
## and domains of d values. `limit` bounds the assignments tried.
##
## When not to use it: for constraints that are mostly global and cannot be
## propagated -- the search then degrades towards generate and test; or for
## problems large enough to want local search (min-conflicts, AIMA 6.4).
class_name ConstraintSolver
extends RefCounted

var problem: ConstraintProblem
var seed_value: int = ConstraintDraws.SEED_FOR_ZERO
var mrv: bool = true
var lcv: bool = true
var propagate: bool = true
var record: bool = false
## The most assignments tried before giving up; 0, no limit.
var limit: int = 0
## Each variable's values still possible, as the search stands.
var domains: Dictionary = {}
## Variable -> value, for those assigned so far.
var assignment: Dictionary = {}
## Every step, when `record` is on: each a Dictionary with an `event` --
## "choose", "assign", "refuse", "prune", "undo" or "backtrack" -- and the
## `variable`, with its `value`, `remaining` or `constraint` as it applies.
var trace: Array[Dictionary] = []
var assignments: int = 0
var backtracks: int = 0
var pruned: int = 0
var refusals: int = 0
## True when the search stopped before it was done -- `limit` ran out, or a
## subclass that never goes back stopped it (`WaveCollapse`, at a
## contradiction): no answer, and no proof of none.
var gave_up: bool = false
var _order: Array = []


## A solver for `of_problem`, its ties ordered by `from_seed`.
func _init(of_problem: ConstraintProblem, from_seed: int = ConstraintDraws.SEED_FOR_ZERO) -> void:
	problem = of_problem
	seed_value = from_seed


## The assignment, every variable in the order declared, or {} when there is
## none (or `gave_up`, when the limit ran out first). A declaration that
## `problem.problem()` refuses has none. Each call starts the counts, the
## trace and `gave_up` afresh.
func solve() -> Dictionary:
	_start_afresh()
	if problem.problem() != "":
		return {}
	var draws := ConstraintDraws.new(seed_value)
	_order = draws.shuffle(problem.variables)
	domains = {}
	for name: String in problem.variables:
		domains[name] = draws.shuffle(problem.domains[name])
	assignment = {}
	if propagate and not _ac3(_every_arc()):
		return {}
	var found: Dictionary = _backtrack()
	var ordered: Dictionary = {}
	if found.is_empty():
		return ordered
	for name: String in problem.variables:
		ordered[name] = found[name]
	return ordered


func _start_afresh() -> void:
	trace.clear()
	assignments = 0
	backtracks = 0
	pruned = 0
	refusals = 0
	gave_up = false


# -- the search, AIMA fig. 6.5 ------------------------------------------------

# Assign one more variable and go on; when every value fails, go back.
func _backtrack() -> Dictionary:
	if assignment.size() == problem.variables.size():
		return assignment.duplicate()
	var name: String = _select()
	_note({"event": "choose", "variable": name, "remaining": (domains[name] as Array).size()})
	for value: Variant in _values(name):
		var refused: Variant = _refusal(name, value)
		if refused != null:
			refusals += 1
			_note({"event": "refuse", "variable": name, "value": value, "constraint": refused})
			continue
		var found: Dictionary = _try(name, value)
		if not found.is_empty() or gave_up:
			return found
	backtracks += 1
	_note({"event": "backtrack", "variable": name})
	return {}


# Assign `value`, propagate, search on; undo it all when that fails.
func _try(name: String, value: Variant) -> Dictionary:
	if limit > 0 and assignments >= limit:
		gave_up = true
		return {}
	var saved: Dictionary = domains.duplicate(true)
	assignment[name] = value
	assignments += 1
	_note({"event": "assign", "variable": name, "value": value})
	domains[name] = [value]
	if not propagate or _ac3(_arcs_into(name)):
		var found: Dictionary = _backtrack()
		if not found.is_empty() or gave_up:
			return found
	domains = saved
	assignment.erase(name)
	_note({"event": "undo", "variable": name, "value": value})
	return {}


# Minimum remaining values, then the most constraints on unassigned
# variables, then the seeded order; without MRV, the seeded order alone.
func _select() -> String:
	var unassigned: Array = _order.filter(func(name: String) -> bool: return not assignment.has(name))
	var best: String = unassigned[0]
	if not mrv:
		return best
	for name: String in unassigned.slice(1):
		if _fewer(name, best):
			best = name
	return best


# Whether `name` has fewer values left than `best`, or as few and more
# constraints on unassigned variables.
func _fewer(name: String, best: String) -> bool:
	var left: int = (domains[name] as Array).size()
	var best_left: int = (domains[best] as Array).size()
	return left < best_left or (left == best_left and _degree(name) > _degree(best))


# How many binary constraints tie `name` to a variable not yet assigned.
func _degree(name: String) -> int:
	var count: int = 0
	for index: int in problem.touching(name):
		if not assignment.has(problem.other_end(index, name)):
			count += 1
	return count


# The domain, least constraining value first; equal ones in the seeded order.
# GDScript's sort is not stable, so the place breaks the tie explicitly.
func _values(name: String) -> Array:
	var values: Array = domains[name]
	if not lcv:
		return values.duplicate()
	var costs: Array[Vector2i] = []
	for place: int in range(values.size()):
		costs.append(Vector2i(_ruled_out(name, values[place]), place))
	costs.sort()
	return costs.map(func(cost: Vector2i) -> Variant: return values[cost.y])


# How many values of unassigned neighbours `name` = `value` would rule out.
func _ruled_out(name: String, value: Variant) -> int:
	var count: int = 0
	for index: int in problem.touching(name):
		var other: String = problem.other_end(index, name)
		if not assignment.has(other):
			count += _crossed_by(index, name, value, other)
	return count


# How many of `other`'s values constraint `index` forbids beside `name` = `value`.
func _crossed_by(index: int, name: String, value: Variant, other: String) -> int:
	var count: int = 0
	for other_value: Variant in domains[other]:
		if not problem.allows(index, name, value, other_value):
			count += 1
	return count


# The label of the first constraint `name` = `value` breaks with what is
# assigned, or null when it breaks none. A label may be "": "refused" and
# "why" are two answers, and an unlabelled constraint still refuses.
func _refusal(name: String, value: Variant) -> Variant:
	for index: int in problem.touching(name):
		var other: String = problem.other_end(index, name)
		if assignment.has(other) and not problem.allows(index, name, value, assignment[other]):
			return problem.binaries[index]["label"]
	assignment[name] = value
	var broken: Variant = null
	for rule: Dictionary in problem.globals:
		if (rule["names"] as Array).has(name) and not rule["holds"].call(assignment):
			broken = rule["label"]
			break
	assignment.erase(name)
	return broken


# -- inference, AIMA fig. 6.3 -------------------------------------------------
# An arc is Vector2i(constraint index, end): end 0 revises the constraint's
# first variable against its second, end 1 the second against the first.

func _every_arc() -> Array[Vector2i]:
	var arcs: Array[Vector2i] = []
	for index: int in range(problem.binaries.size()):
		arcs.append_array([Vector2i(index, 0), Vector2i(index, 1)])
	return arcs


# The arcs that revise each unassigned neighbour of `name` against it.
func _arcs_into(name: String) -> Array[Vector2i]:
	var arcs: Array[Vector2i] = []
	for index: int in problem.touching(name):
		if not assignment.has(problem.other_end(index, name)):
			arcs.append(_arc_revising(index, problem.other_end(index, name)))
	return arcs


func _arc_revising(index: int, target: String) -> Vector2i:
	return Vector2i(index, 0 if problem.binaries[index]["first"] == target else 1)


func _target_of(arc: Vector2i) -> String:
	return problem.binaries[arc.x]["first" if arc.y == 0 else "second"]


# Make every arc consistent; false when a domain is emptied.
func _ac3(arcs: Array[Vector2i]) -> bool:
	var waiting: Array[Vector2i] = arcs.duplicate()
	var queued: Dictionary = {}
	for arc: Vector2i in arcs:
		queued[arc] = true
	var head: int = 0
	while head < waiting.size():
		var arc: Vector2i = waiting[head]
		head += 1
		queued.erase(arc)
		var target: String = _target_of(arc)
		if not _revise(arc.x, target):
			continue
		if (domains[target] as Array).is_empty():
			return false
		_requeue(arc.x, target, waiting, queued)
	return true


# `target` lost a value: every arc into it, but the one just revised, goes
# back on the queue unless it is waiting there already.
func _requeue(revised: int, target: String, waiting: Array[Vector2i], queued: Dictionary) -> void:
	for other_index: int in problem.touching(target):
		var back: Vector2i = _arc_revising(other_index, problem.other_end(other_index, target))
		if other_index != revised and not queued.has(back):
			waiting.append(back)
			queued[back] = true


# Cross out each value of `target` that no value at the other end allows.
func _revise(index: int, target: String) -> bool:
	var other_values: Array = domains[problem.other_end(index, target)]
	var kept: Array = []
	for value: Variant in domains[target]:
		if other_values.any(func(other_value: Variant) -> bool: return problem.allows(index, target, value, other_value)):
			kept.append(value)
		else:
			_note({"event": "prune", "variable": target, "value": value, "constraint": problem.binaries[index]["label"]})
	var removed: int = (domains[target] as Array).size() - kept.size()
	domains[target] = kept
	pruned += removed
	return removed > 0


# Keep one step of the search, when asked to record them.
func _note(event: Dictionary) -> void:
	if record:
		trace.append(event)
