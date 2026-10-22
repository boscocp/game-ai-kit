## The kinds of thing a guard can notice, as data rows: which sense, how
## much it matters, how far it carries and how long it stays news.
##
## Mark of the Ninja's guards notice about sixty kinds of interest source,
## each a row with a sense, a priority, a radius and a lifetime [Miles 2013];
## Crysis calls them stims and gives footsteps, weapons and sight their own
## peaks [Welsh 2013]. A footstep, a shot, a thrown object, a body, a door
## left open and a guard's own call are rows of one table, so a new kind of
## event is a new row, not new code -- and a guard's call for help is heard
## by the same hearing as a footstep, or not at all.
##
## A row: `{"sense": "sound" | "sight", "priority": int, "radius": metres,
## "lifetime": seconds}`. Constant time per question.
##
## When not to use it: events that are not noticed but simply known -- a
## scripted alarm every guard must react to. That is the level's decision,
## not a guard's perception, and pretending otherwise hides it.
class_name StimulusTable
extends RefCounted

const SENSES: Array[String] = ["sound", "sight"]

var _rows: Dictionary[String, Dictionary] = {}


## A table of `rows`, kind -> row, as a guard type's JSON gives it.
func _init(rows: Dictionary) -> void:
	for kind: String in rows:
		_rows[kind] = rows[kind]


## Why `rows` cannot be a table, or "" when it can: every row has the four
## fields, a known sense, and no negative radius or lifetime.
static func problem(rows: Dictionary) -> String:
	for kind: String in rows:
		var found: String = _row_problem(kind, rows[kind])
		if found != "":
			return found
	return ""


## True when the table has a row for `kind`.
func has(kind: String) -> bool:
	return _rows.has(kind)


## The sense `kind` reaches a guard by.
func sense(kind: String) -> String:
	return str(_rows[kind]["sense"])


## How much `kind` matters beside another; higher replaces lower.
func priority(kind: String) -> int:
	return int(_rows[kind]["priority"])


## How far `kind` carries, in metres along the level.
func radius(kind: String) -> float:
	return float(_rows[kind]["radius"])


## True when an event of `kind` that happened `age` seconds ago is still news.
func fresh(kind: String, age: float) -> bool:
	return age <= float(_rows[kind]["lifetime"])


static func _row_problem(kind: String, row: Dictionary) -> String:
	for field: String in ["sense", "priority", "radius", "lifetime"]:
		if not row.has(field):
			return "event %s has no %s" % [kind, field]
	if not (str(row["sense"]) in SENSES):
		return "event %s has sense %s, none of %s" % [kind, row["sense"], SENSES]
	if float(row["radius"]) < 0.0 or float(row["lifetime"]) < 0.0:
		return "event %s has a negative radius or lifetime" % kind
	return ""
