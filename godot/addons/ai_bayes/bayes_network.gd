## How likely something you cannot see is, from what you can: a Bayesian
## network, asked by exact inference by enumeration (AIMA 4th ed., 13.2 and
## 13.3.1, figure 13.10).
##
## A network is a list of discrete **variables**, each with its **values**
## ("yes", "no"; or "quiet", "loud", "very loud") and its **parents**, the
## variables it depends on directly. Each variable holds a **conditional
## probability table**: one row for every way its parents can be, and in
## each row the chance of each of its own values. That is all the numbers
## there are -- the network says that a variable, once its parents are
## known, cares about nothing else above it -- and from them the chance of
## any whole assignment is a product, one factor a variable:
##
##     P(x1, ..., xn) = P(x1 | parents(X1)) * ... * P(xn | parents(Xn))
##
## `ask(query, evidence)` answers P(query | evidence) as the book's
## ENUMERATION-ASK does: for each value of the query, the evidence and that
## value fixed, sum the product over every value of every variable left
## hidden, then normalise. `influence` then says what each piece of
## evidence did: the answer with it, less the answer without it -- "which
## evidence moved the belief most" is the largest of those.
##
## The tables are data, written by a person (or learned offline, elsewhere):
## nothing here changes a number from what it sees (invariant 6).
##
## Complexity: `ask` is O(d^n) for n variables of at most d values -- every
## hidden variable doubles the work of a yes-or-no network. Fine for the
## handful of variables a guard reasons with; the book's next step is
## variable elimination (13.3.2), which keeps each sum's partial products
## instead of computing them again, and is not built here.
##
## When not to use it: tens of variables (eliminate, or sample -- 13.4);
## a variable that is a number, not a few values (discretise it, or use a
## filter, as `ai_perception`'s particles do for a place); a belief that
## must follow time -- the chance someone is there *now*, from what was
## seen a minute ago -- which is a dynamic network (ch. 14). And when the
## table's numbers are guesses nobody can defend: the arithmetic is exact,
## but it is only as good as what it multiplies.
class_name BayesNetwork
extends RefCounted

## How far a table's row may sum from 1 and still be read as a distribution.
const ROW_SUM_SLACK: float = 1e-9

## Every variable, in the order given: a parent always comes before its child.
var names: Array[String] = []
## Variable -> its values, in the order given.
var values: Dictionary[String, PackedStringArray] = {}
## Variable -> its parents, in the order given; the first varies slowest
## along the table's rows.
var parents: Dictionary[String, PackedStringArray] = {}
## Variable -> its table: one row per combination of its parents' values,
## each row the chance of each of its values.
var tables: Dictionary[String, Array] = {}
var _problem: String = ""


## The network `data` describes: {"variables": [{"name", "values",
## "parents", "table"}, ...]}, a parent before its child. A malformed one is
## kept, and `problem()` says what is wrong with it.
func _init(data: Dictionary = {}) -> void:
	var rows: Variant = data.get("variables", [])
	if not rows is Array or (rows as Array).is_empty():
		_problem = "B1 the network has no variables"
		return
	for row: Variant in rows:
		_problem = _add(row)
		if _problem != "":
			return


## The network in the JSON file at `path`.
static func read(path: String) -> BayesNetwork:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	# `new()`, not its own class name: naming it would make the script hold itself (T162, docs/godot/exit-leaks.md).
	return new(data if data is Dictionary else {})


## What is wrong with the network as given, or "" when it can be asked.
## Each answer starts with its rule, B1 to B5, as the vectors' README lists.
func problem() -> String:
	return _problem


## P(`variable` = `value` | its parents as `assignment` has them): one entry
## of its table. Every parent must be in `assignment`; a value the network
## does not have, for the variable or a parent, is an error and reads 0 --
## never a neighbouring row read in silence.
func probability(variable: String, value: String, assignment: Dictionary) -> float:
	var row: int = 0
	for parent: String in parents[variable]:
		var found: int = values[parent].find(str(assignment.get(parent, "")))
		if found == -1:
			push_error("BayesNetwork: '%s' has no value '%s'" % [parent, assignment.get(parent, "")])
			return 0.0
		row = row * values[parent].size() + found
	var column: int = values[variable].find(value)
	if column == -1:
		push_error("BayesNetwork: '%s' has no value '%s'" % [variable, value])
		return 0.0
	return float(tables[variable][row][column])


## P(`query` | `evidence`): one chance for each of the query's values, in
## their order, summing to 1. `evidence` maps a variable to the value it was
## seen to take. Empty when the evidence cannot happen under the tables
## (its chance is 0), or when it or the query names what the network lacks.
func ask(query: String, evidence: Dictionary) -> PackedFloat64Array:
	var unknown: String = _unknown(query, evidence)
	if unknown != "":
		push_error(unknown)
		return PackedFloat64Array()
	var distribution := PackedFloat64Array()
	for value: String in values[query]:
		var extended: Dictionary = evidence.duplicate()
		extended[query] = value
		distribution.append(_enumerate_all(0, extended))
	return _normalised(distribution)


