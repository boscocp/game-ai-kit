## The RTS side whose economy is topped by a plan: it chooses a goal from
## what it has seen, plans a build order to it, and feeds the plan's next
## step to the priority queue.
##
## The top of ADR 0010's three layers, and the only one that plans. Every
## decision it asks three questions. **What to aim at** (`goal`): workers
## always, then the counter to the fighter the enemy has shown most -- a
## mortar for shields, a shield for runners, a runner for mortars -- and
## the tower when nothing has been seen for a while, so it can find out;
## the expansion once the match is old enough. **How to get there**:
## `BuildOrder` plans the chain, by STRIPS or by HTN. **When**:
## `BuildSchedule` times the plan by jumping from one affordable moment to
## the next, which is what the screen shows beside each step.
##
## It replans on a cadence and when the plan breaks, never every frame
## (ADR 0010, point 5) -- the world does not wait while it thinks, and that
## is the difference from T11's board, which did. The cadence is
## `REPLAN_SECONDS`; a plan breaks when its next step cannot run or the goal
## has changed. Each call is timed against `FrameBudget`'s strategy share,
## and the plans here are a handful of steps, so none comes near it.
##
## When not to use it: a game whose openings are few and known. A fixed
## build order written by a person is cheaper, and a player reads it as
## well.
class_name RtsCommander
extends RtsSide

## Seconds between two plans when nothing breaks the one in hand.
const REPLAN_SECONDS: float = 10.0
## With no enemy fighter seen this long, the commander builds a tower to look.
const SCOUT_AFTER_SECONDS: float = 120.0
## The match time after which the expansion joins the goal.
const EXPAND_AFTER_SECONDS: float = 240.0
## The fighter that beats each kind: the counter to what was seen.
const COUNTER: Dictionary = {
	RtsKinds.RUNNER: RtsKinds.SHIELD, RtsKinds.SHIELD: RtsKinds.MORTAR, RtsKinds.MORTAR: RtsKinds.RUNNER,
}
const READY_FACT: Dictionary = {
	RtsKinds.RUNNER: "runners_ready", RtsKinds.SHIELD: "shields_ready", RtsKinds.MORTAR: "mortars_ready",
}

var planner: BuildOrder.Planner
## The plan in hand, its goal, and its timing: what the screen draws.
var steps := PackedStringArray()
var goal_facts := PackedStringArray()
var schedule: Array[Dictionary] = []
## Every planning call: {tick, microseconds, visited, steps, solved}.
var plans: Array[Dictionary] = []

var _planned_at: int = -1
# What the plan put in the queue last decision.
var _wished: Array[String] = []


## A commander for `side_played` at `side_level`, planning with
## `use_planner`, its dice drawn from `seed_value`.
func _init(side_played: int, side_level: Difficulty, seed_value: int,
		use_planner: BuildOrder.Planner = BuildOrder.Planner.STRIPS) -> void:
	super(side_played, side_level, seed_value)
	planner = use_planner


func _fill_queue(view: RtsSnapshot) -> void:
	_reflexes(view)
	var held: PackedStringArray = BuildOrder.facts(view)
	var wanted: PackedStringArray = goal(view)
	steps = _still_to_do(steps, held)
	if _plan_is_stale(view, held, wanted):
		_plan(view, held, wanted)
	schedule = BuildSchedule.of(steps, view)
	_follow(held)


## What to aim at now, from what this side has seen and how long the match
## has run.
func goal(view: RtsSnapshot) -> PackedStringArray:
	var wanted := PackedStringArray(["workers_saturated"])
	var seen: Dictionary = belief.seen_fighters()
	var most: String = ""
	for kind: String in seen:
		if most == "" or seen[kind] > seen[most]:
			most = kind
	var seconds: float = float(view.tick) / RtsWorld.TICKS_PER_SECOND
	if most == "":
		wanted.append("runners_ready")
		if seconds >= SCOUT_AFTER_SECONDS:
			wanted.append("tower_up")
	else:
		wanted.append(READY_FACT[COUNTER[most]])
	if seconds >= EXPAND_AFTER_SECONDS:
		wanted.append("expansion_up")
	return wanted


## The plan, its timing and the economy under it, for the screen.
func overlay(view: RtsSnapshot) -> Dictionary:
	var shown: Dictionary = super(view)
	shown["goal"] = goal_facts
	shown["plan"] = schedule.duplicate(true)
	shown["planner"] = "STRIPS" if planner == BuildOrder.Planner.STRIPS else "HTN"
	return shown


# Leading steps whose effects already hold are done; drop them.
static func _still_to_do(plan: PackedStringArray, held: PackedStringArray) -> PackedStringArray:
	var left := PackedStringArray(plan)
	while not left.is_empty() and _done(left[0], held):
		left.remove_at(0)
	return left


static func _done(step: String, held: PackedStringArray) -> bool:
	var action: StripsAction = BuildOrder.action_named(step)
	return action == null or WorldState.new(held).holds_all(action.adds)


# Replan on the cadence, when the goal changed, when the plan ran out with
# the goal still unmet, or when its next step cannot run from here.
func _plan_is_stale(view: RtsSnapshot, held: PackedStringArray, wanted: PackedStringArray) -> bool:
	if _planned_at < 0 or wanted != goal_facts:
		return true
	if view.tick - _planned_at >= REPLAN_SECONDS * RtsWorld.TICKS_PER_SECOND:
		return true
	if steps.is_empty():
		return not WorldState.new(held).holds_all(wanted)
	var next: StripsAction = BuildOrder.action_named(steps[0])
	return next == null or not WorldState.new(held).holds_all(next.preconditions)


func _plan(view: RtsSnapshot, held: PackedStringArray, wanted: PackedStringArray) -> void:
	var started: int = Time.get_ticks_usec()
	var found: Dictionary = BuildOrder.plan(held, wanted, planner, level.plan_horizon)
	var spent: int = Time.get_ticks_usec() - started
	steps = found["steps"]
	goal_facts = wanted
	_planned_at = view.tick
	plans.append({"tick": view.tick, "microseconds": spent, "visited": found["visited"],
		"steps": steps.size(), "solved": found["solved"]})


# The plan's next step becomes the queue's top wish; with the plan done,
# the counter keeps coming at a lower priority, so the army is replaced.
# Only what the plan wished last time is taken back first: the reflexes'
# wishes are theirs.
func _follow(held: PackedStringArray) -> void:
	for kind: String in _wished:
		queue.forget(kind)
	_wished.clear()
	if steps.is_empty():
		_keep_the_army_coming(held)
		return
	var what: String = BuildOrder.BUYS.get(steps[0], "")
	if steps[0] == "mine_magma":
		queue.magma_wanted = true
	elif what != "":
		_wish(what, 80, "plan, step 1 of %d: %s" % [steps.size(), steps[0]])


# Every fighter the goal asked for and has, kept coming to replace losses.
func _keep_the_army_coming(held: PackedStringArray) -> void:
	for kind: String in READY_FACT:
		var fact: String = READY_FACT[kind]
		if fact in goal_facts and fact in held:
			_wish(kind, 30, "goal met: more %ss" % kind)


func _wish(what: String, priority: int, why: String) -> void:
	queue.wish(what, priority, why)
	_wished.append(what)
