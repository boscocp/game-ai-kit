## The tasks an HTN planner knows: primitive ones it can do, and compound
## ones it knows how to break down.
##
## A **primitive** task is a GOAP action without the cost: what must hold,
## what it makes hold. A **compound** task has methods, tried in the order the
## designer wrote them; a method holds when its conditions do, and says which
## tasks the compound one becomes. That order is the designer's judgement
## written down -- "if you can see them, chase; if you know where they were,
## go and look; otherwise walk your round" -- and it is what an HTN has that
## GOAP does not: the planner never invents an order nobody wrote.
##
## When not to use it: a domain whose designer cannot say how its tasks break
## down. That is what search is for, and GOAP or STRIPS finds orders an HTN
## would need a method for.
class_name HtnDomain
extends RefCounted

## Primitive task name -> [preconditions, effects], each fact -> value.
var primitives: Dictionary[String, Array] = {}
## Compound task name -> its methods in order, each
## [method name, conditions (fact -> value), subtasks (Array[String])].
var compounds: Dictionary[String, Array] = {}


## A task the planner can do, when `needs` holds, leaving `makes` true.
func add_primitive(task: String, needs: Dictionary, makes: Dictionary) -> void:
	primitives[task] = [needs, makes]


## One more way to carry out `task`, tried after the ones added before it:
## when `conditions` hold, `task` becomes `subtasks`, in order.
func add_method(task: String, method: String, conditions: Dictionary, subtasks: Array[String]) -> void:
	if not compounds.has(task):
		compounds[task] = []
	compounds[task].append([method, conditions, subtasks])


## True when every fact of `needs` has its value in `world`.
static func holds(needs: Dictionary, world: Dictionary) -> bool:
	for fact: String in needs:
		if world.get(fact, false) != needs[fact]:
			return false
	return true
