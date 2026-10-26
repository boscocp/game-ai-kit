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
# The same reason as a key and the name it is about, for the panel.
var _why_key: String = ""
var _why_name: String = ""

var _planner := HtnPlanner.new()
var _domain: HtnDomain = GuardActions.htn()
# How far through `plan.steps` the guard is.
var _next: int = 0


## The name the screen gives this way of deciding.
func brain_name() -> String:
	return "HTN"


## The plan's next step, planning again first if it should.
func decide(facts: Dictionary) -> String:
	_skip_steps_done(facts)
	var why: Array[String] = _why_plan_again(facts)
	if not why.is_empty():
		plan = _planner.plan(_domain, facts, "guard")  # shown through tr()
		_next = 0
		_why_key = why[0]
		_why_name = why[1]
		why_planned = _why_key.format({name = _why_name})
	if _next >= plan.steps.size():
		return WALK_ROUND
	return plan.steps[_next]


## The method chosen, the plan, the step it is on, and why it last planned.
func thinking() -> Dictionary:
	return {"method": plan.methods.duplicate(), "plan": plan.steps.duplicate(), "step": _next,
		"visited": plan.visited, "planned": why_planned, "planned_words": _why_in_words()}


# `why_planned` in the language spoken now: the sentence and the name in it
# translated apart, since the name is a step or a method and the sentence is
# about it.
func _why_in_words() -> String:
	return TranslationServer.translate(_why_key).format({name = BrainPanel.words(_why_name)})


# Move past the steps whose effects the world already shows done.
func _skip_steps_done(facts: Dictionary) -> void:
	while _next < plan.steps.size() and HtnDomain.holds(_domain.primitives[plan.steps[_next]][1], facts) \
			and plan.steps[_next] != WALK_ROUND:
		_next += 1


# Why to plan again this turn, as [the reason's key, the name it is about],
# or [] to carry on.
func _why_plan_again(facts: Dictionary) -> Array[String]:
	if plan.steps.is_empty() or _next >= plan.steps.size():
		return ["the plan was done", ""]  # shown through tr()
	if not HtnDomain.holds(_domain.primitives[plan.steps[_next]][0], facts):
		return ["{name} could no longer run", plan.steps[_next]]  # shown through tr()
	var better: String = _better_method(facts)
	if better != "":
		return ["{name} became possible", better]  # shown through tr()
	return []


# A method ranked above the one being carried out whose conditions now hold.
func _better_method(facts: Dictionary) -> String:
	var current: String = plan.methods[0].trim_prefix("guard: ") if not plan.methods.is_empty() else ""
	for method: Array in _domain.compounds["guard"]:
		if method[0] == current:
			return ""
		if HtnDomain.holds(method[1], facts):
			return method[0]
	return ""