## What each piece of `evidence` did to P(`query` = `value`): the answer
## with all of it, less the answer with that piece left out, by variable,
## in the evidence's order. Positive, it raised the belief. Empty when the
## evidence cannot happen.
func influence(query: String, value: String, evidence: Dictionary) -> Dictionary:
	var moved: Dictionary = {}
	var with_all: PackedFloat64Array = ask(query, evidence)
	if with_all.is_empty():
		return moved
	var index: int = values[query].find(value)
	for name: String in evidence:
		var without: Dictionary = evidence.duplicate()
		without.erase(name)
		moved[name] = with_all[index] - ask(query, without)[index]
	return moved


## The evidence that moved the belief most, either way: the variable in
## `moved` (as `influence` answers) with the largest change by size, the
## first of equal ones; "" when there is none.
static func most_moved(moved: Dictionary) -> String:
	var strongest: String = ""
	for name: String in moved:
		if strongest == "" or absf(float(moved[name])) > absf(float(moved[strongest])):
			strongest = name
	return strongest


# ENUMERATE-ALL (figure 13.10): the sum, over every value of every variable
# from `index` on that `assignment` does not fix, of the product of their
# tables' entries. A fixed variable contributes its one entry.
func _enumerate_all(index: int, assignment: Dictionary) -> float:
	if index == names.size():
		return 1.0
	var variable: String = names[index]
	if assignment.has(variable):
		return probability(variable, str(assignment[variable]), assignment) * _enumerate_all(index + 1, assignment)
	var total: float = 0.0
	for value: String in values[variable]:
		var extended: Dictionary = assignment.duplicate()
		extended[variable] = value
		total += probability(variable, value, extended) * _enumerate_all(index + 1, extended)
	return total


# Each entry over their sum, in order; empty when they sum to 0.
static func _normalised(distribution: PackedFloat64Array) -> PackedFloat64Array:
	var total: float = 0.0
	for chance: float in distribution:
		total += chance
	if total <= 0.0:
		return PackedFloat64Array()
	var scaled := PackedFloat64Array()
	for chance: float in distribution:
		scaled.append(chance / total)
	return scaled


# Why `query` and `evidence` cannot be asked of this network, or "".
func _unknown(query: String, evidence: Dictionary) -> String:
	if _problem != "":
		return "BayesNetwork: %s" % _problem
	if not values.has(query) or evidence.has(query):
		return "BayesNetwork: '%s' is not a variable to ask about here" % query
	for name: Variant in evidence:
		if not values.has(str(name)) or not values[str(name)].has(str(evidence[name])):
			return "BayesNetwork: the evidence %s = %s names no variable or value here" % [name, evidence[name]]
	return ""


# Read one variable's row of the data; why it cannot be read, or "".
func _add(row: Variant) -> String:
	if not row is Dictionary:
		return "B2 a variable is not an object"
	var name: String = str(row.get("name", ""))
	if not row.get("values") is Array:
		return "B2 the values of '%s' are not a list" % name
	var own := PackedStringArray(row["values"])
	if name == "" or values.has(name) or own.size() < 2 or _repeats(own):
		return "B2 the variable '%s' has no name, a name taken, or fewer than two distinct values" % name
	var above := PackedStringArray(row.get("parents", []))
	for parent: String in above:
		if not values.has(parent):
			return "B3 the parent '%s' of '%s' is not a variable given before it" % [parent, name]
	var problem_found: String = _table_problem(name, own, above, row.get("table", []))
	if problem_found != "":
		return problem_found
	names.append(name)
	values[name] = own
	parents[name] = above
	tables[name] = row["table"]
	return ""


# Why `table` is not one row per combination of `above`'s values, each a
# distribution over `own`; or "".
func _table_problem(name: String, own: PackedStringArray, above: PackedStringArray, table: Variant) -> String:
	var rows_wanted: int = 1
	for parent: String in above:
		rows_wanted *= values[parent].size()
	if not table is Array or (table as Array).size() != rows_wanted:
		return "B4 the table of '%s' does not have %d rows, one per combination of its parents" % [name, rows_wanted]
	for entry: Variant in table:
		var wrong: String = _row_problem(name, own, entry)
		if wrong != "":
			return wrong
	return ""


# Why `entry` is not one chance for each of `own`, summing to 1; or "".
static func _row_problem(name: String, own: PackedStringArray, entry: Variant) -> String:
	if not entry is Array or (entry as Array).size() != own.size():
		return "B4 a row of '%s' does not give one chance for each of its %d values" % [name, own.size()]
	var total: float = 0.0
	for chance: Variant in entry:
		if not (chance is float or chance is int) or not is_finite(float(chance)) or float(chance) < 0.0:
			return "B5 a row of '%s' has an entry that is not a chance" % name
		total += float(chance)
	if absf(total - 1.0) > ROW_SUM_SLACK:
		return "B5 a row of '%s' sums to %s, not 1" % [name, total]
	return ""


static func _repeats(own: PackedStringArray) -> bool:
	for index: int in range(own.size()):
		if own.find(own[index]) != index:
			return true
	return false
