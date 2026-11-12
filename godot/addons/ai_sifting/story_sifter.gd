## Which moments of a record are worth telling: story sifting, as in Felt
## [Kreminski, Dickinson & Wardrip-Fruin, "Felt: A Simple Story Sifter",
## ICIDS 2019].
##
## A simulation writes down what happened -- a deed, a fact that changed
## overnight -- and most of it is not a story. A story is a shape among
## the events: the barn burned, and it was rebuilt; the bridge came down
## for the third time. A designer writes that shape as a pattern
## (`SiftPattern`), and the sifter finds every place in the record where
## it fits, with the events that made it fit. What to do with a match --
## a line of a chronicle, a villager's gossip -- is the game's.
##
## The record is an `Array` of `Dictionary` events, in the order they
## happened; an event is identified by its place in that array. The sifter
## names nothing else -- not the game's log class, not its world -- so it
## can be copied alone.
##
## **It only reads.** `sift` takes the record and returns matches; it never
## writes an event, and it holds nothing between calls. The tests hand it
## a record and compare it afterwards with a copy, and a planted sifter
## that marks the events it used fails them.
##
## How: depth first, the pattern's events in its order. For the next event
## to find, each event of the record is tried in turn: not one already
## used, with every field the pattern names, every variable either bound
## here or already holding that value, and every `before` pair whose two
## ends are now known in order. When all are found, each `unless` is looked
## for, and one found drops the match. So the matches come in the order of
## their events' places, the first event's first.
##
## Complexity: up to n^k tries for k events to find in a record of n, and
## each `unless` reads the record once more per match. Small patterns over
## a game's record -- hundreds of events, two to four to find -- are cheap.
##
## When not to use it: over a record that grows while the game runs and is
## asked again every frame -- sifting it whole each time repeats all the
## work; Winnow [Kreminski, Dickinson & Mateas, AIIDE 2021] keeps partial
## matches and extends them as each event arrives. And not to decide
## anything: a match is a story to tell, and the world should not turn on
## which stories a designer happened to write.
class_name StorySifter
extends RefCounted


## Every match of `pattern` in `events`, in the order of the events that
## made it. A match is `{"events": {name: index}, "bindings": {variable:
## value}}`: which event of the record each name found, and what each
## variable was bound to, without its `?`. A pattern with a problem
## (`SiftPattern.problem`) matches nothing.
func sift(events: Array, pattern: Dictionary) -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	if SiftPattern.problem(pattern) != "":
		return matches
	_extend(events, pattern, {}, {}, matches)
	return matches


# Find the pattern's next event, given those found so far (`found`, name
# to index) and the variables they bound; at the end, keep the match
# unless an event that must not be there is.
func _extend(events: Array, pattern: Dictionary, found: Dictionary, bound: Dictionary,
		matches: Array[Dictionary]) -> void:
	var clauses: Array = pattern["find"]
	if found.size() == clauses.size():
		if not _absent_found(events, pattern, found, bound):
			matches.append({"events": found.duplicate(), "bindings": bound.duplicate()})
		return
	var clause: Dictionary = clauses[found.size()]
	for index: int in range(events.size()):
		if index in found.values():
			continue
		var binds: Variant = bindings_if_matches(events[index], clause["where"], bound)
		if binds == null:
			continue
		found[clause["as"]] = index
		if _in_order(pattern.get("before", []), found):
			_extend(events, pattern, found, binds, matches)
		found.erase(clause["as"])


## The bindings once `event` is matched against `where`, given those
## already `bound`; or null when it does not match. Every field `where`
## names must be in the event: a fixed value the same, a variable bound to
## the same value or not bound yet. `bound` is not changed.
static func bindings_if_matches(event: Variant, where: Dictionary, bound: Dictionary) -> Variant:
	if not event is Dictionary:
		return null
	var binds: Dictionary = bound.duplicate()
	for field: Variant in where:
		if not (event as Dictionary).has(field):
			return null
		if not SiftPattern.same(event[field], _wanted(where[field], event[field], binds)):
			return null
	return binds


# The value a field must have: `wanted` itself, or the variable's value --
# bound to `seen` first, in `binds`, when it has none yet.
static func _wanted(wanted: Variant, seen: Variant, binds: Dictionary) -> Variant:
	if not SiftPattern.is_variable(wanted):
		return wanted
	var variable: String = SiftPattern.variable_name(wanted)
	if not binds.has(variable):
		binds[variable] = seen
	return binds[variable]


# Whether every `before` pair whose two events are found is in order.
static func _in_order(order: Array, found: Dictionary) -> bool:
	for pair: Array in order:
		if found.has(pair[0]) and found.has(pair[1]) and int(found[pair[0]]) >= int(found[pair[1]]):
			return false
	return true


# Whether any event that must not be there is, between its bounds, and is
# not one of the events found.
func _absent_found(events: Array, pattern: Dictionary, found: Dictionary, bound: Dictionary) -> bool:
	for clause: Dictionary in pattern.get("unless", []):
		if _found_between(events, clause, found, bound):
			return true
	return false


# Whether one event that must not be there, `clause`, is between its bounds.
static func _found_between(events: Array, clause: Dictionary, found: Dictionary, bound: Dictionary) -> bool:
	var first: int = int(found[clause["after"]]) + 1 if clause.has("after") else 0
	var last: int = int(found[clause["before"]]) if clause.has("before") else events.size()
	for index: int in range(first, last):
		if not index in found.values() and bindings_if_matches(events[index], clause["where"], bound) != null:
			return true
	return false
