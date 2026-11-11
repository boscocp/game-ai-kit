## What is true right now, as a set of predicates the planner can test.
##
## They are plain strings -- `node_held`, `unit_trained` -- with no variables
## and no objects in them. A lifted planner that reasons about `(holds ?faction
## ?node)` is a different and much larger lesson; this one plans over a domain
## small enough to read in one sitting.
##
## Every state is immutable: `after` hands back a new one. That is what lets a
## planner hold a few thousand of them at once without any of them changing
## under it, and it is the same bargain a turn-based board makes when every
## move hands back a new board.
##
## When not to use it: a world with numbers in it -- ammunition, health,
## distance. STRIPS has no arithmetic, and faking it with `has_3_ore`,
## `has_4_ore` is how a domain stops being readable.
class_name WorldState
extends RefCounted

# The set, as a dictionary whose values are all `true`. GDScript has no set
# type and this is what everybody uses instead: membership is a hash lookup,
# where an array would be a linear scan on the one path that runs millions of
# times.
var _facts: Dictionary[String, bool]


func _init(predicates: PackedStringArray = PackedStringArray()) -> void:
	_facts = {}
	for predicate: String in predicates:
		_facts[predicate] = true


## True when this predicate is one of the things true in this state.
##
## A predicate nobody has made true is simply absent: there is no third answer
## between true and false, and that closed-world assumption is why a STRIPS
## domain never has to list everything that is *not* the case.
func holds(predicate: String) -> bool:
	return _facts.has(predicate)


## True when every one of these holds. An empty list holds in every state,
## which is the right answer and also the one a goal of `[]` depends on.
func holds_all(predicates: PackedStringArray) -> bool:
	for predicate: String in predicates:
		if not _facts.has(predicate):
			return false
	return true


## This state with `removed` taken out and `added` put in, as a **new** state.
##
## Deletes first, then adds, which is the STRIPS convention and is not
## cosmetic. An action naming the same predicate in both lists is how a domain
## writes "this is still true afterwards" when it has to delete a precondition,
## and in the other order that predicate would quietly vanish.
func after(removed: PackedStringArray, added: PackedStringArray) -> WorldState:
	var next: WorldState = new()
	next._facts = _facts.duplicate()
	for predicate: String in removed:
		next._facts.erase(predicate)
	for predicate: String in added:
		next._facts[predicate] = true
	return next


## Every predicate that holds, sorted, so two states built in different orders
## read the same.
func predicates() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray(_facts.keys())
	found.sort()
	return found


## This state as one string, so two states that hold the same things are the
## same key.
##
## The planner cannot work without it. Two different routes routinely arrive at
## the same world, and a frontier that cannot see they are one state will plan
## in a circle until it hits its budget -- which is a planner that looks slow
## rather than one that looks broken.
func key() -> String:
	return "|".join(predicates())
