## One thing the AI can do: what must be true first, and what is true after.
##
## The three lists *are* STRIPS. `preconditions` is what the world must already
## satisfy, `deletes` is what stops being true, `adds` is what starts being
## true. A planner needs to know nothing else about a game to reason about it,
## which is the whole trick and the reason this type has no board in it.
##
## When not to use it: an effect that depends on the state it runs in -- "deal
## damage equal to half the target's health". That is a conditional effect, and
## STRIPS has none; a domain faking it with one action per case grows until
## nobody reads it.
class_name StripsAction
extends RefCounted

## What it is called, in the domain and in a printed plan.
var name: String

var preconditions: PackedStringArray
var deletes: PackedStringArray
var adds: PackedStringArray


func _init(action_name: String, needs: PackedStringArray,
		stops_being_true: PackedStringArray,
		starts_being_true: PackedStringArray) -> void:
	name = action_name
	preconditions = needs
	deletes = stops_being_true
	adds = starts_being_true


## True when this action may run in this state.
func is_applicable(state: WorldState) -> bool:
	return state.holds_all(preconditions)


## The state this action leaves behind.
##
## It does not check `is_applicable` first, and that is a contract rather than
## an oversight: the planner asks before every call, and a version that quietly
## returned the state unchanged would turn a caller's bug into a plan that
## cannot be executed. What holds the contract up is `planner_properties.gd`,
## which replays every plan the planner returns and fails if any step was not
## applicable at the moment it ran.
func apply(state: WorldState) -> WorldState:
	return state.after(deletes, adds)
