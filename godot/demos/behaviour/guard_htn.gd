## The guard as an HTN: break "guard" down by the first method whose
## conditions hold, and carry the plan out step by step.
##
## Unlike GOAP it keeps its plan between turns. It plans again only when the
## plan is done, when its next step can no longer run, or when a method ranked
## above the one it chose becomes possible -- an alert outranks an
## investigation. So a guard that set out to go and look carries on down that
## method even as its suspicion fades, until it has looked: Humphreys' HTN
## agents do the same, replanning on a better method or a plan that failed.
##
## When not to use it: see `HtnPlanner`.
class_name GuardHtn
extends GuardBrain

## The plan being carried out, for the screen.
var plan: BehaviourPlan = BehaviourPlan.new()
## Why it last planned.
var why_planned: String = ""

var _planner := HtnPlanner.new()
var _domain: HtnDomain = GuardActions.htn()
# How far through `plan.steps` the guard is.
var _next: int = 0


## "HTN".
func brain_name() -> String:
	return "HTN"


## The plan's next step, planning again first if it should.
func decide(facts: Dictionary) -> String:
	_skip_steps_done(facts)
	var why: String = _why_plan_again(facts)
	if why != "":
		plan = _planner.plan(_domain, facts, "guard")
		_next = 0
		why_planned = why
	if _next >= plan.steps.size():
		return WALK_ROUND
	return plan.steps[_next]


## The method chosen, the plan, the step it is on, and why it last planned.
func thinking() -> Dictionary:
	return {"method": plan.methods.duplicate(), "plan": plan.steps.duplicate(), "step": _next,
		"visited": plan.visited, "planned": why_planned}


# Move past the steps whose effects the world already shows done.
func _skip_steps_done(facts: Dictionary) -> void:
	while _next < plan.steps.size() and HtnDomain.holds(_domain.primitives[plan.steps[_next]][1], facts) \
			and plan.steps[_next] != WALK_ROUND:
		_next += 1


# Why to plan again this turn, or "" to carry on.
func _why_plan_again(facts: Dictionary) -> String:
	if plan.steps.is_empty() or _next >= plan.steps.size():
		return "the plan was done"
	if not HtnDomain.holds(_domain.primitives[plan.steps[_next]][0], facts):
		return "%s could no longer run" % plan.steps[_next]
	var better: String = _better_method(facts)
	if better != "":
		return "%s became possible" % better
	return ""


# A method ranked above the one being carried out whose conditions now hold.
func _better_method(facts: Dictionary) -> String:
	var current: String = plan.methods[0].trim_prefix("guard: ") if not plan.methods.is_empty() else ""
	for method: Array in _domain.compounds["guard"]:
		if method[0] == current:
			return ""
		if HtnDomain.holds(method[1], facts):
			return method[0]
	return ""
