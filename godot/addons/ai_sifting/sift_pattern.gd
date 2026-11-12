## What a story sifting pattern is, and what makes one unusable: the
## shape `StorySifter` reads, checked before anything reads it.
##
## A pattern is plain data, so a designer can write it in a JSON file
## and the twin in Python (`gameaikit.sifting`) reads the same one:
##
##     {"name": "rebuilt",
##      "find": [{"as": "burned", "where": {"verb": "burn", "place": "?place"}},
##               {"as": "rebuilt", "where": {"verb": "repair", "place": "?place"}}],
##      "before": [["burned", "rebuilt"]],
##      "unless": [{"where": {"verb": "burn", "place": "?place"},
##                  "after": "burned", "before": "rebuilt"}]}
##
## * `find`: the events to find, each named by `as`. An event matches
##   `where` when it has every field `where` names, with that value. A
##   value that starts with `?` is a **variable**: the first event to meet
##   it binds it, and every later use must hold the same value -- this is
##   how two events are joined on the same place.
## * `before`: pairs of names, the first found earlier in the record than
##   the second.
## * `unless`: events that must *not* be there. Each is a `where` -- its
##   variables already bound are the match's, the others match anything --
##   looked for strictly between the events named `after` and `before`,
##   or from the start or to the end when one is left out.
##
## Felt [Kreminski, Dickinson & Wardrip-Fruin 2019] writes the same three
## things as a Datalog query: event clauses, shared logic variables, and
## order and negation constraints.
##
## A value is text, a number or true or false, and two values are the same
## only when they are the same kind: `1` is not `true` here, though it is
## in Python, and the twins must agree.
##
## When not to use it: to compute anything -- a sum, a difference of days.
## A pattern asks only "these events, in this order, and not those"; a
## number worth telling belongs in the events themselves.
class_name SiftPattern
extends RefCounted

## The keys a pattern may have; `name` and `find` must be there.
const KEYS: Array[String] = ["before", "find", "name", "unless"]
## The keys of an event to find, both required.
const FIND_KEYS: Array[String] = ["as", "where"]
## The keys of an event that must not be there; only `where` is required.
const UNLESS_KEYS: Array[String] = ["after", "before", "where"]
## What a variable starts with.
const VARIABLE: String = "?"


## Why `pattern` cannot be sifted for, or "" when it can. The reason starts
## with its rule, P1 to P5, so a test can plant one case for each.
static func problem(pattern: Dictionary) -> String:
	for key: Variant in pattern.keys():
		if not str(key) in KEYS:
			return "P1 a pattern has no key %s" % JSON.stringify(key)
	if not (pattern.get("name") is String and str(pattern.get("name")) != ""):
		return "P1 a pattern needs a name"
	if not (pattern.get("find") is Array and not (pattern["find"] as Array).is_empty()):
		return "P1 a pattern needs at least one event to find"
	var names: Array[String] = []
	for clause: Variant in pattern["find"]:
		var wrong: String = _find_problem(clause, names)
		if wrong != "":
			return wrong
		names.append(str(clause["as"]))
	var order: String = _order_problem(pattern.get("before", []), names)
	if order != "":
		return order
	return _unless_problem(pattern.get("unless", []), names)


## Whether `value` is a variable: text that starts with `?`.
static func is_variable(value: Variant) -> bool:
	return value is String and str(value).begins_with(VARIABLE)


## The variable's name as a match reports it, without its `?`.
static func variable_name(value: String) -> String:
	return value.substr(VARIABLE.length())


## Whether two values are the same: the same kind -- text, number, true or
## false -- and equal. A whole number read from JSON as `1.0` is the same
## as `1`; `true` is not the same as `1`.
static func same(first: Variant, second: Variant) -> bool:
	if _kind(first) == "" or _kind(first) != _kind(second):
		return false
	return first == second


# One event to find: a unique name and a `where` of plain values.
static func _find_problem(clause: Variant, names: Array[String]) -> String:
	if not (clause is Dictionary and _sorted_keys(clause) == FIND_KEYS):
		return "P2 an event to find is {as, where}, not %s" % JSON.stringify(clause)
	if not (clause["as"] is String and str(clause["as"]) != ""):
		return "P2 an event to find needs a name in `as`"
	if str(clause["as"]) in names:
		return "P2 two events to find are both named %s" % clause["as"]
	return _where_problem(clause["where"])


# Each pair in `before` names two different events to find.
static func _order_problem(order: Variant, names: Array[String]) -> String:
	if not order is Array:
		return "P3 `before` is a list of pairs"
	for pair: Variant in order:
		if not (pair is Array and (pair as Array).size() == 2):
			return "P3 a pair in `before` is two names, not %s" % JSON.stringify(pair)
		if not (str(pair[0]) in names and str(pair[1]) in names) or pair[0] == pair[1]:
			return "P3 %s does not name two different events to find" % JSON.stringify(pair)
	return ""


# Each event that must not be there has a `where`, and its bounds name
# events to find.
static func _unless_problem(absent: Variant, names: Array[String]) -> String:
	if not absent is Array:
		return "P4 `unless` is a list"
	for clause: Variant in absent:
		var wrong: String = _absent_problem(clause, names)
		if wrong != "":
			return wrong
	return ""


# One event that must not be there: a `where`, no other key than its two
# bounds, and each bound the name of an event to find.
static func _absent_problem(clause: Variant, names: Array[String]) -> String:
	if not (clause is Dictionary and clause.has("where")):
		return "P4 an event that must not be there needs a `where`"
	for key: Variant in clause.keys():
		if not str(key) in UNLESS_KEYS:
			return "P4 an event that must not be there has no key %s" % JSON.stringify(key)
	for bound: String in ["after", "before"]:
		if clause.has(bound) and not str(clause[bound]) in names:
			return "P4 `%s` names no event to find: %s" % [bound, JSON.stringify(clause[bound])]
	return _where_problem(clause["where"])


# A `where` is a dictionary of plain values: text, numbers, true or false.
static func _where_problem(where: Variant) -> String:
	if not where is Dictionary:
		return "P5 a `where` is a dictionary of fields, not %s" % JSON.stringify(where)
	for field: Variant in where:
		var shown: String = JSON.stringify(where[field])
		if _kind(where[field]) == "":
			return "P5 the field %s is %s: a value is text, a number or true or false" % [field, shown]
	return ""


# "text", "number" or "flag", or "" for anything else.
static func _kind(value: Variant) -> String:
	match typeof(value):
		TYPE_STRING, TYPE_STRING_NAME:
			return "text"
		TYPE_INT, TYPE_FLOAT:
			return "number"
		TYPE_BOOL:
			return "flag"
	return ""


static func _sorted_keys(table: Dictionary) -> Array:
	var keys: Array = table.keys()
	keys.sort()
	return keys
