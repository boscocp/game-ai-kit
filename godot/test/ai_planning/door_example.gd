# The minimal example on docs/techniques/ai_planning.md, run by
# door_example_test.gd. A character of your own that is asked for a goal
# -- the door open -- and finds for itself the steps that get there.
extends Node

## What it can do: what each needs, what stops being true, what starts.
## The planner knows nothing else about your game.
var actions: Array[StripsAction] = [
	StripsAction.new("walk to the table", ["at_door"], ["at_door"], ["at_table"]),
	StripsAction.new("walk to the door", ["at_table"], ["at_table"], ["at_door"]),
	StripsAction.new("take the key", ["at_table", "key_on_table"], ["key_on_table"], ["has_key"]),
	StripsAction.new("unlock the door", ["at_door", "has_key"], [], ["door_open"]),
]


## The steps from what is true now, `facts`, to `goal`, by name. Empty when
## the goal already holds, or when there is no way -- `solved` on the
## `PlanResult` from `plan_for` tells those apart.
func steps(facts: PackedStringArray, goal: PackedStringArray) -> PackedStringArray:
	return plan_for(facts, goal).action_names()


## The whole answer: the steps, whether they reach the goal, and how many
## worlds the planner looked at to find them.
func plan_for(facts: PackedStringArray, goal: PackedStringArray) -> PlanResult:
	return HeuristicPlanner.new().plan(actions, WorldState.new(facts), goal, HeuristicPlanner.Guide.H_MAX)
