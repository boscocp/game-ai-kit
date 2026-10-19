## A finite state machine: one state at a time, and arrows between states
## that fire when their condition holds.
##
## The oldest way to write a guard, and still the clearest when the states
## are few: you can draw it, and the drawing is the whole program. Each
## arrow is a condition over the facts the agent knows (`facts`, a
## Dictionary the game fills in) and a sentence saying why it fires, so the
## demo can light the arrow that was taken. Arrows out of a state are tried
## in the order they were added; the first that holds is taken, and only
## one per update -- a machine that chained several in one update would hide
## the states it passed through.
##
## What it is bad at, and why the other three exist: every state has to know
## every way out of itself, so a new state means touching the old ones, and
## the same behaviour in two states is written twice.
##
## Complexity: one update tries the arrows out of the current state, O(arrows).
##
## When not to use it: more than a handful of states, or behaviour shared
## between states. A behaviour tree composes; a planner finds the order.
class_name StateMachine
extends RefCounted

## The state it is in.
var current: String
## The arrow the last update took, as "from -> to: why"; "" when it stayed.
var last_change: String = ""

# From-state -> [[to-state, condition Callable(facts) -> bool, why]].
var _arrows: Dictionary[String, Array] = {}


## A machine that starts in `first`.
func _init(first: String) -> void:
	current = first


## An arrow from `from` to `to`, taken when `condition` (given the facts)
## returns true; `why` is what the screen says when it is.
func add_arrow(from: String, to: String, condition: Callable, why: String) -> void:
	if not _arrows.has(from):
		_arrows[from] = []
	_arrows[from].append([to, condition, why])


## Take the first arrow out of the current state whose condition holds on
## `facts`, if any, and return the state it is in afterwards.
func update(facts: Dictionary) -> String:
	last_change = ""
	for arrow: Array in _arrows.get(current, []):
		if (arrow[1] as Callable).call(facts):
			last_change = "%s -> %s: %s" % [current, arrow[0], arrow[2]]
			current = arrow[0]
			break
	return current


## Every state any arrow starts or ends at, in the order first met: what a
## drawing of the machine needs.
func states() -> Array[String]:
	var ends: Array[String] = []
	if _arrows.is_empty():
		ends.append(current)
	for from: String in _arrows:
		ends.append(from)
		ends.append_array(_arrows[from].map(func(arrow: Array) -> String: return arrow[0]))
	var found: Array[String] = []
	for state: String in ends:
		if state not in found:
			found.append(state)
	return found
