## What a planner in this addon found, and how hard it looked.
##
## The same three answers `ai_planning`'s result keeps apart, for the same
## reason: an empty plan can mean "the goal already holds" or "there is no
## plan", and those are opposite answers. Its own type rather than that one,
## because no addon depends on another (invariant 2).
##
## When not to use it: a plan being carried out. This is one question's
## answer; following it is the caller's.
class_name BehaviourPlan
extends RefCounted

## The actions to take, by name, in the order to take them.
var steps: Array[String] = []
## True when the goal holds once `steps` have run.
var solved: bool = false
## Worlds the search took up and looked past -- the counter T11 reports, so
## the planners can be compared on one number.
var visited: int = 0
## True when it stopped at its budget rather than running out of worlds.
var gave_up: bool = false
## For an HTN, the method chosen for each compound task, in order: what the
## guard is carrying out. Empty for GOAP, which has no methods.
var methods: Array[String] = []


## A plan with these steps; `solved` when they reach the goal.
func _init(found: Array[String] = [], reached: bool = false, looked_at: int = 0, stopped: bool = false) -> void:
	steps = found
	solved = reached
	visited = looked_at
	gave_up = stopped
