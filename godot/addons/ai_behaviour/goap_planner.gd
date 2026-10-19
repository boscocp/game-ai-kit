## Goal-oriented action planning: given a goal, find the cheapest list of
## actions that makes it hold -- searched backwards, from the goal.
##
## F.E.A.R. used "A\* to plan sequences of actions as well as to plan paths"
## (Orkin, 2006). A\* here walks from the goal towards the world as it is:
## a node is what has to be true at that point of the plan, and an action is
## worth trying when one of its effects makes some of that true without
## undoing the rest. Regressing through it swaps what it makes for what it
## needs. The search ends when everything a node asks for already holds in
## the world. A fact the world already has stays in the node all the same --
## dropping it let an action that undoes it slip through, and a test caught
## exactly that.
##
## Backwards is the comparison T15 is about. `ai_planning`'s STRIPS planner
## searches forwards, from the world, and claims the *shortest* plan -- the
## fewest actions; this one claims the *cheapest*, by the actions' costs.
## Humphreys (Game AI Pro, ch. 12) notes
## that "GOAP and STRIPS planner variants" "use a backward search", and
## that his studio's forward HTN was "considerably faster" than its GOAP.
## Searching backwards only ever considers actions that touch the goal, which
## is its strength; it cannot hand back a partial plan, because until it
## reaches the world it does not know where the plan starts.
##
## The guess is the number of facts a node asks for that the world lacks.
## Admissible when no action costs less than the number of facts it makes --
## true of the guard here, where every action makes one and costs 1, not of
## every domain -- and then the plan found is the cheapest.
##
## Complexity: A\* over sets of facts to make true, at most 2^facts of
## them; each expansion tries every action once.
##
## When not to use it: a goal reached through long chains of the same few
## actions, or many agents in one search. Van der Sterren's warning, quoted
## in the concept page: GOAP "struggle[s] to search efficiently in such a
## large state-space".
class_name GoapPlanner
extends RefCounted

## Worlds taken off the frontier before a call gives up.
const DEFAULT_BUDGET: int = 5000


## The cheapest plan from `world` that makes every fact in `goal` hold, or a
## plan that says why there is none.
func plan(actions: Array[GoapAction], world: Dictionary, goal: Dictionary, budget: int = DEFAULT_BUDGET) -> BehaviourPlan:
	var start: Dictionary = goal.duplicate()
	var frontier: Array[Array] = [[start, 0, [] as Array[String]]]
	var cheapest: Dictionary[String, int] = {_key(start): 0}
	var visited: int = 0
	while not frontier.is_empty():
		if visited >= budget:
			return BehaviourPlan.new([], false, visited, true)
		var node: Array = frontier.pop_at(_cheapest_guess(frontier, world))
		visited += 1
		if _still_to_do(node[0], world).is_empty():
			return BehaviourPlan.new(node[2], true, visited, false)
		_expand(node, actions, frontier, cheapest)
	return BehaviourPlan.new([], false, visited, false)


# Queue, for every action worth doing last before `node`, what has to hold
# before it -- unless that was already queued as cheaply.
static func _expand(node: Array, actions: Array[GoapAction], frontier: Array[Array], cheapest: Dictionary[String, int]) -> void:
	for action: GoapAction in actions:
		var regressed: Variant = _regress(node[0], action)
		var cost: int = node[1] + action.cost
		if regressed == null or cheapest.get(_key(regressed), cost + 1) <= cost:
			continue
		cheapest[_key(regressed)] = cost
		var steps: Array[String] = [action.name]
		steps.append_array(node[2])
		frontier.append([regressed, cost, steps])


# What has to be true before `action`, for `wanted` to be true after it: its
# effects' part of `wanted` is met, and its preconditions are wanted too.
# Null when the action makes nothing wanted, undoes something wanted, or
# needs the opposite of something wanted.
static func _regress(wanted: Dictionary, action: GoapAction) -> Variant:
	var helps: bool = false
	for fact: String in action.effects:
		if wanted.has(fact) and wanted[fact] != action.effects[fact]:
			return null
		helps = helps or wanted.has(fact)
	if not helps:
		return null
	var left: Dictionary = {}
	for fact: String in wanted:
		if not action.effects.has(fact):
			left[fact] = wanted[fact]
	for fact: String in action.preconditions:
		if left.has(fact) and left[fact] != action.preconditions[fact]:
			return null
		left[fact] = action.preconditions[fact]
	return left


# The facts of `wanted` the world does not already have.
static func _still_to_do(wanted: Dictionary, world: Dictionary) -> Dictionary:
	var left: Dictionary = {}
	for fact: String in wanted:
		if world.get(fact, false) != wanted[fact]:
			left[fact] = wanted[fact]
	return left


# The frontier entry with the least cost plus guess; ties to the first added.
static func _cheapest_guess(frontier: Array[Array], world: Dictionary) -> int:
	var best: int = 0
	for index: int in range(1, frontier.size()):
		if _f(frontier[index], world) < _f(frontier[best], world):
			best = index
	return best


# Cost so far plus the guess: the facts the node asks for that the world lacks.
static func _f(entry: Array, world: Dictionary) -> int:
	return entry[1] + _still_to_do(entry[0], world).size()


static func _key(wanted: Dictionary) -> String:
	var facts: Array = wanted.keys()
	facts.sort()
	return ",".join(facts.map(func(fact: String) -> String: return "%s=%s" % [fact, wanted[fact]]))
