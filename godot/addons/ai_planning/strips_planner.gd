## Forward state-space planning: start from what is true, try every action,
## stop when the goal holds.
##
## The frontier is a queue, so the states come off in the order they were
## reached and the first plan that arrives is the one with the fewest actions.
## That is breadth-first, over worlds instead of over cells, and it is written
## out here rather than imported because no addon may depend on another -- the
## shape is the lesson, and the shape is three lines long.
##
## Complexity: O(states x actions), and the number of states is 2^predicates in
## the worst case. The space is finite, so this always terminates in principle;
## `budget` is about the difference between terminating and terminating this
## week.
##
## When not to use it: a domain with more than a dozen or so predicates. Then
## the answer is a heuristic planner -- relaxed-plan, landmarks -- and the
## reason those exist is exactly the number this one reports in `visited`.
class_name StripsPlanner
extends RefCounted

## How many states the planner will take off the frontier before giving up.
##
## There is nothing sacred about the number. What matters is that there is one
## and that hitting it is reported rather than dressed up as "no plan exists".
const DEFAULT_BUDGET: int = 50000


# One entry on the frontier: a world, and the actions that got to it.
#
# A pair of parallel arrays was the first version -- `frontier[i]` beside
# `plans[i]` -- and keeping two arrays in step is a rule nobody can see. This
# is the same thing with the rule held up by the type.
class Step:
	var world: WorldState
	var taken: Array[StripsAction]

	func _init(reached: WorldState, actions_so_far: Array[StripsAction]) -> void:
		world = reached
		taken = actions_so_far


## The shortest sequence of actions that makes `goal` hold, or a `PlanResult`
## saying why there is none.
##
## `goal` is a list of predicates that must all hold; a goal already satisfied
## returns an empty plan with `solved` true, which is why that field exists.
func plan(actions: Array[StripsAction], start: WorldState,
		goal: PackedStringArray, budget: int = DEFAULT_BUDGET) -> PlanResult:
	if start.holds_all(goal):
		return PlanResult.new([] as Array[StripsAction], true, 0, false)

	var frontier: Array[Step] = [Step.new(start, [] as Array[StripsAction])]
	var seen: Dictionary = {start.key(): true}
	var visited: int = 0

	while not frontier.is_empty():
		if visited >= budget:
			return PlanResult.ran_out(visited)
		# The front of the queue: the oldest world, which is what makes the
		# first plan found the shortest one. Take it off the back instead and
		# the planner still answers, with a plan that wanders.
		var step: Step = frontier.pop_front()
		visited += 1
		var finished: Array[StripsAction] = _expand(actions, step, goal, seen, frontier)
		if not finished.is_empty():
			return PlanResult.new(finished, true, visited, false)

	return PlanResult.impossible(visited)


# Every action that may run in `step`'s world, each queued with the plan that
# reaches it. Returns the finished plan when one of them satisfies the goal,
# and an empty array when none does.
#
# The goal is tested on each world as it is *generated* rather than when it
# comes off the frontier. Both are correct and both return the same shortest
# plan; testing here saves a whole level of expansion, which on a branching
# domain is most of the work.
static func _expand(actions: Array[StripsAction], step: Step, goal: PackedStringArray,
		seen: Dictionary, frontier: Array[Step]) -> Array[StripsAction]:
	for action: StripsAction in actions:
		if not action.is_applicable(step.world):
			continue
		var next: WorldState = action.apply(step.world)
		# A world already reached is not reached again. Without this the
		# planner walks in circles on any domain where an action can be undone,
		# which is most of them, and spends its whole budget doing it.
		if seen.has(next.key()):
			continue
		seen[next.key()] = true
		var longer: Array[StripsAction] = step.taken.duplicate()
		longer.append(action)
		if next.holds_all(goal):
			return longer
		frontier.append(Step.new(next, longer))
	return [] as Array[StripsAction]
