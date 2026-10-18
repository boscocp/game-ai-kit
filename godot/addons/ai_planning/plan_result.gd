## What the planner found, and how hard it had to look for it.
##
## The steps alone cannot be read. An empty plan means "the goal already held"
## and it also means "there is no plan", and those are opposite answers -- the
## same trap the four searches in `ai_search` hit with an empty path, where a
## `reached` flag had to be added to tell them apart. It is not rediscovered
## here.
##
## When not to use it: a plan being executed. This is the answer to one
## question asked once; a plan that a unit is partway through is a different
## object with an index in it.
class_name PlanResult
extends RefCounted

## The actions to take, in order.
var steps: Array[StripsAction]

## True when the goal holds once `steps` have run -- including the case where
## it already held and `steps` is empty.
var solved: bool

## How many states came off the frontier before the planner stopped.
##
## Carried because it is the only honest measure of what a plan cost. The
## game's domain -- seven actions, eight predicates -- needs 14 states for its
## eight-step plan, which is small; the point is that the number is reported at
## all, because it is what grows when a domain does.
var visited: int

## True when the planner stopped at its budget rather than running out of
## states to try.
##
## Then `solved == false` means "I did not find one", never "there is none".
## Reporting those as the same answer is how a planner comes to be trusted for
## a claim it never made.
var gave_up: bool

## True when the planner stopped at its budget and `steps` are the start of a
## plan rather than a whole one: the way to the world it had searched that
## looked nearest the goal. `solved` is false and `gave_up` true.
##
## Only a search with a guess about distance can say which world looked
## nearest, so only `HeuristicPlanner`'s A* returns one. The game acts on its
## first step and asks again (ADR 0010), because a partial plan is a direction,
## not a promise -- the world it ends at may be a dead end the budget hid.
var partial: bool = false


func _init(found: Array[StripsAction], goal_reached: bool, states_visited: int,
		stopped_early: bool) -> void:
	steps = found
	solved = goal_reached
	visited = states_visited
	gave_up = stopped_early


## The plan as names, in order: what to print, and what a test asserts on.
func action_names() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for action: StripsAction in steps:
		names.append(action.name)
	return names


## There is no plan: the planner tried every state it could reach and the goal
## was in none of them.
static func impossible(states_visited: int) -> PlanResult:
	return PlanResult.new([] as Array[StripsAction], false, states_visited, false)


## The planner stopped at its budget. A weaker answer than `impossible`, and
## deliberately a different one.
static func ran_out(states_visited: int) -> PlanResult:
	return PlanResult.new([] as Array[StripsAction], false, states_visited, true)


## The planner stopped at its budget, and `so_far` is the way to the world
## that looked nearest the goal. An empty `so_far` -- nothing looked nearer
## than the start -- is a plain `ran_out`, not a partial plan of no steps.
static func partial_plan(so_far: Array[StripsAction], states_visited: int) -> PlanResult:
	var result := PlanResult.new(so_far, false, states_visited, true)
	result.partial = not so_far.is_empty()
	return result
