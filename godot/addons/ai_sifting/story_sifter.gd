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
## to find, each event of the record the `before` pairs leave it is tried
## in turn, fixed fields first, before anything is copied: not one already
## used, with every field the pattern names, every variable either bound
## here or already holding that value, and every `before` pair whose two
## ends are now known in order. When all are found, each `unless` is looked
## for, and one found drops the match. So the matches come in the order of
## their events' places, the first event's first.
##
## An `unless` is also looked for early, as soon as its bounds are found
## and its variables bound: when more events lie in its window than the
## finds still to come could take, one of them stays there whatever is
## found next, and the partial match is dropped at once. "The third time"
## (`unless ... before: first`) then stops at the third candidate for
## `first` instead of trying every triple.
##
## And when an `unless` that ends at the event being found rules it out,
## every later event would only widen the window: the search for that event
## stops there (`closes_later`).
##
## Complexity: up to n^k tries for k events to find in a record of n, and
## each `unless` reads its window once per partial match it is ready for.
## What keeps a real pattern far below that is the early `unless`, the stop
## it allows, and `before` narrowing where the next event may be. Measured
## on the pinned engine (review 189), the valley's six patterns and the
## events derived for them, over a bridge pulled down and repaired on
## alternate days: 5 ms at 30 days (59 events), 11 ms at 60, 26 ms at 120
## (239 events), 76 ms at 240 -- where every `unless` checked only at the
## end took 2.8 s at 120 days. Still more than linear: a join such as "the
## deed behind this night" reads every earlier deed once per night. Sift
## when the record changes, not every frame.
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
	var span: Array[int] = _span(pattern.get("before", []), clause["as"], found, events.size())
	var taken: Array = found.values()
	for index: int in range(span[0], span[1]):
		if index in taken:
			continue
		var binds: Variant = bindings_if_matches(events[index], clause["where"], bound)
		if binds == null:
			continue
		found[clause["as"]] = index
		var against: Dictionary = _ruled_out(events, pattern, found, binds)
		if against.is_empty() and _in_order(pattern.get("before", []), found):
			_extend(events, pattern, found, binds, matches)
		found.erase(clause["as"])
		if not against.is_empty() and closes_later(clauses, against, found.size()):
			break


## The bindings once `event` is matched against `where`, given those
## already `bound`; or null when it does not match. Every field `where`
## names must be in the event: a fixed value the same, a variable bound to
## the same value or not bound yet. `bound` is not changed.
static func bindings_if_matches(event: Variant, where: Dictionary, bound: Dictionary) -> Variant:
	if not (event is Dictionary and _known_fields_match(event, where, bound)):
		return null
	var binds: Dictionary = bound.duplicate()
	for field: Variant in where:
		if not (event as Dictionary).has(field):
			return null
		if not SiftPattern.same(event[field], _wanted(where[field], event[field], binds)):
			return null
	return binds


# Whether `event` has every field `where` names, each value already known
# -- fixed, or a variable already bound -- the same: the cheap half of a
# match, read before anything is copied. Most events of a record fail
# here, on their kind, their verb or a day a cause names.
static func _known_fields_match(event: Dictionary, where: Dictionary, bound: Dictionary) -> bool:
	for field: Variant in where:
		if not event.has(field):
			return false
		var wanted: Variant = where[field]
		if SiftPattern.is_variable(wanted):
			wanted = bound.get(SiftPattern.variable_name(wanted), event[field])
		if not SiftPattern.same(event[field], wanted):
			return false
	return true


# The places the next event, `name`, may take: after every event `before`
# puts ahead of it that is found, ahead of every found one it must precede.
# Only a narrowing: `_in_order` still checks every pair.
static func _span(order: Array, name: String, found: Dictionary, size: int) -> Array[int]:
	var span: Array[int] = [0, size]
	for pair: Array in order:
		if pair[1] == name and found.has(pair[0]):
			span[0] = maxi(span[0], int(found[pair[0]]) + 1)
		elif pair[0] == name and found.has(pair[1]):
			span[1] = mini(span[1], int(found[pair[1]]))
	return span


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
		if _count_between(events, clause, found, bound, 1) > 0:
			return true
	return false


# The `unless` that became ready with the event just found and already
# rules this partial match out -- more events in its window than the finds
# still to come could take -- or {} when none does. Exact, never a guess: a
# window it cannot yet rule on is left to `_absent_found` at the end.
func _ruled_out(events: Array, pattern: Dictionary, found: Dictionary, bound: Dictionary) -> Dictionary:
	var finds: Array = pattern["find"]
	var left: int = finds.size() - found.size()
	for clause: Dictionary in pattern.get("unless", []):
		if ready_at(finds, clause) == found.size() - 1 and _count_between(events, clause, found, bound, left + 1) > left:
			return clause
	return {}


## Whether the `unless` `clause`, having ruled out the find at `place`,
## rules out every later event for it too: its window ends at that find
## and reads nothing the find binds, so a later event only widens a window
## already too full. The search stops there -- "the third time" looks no
## further than the next same deed.
static func closes_later(finds: Array, clause: Dictionary, place: int) -> bool:
	if clause.get("before") != finds[place]["as"]:
		return false
	for value: Variant in (clause["where"] as Dictionary).values():
		if SiftPattern.is_variable(value) and _first_use(finds, value) >= place:
			return false
	return true


## The place among `finds` after which the `unless` `clause` can be looked
## for: its bounds found, and every variable a find binds already bound. A
## variable no find binds matches anything, so it waits for nobody.
static func ready_at(finds: Array, clause: Dictionary) -> int:
	var ready: int = 0
	for place: int in range(finds.size()):
		if finds[place]["as"] in [clause.get("after"), clause.get("before")]:
			ready = place
	for value: Variant in (clause["where"] as Dictionary).values():
		if SiftPattern.is_variable(value):
			ready = maxi(ready, _first_use(finds, value))
	return ready


# The place of the first find whose `where` uses `variable`, or -1.
static func _first_use(finds: Array, variable: String) -> int:
	for place: int in range(finds.size()):
		if variable in (finds[place]["where"] as Dictionary).values():
			return place
	return -1


# How many events that must not be there, `clause`, lie between its bounds
# and are not among the events found -- counted up to `enough`, no further.
static func _count_between(events: Array, clause: Dictionary, found: Dictionary, bound: Dictionary,
		enough: int) -> int:
	var first: int = int(found[clause["after"]]) + 1 if clause.has("after") else 0
	var last: int = int(found[clause["before"]]) if clause.has("before") else events.size()
	var counted: int = 0
	var taken: Array = found.values()
	for index: int in range(first, last):
		if not index in taken and bindings_if_matches(events[index], clause["where"], bound) != null:
			counted += 1
		if counted >= enough:
			return counted
	return counted
