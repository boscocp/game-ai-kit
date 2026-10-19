## The guard as GOAP: choose the most pressing goal, plan the cheapest way to
## it backwards from the goal, and do the first step -- then plan again next
## turn, from scratch.
##
## Replanning every turn is F.E.A.R.'s habit and the point of the comparison:
## the plan is never trusted past one step, so the guard always answers the
## world as it is now -- and drops a search the moment its goal changes,
## however close it was to finishing.
##
## When not to use it: see `GoapPlanner`.
class_name GuardGoap
extends GuardBrain

## The last plan made, for the screen.
var plan: BehaviourPlan = BehaviourPlan.new()
## The goal it was made for.
var goal: Dictionary = {}

var _planner := GoapPlanner.new()
var _actions: Array[GoapAction] = GuardActions.goap()


## The name the screen gives this way of deciding.
func brain_name() -> String:
	return "GOAP"


## Choose the goal, plan to it, and take the plan's first step.
func decide(facts: Dictionary) -> String:
	goal = GuardActions.goal(facts)
	plan = _planner.plan(_actions, facts, goal)
	return plan.steps[0] if not plan.steps.is_empty() else WALK_ROUND


## The goal, the plan to it, and the worlds the search looked at.
func thinking() -> Dictionary:
	return {"goal": goal.keys(), "plan": plan.steps.duplicate(), "visited": plan.visited}
