## The HTN team (T25), one of the board's controllers: for each walker, break
## "walker" down by the first method whose conditions hold, and carry the plan
## out step by step over its turns.
##
##     walker
##       save itself         in danger, wounded       -> fall back
##       defend home         home threatened          -> defend
##       press the siege     at their workshop        -> siege
##       hunt, then march    prey in reach            -> hunt, siege
##       hold a point        a point free             -> take point
##       march               (always)                 -> siege
##
## Unlike GOAP it keeps each walker's plan between turns, as T15's guard did.
## It plans again only when the plan is done, when its next step can no
## longer run, or when a method ranked above the one it chose becomes
## possible -- Humphreys' rule. So a defender stays one until home is clear
## (defend's effect), not merely until home stops being threatened, and a
## walker that has hunted marches on rather than looking for the next fight
## -- the plan said "then march", and only a better method interrupts it.
##
## When not to use it: see `HtnPlanner`.
class_name HtnTeam
extends TechniqueTeam

## The top task every walker breaks down.
const TOP: String = "walker"  # not shown

var _planner := HtnPlanner.new()
var _domain: HtnDomain = domain()
# Walker id -> [plan, index of its next step, why it last planned].
var _plans: Dictionary[int, Array] = {}
var _last_turn: int = -1
var _replans: int = 0


## The name the league table and the screen give it.
func controller_name() -> String:
	return "HTN"  # shown through tr()


## One line for the screen: what kind of thinking this is.
func describe() -> String:
	return tr("an HTN per walker: a plan by ranked methods, kept over turns until done, broken or bettered; builds by the rules")


## The walker's primitive tasks and the one compound task, with its methods
## in the order a designer would rank them. A step's effect is what the board
## shows when the step is done; siege and take point are never done, only
## interrupted, so their effects name facts no board has.
static func domain() -> HtnDomain:
	var made := HtnDomain.new()
	made.add_primitive(FALL_BACK, {"in_danger": true}, {"in_danger": false})
	made.add_primitive(DEFEND, {}, {"home_clear": true})
	made.add_primitive(HUNT, {"prey_in_reach": true}, {"prey_in_reach": false})
	made.add_primitive(SIEGE, {}, {"workshop_fallen": true})
	made.add_primitive(TAKE_POINT, {"point_free": true}, {"point_kept": true})
	made.add_method(TOP, "save itself", {"in_danger": true, "wounded": true}, [FALL_BACK] as Array[String])  # shown through tr()
	made.add_method(TOP, "defend home", {"home_threatened": true}, [DEFEND] as Array[String])  # shown through tr()
	made.add_method(TOP, "press the siege", {"at_their_workshop": true}, [SIEGE] as Array[String])  # shown through tr()
	made.add_method(TOP, "hunt, then march", {"prey_in_reach": true}, [HUNT, SIEGE] as Array[String])  # shown through tr()
	made.add_method(TOP, "hold a point", {"point_free": true}, [TAKE_POINT] as Array[String])  # shown through tr()
	made.add_method(TOP, "march", {}, [SIEGE] as Array[String])  # shown through tr()
	return made


## A new turn; a turn no later than the last means a new game, and every
## plan is forgotten.
func begin_turn(state: BoardState) -> void:
	if state.turn_number <= _last_turn:
		_plans.clear()
	_last_turn = state.turn_number
	super.begin_turn(state)


## The plan's next step, planning again first if it should.
func decide(unit: Unit, known: TeamFacts) -> String:
	var held: Array = _plans.get(unit.id, [BehaviourPlan.new(), 0, ""])
	var plan: BehaviourPlan = held[0]
	var next: int = _skip_steps_done(plan, held[1], known.facts)
	var why: String = _why_plan_again(plan, next, known.facts)
	if why != "":
		plan = _planner.plan(_domain, known.facts, TOP)
		_work += plan.visited
		_replans += 1
		next = 0
		held[2] = why
	_plans[unit.id] = [plan, next, held[2]]
	return plan.steps[next] if next < plan.steps.size() else SIEGE


## The walker's method, the step it is on, and why it last planned.
func thinking(unit_id: int) -> String:
	if not _plans.has(unit_id):
		return tr("no plan yet")
	var held: Array = _plans[unit_id]
	var plan: BehaviourPlan = held[0]
	var method: String = tr("none")
	if not plan.methods.is_empty():
		method = tr(plan.methods[0].trim_prefix(TOP + ": "))
	var steps: Array[String] = []
	for step: String in plan.steps:
		steps.append(tr(step))
	return tr("method {method}, step {step} of {steps} ({deeds}), planned {why}").format({
		method = method, step = held[1] + 1, steps = plan.steps.size(),
		deeds = (" %s " % tr("then")).join(steps), why = held[2]})


## "Tasks": the tasks the decomposition visited.
func work_unit() -> String:
	return "tasks"


## How many times it has planned since it was made.
func replans() -> int:
	return _replans


# Past the steps whose effects the board already shows.
func _skip_steps_done(plan: BehaviourPlan, next: int, facts: Dictionary) -> int:
	while next < plan.steps.size() and HtnDomain.holds(_domain.primitives[plan.steps[next]][1], facts):
		next += 1
	return next


# Why to plan again this turn, or "" to carry on.
func _why_plan_again(plan: BehaviourPlan, next: int, facts: Dictionary) -> String:
	if plan.steps.is_empty():
		return tr("at its first decision")
	if next >= plan.steps.size():
		return tr("because the plan was done")
	if not HtnDomain.holds(_domain.primitives[plan.steps[next]][0], facts):
		return tr("because {deed} could no longer run").format({deed = tr(plan.steps[next])})
	var better: String = _better_method(plan, facts)
	if better == "":
		return ""
	return tr("because {method} became possible").format({method = tr(better)})


# A method ranked above the one being carried out whose conditions now hold.
func _better_method(plan: BehaviourPlan, facts: Dictionary) -> String:
	var current: String = plan.methods[0].trim_prefix(TOP + ": ") if not plan.methods.is_empty() else ""
	for method: Array in _domain.compounds[TOP]:
		if method[0] == current:
			return ""
		if HtnDomain.holds(method[1], facts):
			return method[0]
	return ""
