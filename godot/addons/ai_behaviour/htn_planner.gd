## A hierarchical task network planner: break the top task down, method by
## method, forwards from the world as it is, until only things it can do are
## left.
##
## SHOP2's way (Nau and colleagues, 2003), the one Humphreys describes for
## games (Game AI Pro, ch. 12): it "generates the steps of each plan in the
## same order that those steps will later be executed, so it knows the
## current state". The first task on the list is taken up; a primitive one is
## done to a copy of the world if its preconditions hold; a compound one is
## replaced by the subtasks of its first method whose conditions hold. When
## a branch reaches a primitive task it cannot do, it goes back to the last
## method it chose and tries the next one -- backtracking, which is what
## makes the order of methods a preference and not a trap.
##
## Forwards is what would let it hand back the first steps of a plan it has
## not finished -- this one does not, the guard's plans are short -- and it
## searches only the orders its methods allow: the two advantages Humphreys
## names over GOAP. The price is the methods: every order the agent can
## follow is one somebody wrote.
##
## `visited` counts tasks taken up -- the compound ones included, which are
## not worlds -- so beside GOAP's worlds off the frontier it is the nearest
## count, not the same unit.
##
## Complexity: depth-first over methods; without backtracking, linear in the
## tasks of the plan, and at worst every combination of methods.
##
## When not to use it: a problem whose order nobody can write down. GOAP or
## STRIPS search for one; an HTN only chooses among the ones it was given.
class_name HtnPlanner
extends RefCounted

## Tasks taken up before a call gives up.
const DEFAULT_BUDGET: int = 5000

var _domain: HtnDomain
var _visited: int = 0
var _budget: int = DEFAULT_BUDGET
# True once a branch was abandoned for the budget rather than for its methods.
var _cut_off: bool = false


## The primitive steps `top` breaks down into from `world`, with the method
## chosen for each compound task on the way; unsolved when no method leads to
## steps that can all be done.
func plan(domain: HtnDomain, world: Dictionary, top: String, budget: int = DEFAULT_BUDGET) -> BehaviourPlan:
	_domain = domain
	_visited = 0
	_budget = budget
	_cut_off = false
	var found: BehaviourPlan = BehaviourPlan.new()
	var solved: bool = _decompose([top] as Array[String], world.duplicate(), found)
	found.solved = solved
	found.visited = _visited
	found.gave_up = not solved and _cut_off
	if not solved:
		found.steps.clear()
		found.methods.clear()
	return found


# Carry out `tasks` in order from `world`, writing steps and methods into
# `found`; true when they all could be. On false, a method tried here has
# been taken back with every step under it; `plan` clears the rest.
func _decompose(tasks: Array[String], world: Dictionary, found: BehaviourPlan) -> bool:
	if tasks.is_empty():
		return true
	if _visited >= _budget:
		_cut_off = true
		return false
	_visited += 1
	var task: String = tasks[0]
	var rest: Array[String] = tasks.slice(1)
	if _domain.primitives.has(task):
		return _do(task, rest, world, found)
	for method: Array in _domain.compounds.get(task, []):
		if not HtnDomain.holds(method[1], world):
			continue
		var steps_before: int = found.steps.size()
		found.methods.append("%s: %s" % [task, method[0]])
		var expanded: Array[String] = method[2].duplicate()
		expanded.append_array(rest)
		if _decompose(expanded, world, found):
			return true
		found.steps.resize(steps_before)
		found.methods.pop_back()
	return false


# A primitive task: done to a copy of the world if it can be, then the rest.
# A step it appends and that leads nowhere is taken back by the method that
# chose it (`_decompose`), which is the one place a branch is undone.
func _do(task: String, rest: Array[String], world: Dictionary, found: BehaviourPlan) -> bool:
	var needs: Dictionary = _domain.primitives[task][0]
	if not HtnDomain.holds(needs, world):
		return false
	var after: Dictionary = world.duplicate()
	after.merge(_domain.primitives[task][1], true)
	found.steps.append(task)
	return _decompose(rest, after, found)
