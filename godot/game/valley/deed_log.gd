## The record of what the player did to the valley's places (T164, ADR 0025).
##
## A deed is `{day, verb, place}` and nothing else: the schema has no field
## for a person, so the record can never become a log of what the player
## did to whom. The log is appended to and never edited -- it has no way to
## change or remove a deed once kept -- and its deeds come in the order of
## their days. Everything the valley shows is rebuilt from it by
## `ValleyRules` and `Standing`; only `ValleySave` puts it on disk.
##
## A deed is refused, by name, when it has a key beyond the three, a verb
## the rules do not know, a place that is not one of the valley's, a verb
## that does not act on that place, or a day before the last one kept.
## Appending is constant time; reading the deeds copies them.
##
## When not to use it: for anything that is not a deed on a place. A
## villager's mood, a price or the world itself is derived, and a record of
## derived things would drift from its cause the first time a rule changed.
class_name DeedLog
extends RefCounted

## The keys of a deed, and the only ones.
const KEYS: Array[String] = ["day", "verb", "place"]

var _deeds: Array[Dictionary] = []
## The valley's places, by name.
var _places: Array[String] = []
## For each verb, the places it acts on.
var _verbs: Dictionary = {}


func _init(places: Array[String], verbs: Dictionary) -> void:
	_places = places
	_verbs = verbs


## A deed as the record keeps it: the day it was done, what was done, where.
static func make(day: int, verb: String, place: String) -> Dictionary:
	return {"day": day, "verb": verb, "place": place}


## Keep `deed` at the end of the record, or refuse it. Returns "" when it
## was kept, or why it was refused, naming the key, verb, place or day at
## fault -- so a planted person is reported as what it is.
func append(deed: Dictionary) -> String:
	var why: String = refusal(deed)
	if why == "":
		_deeds.append(make(int(deed["day"]), str(deed["verb"]), str(deed["place"])))
	return why


## Why `deed` cannot be kept after the deeds already in the record, or ""
## when it can. Asked before anything is written, so the save and the
## record never disagree.
func refusal(deed: Dictionary) -> String:
	for key: Variant in deed.keys():
		if not str(key) in KEYS:
			return "a deed has no key %s: a deed is {day, verb, place}, and none has a person as its target" % key
	for key: String in KEYS:
		if not deed.has(key):
			return "a deed has no %s" % key
	var day: Variant = deed["day"]
	if not (day is int or (day is float and float(day) == floorf(float(day)))) or int(day) < 1:
		return "day %s is not a day of the game; days are counted from 1" % [day]
	if not _deeds.is_empty() and int(day) < int(_deeds[-1]["day"]):
		return "day %d comes after day %d in the record; deeds are kept in the order they were done" % [
			int(day), int(_deeds[-1]["day"])]
	return _vocabulary_refusal(str(deed["verb"]), str(deed["place"]))


func _vocabulary_refusal(verb: String, place: String) -> String:
	if not _verbs.has(verb):
		return "unknown verb %s" % verb
	if not place in _places:
		return "%s is not a place in the valley; a deed acts on a place" % place
	if not place in _verbs[verb]:
		return "%s does not act on the %s" % [verb, place]
	return ""


## Every deed, in the order they were kept: a copy, so the reader cannot
## change the record through it.
func deeds() -> Array[Dictionary]:
	return _deeds.duplicate(true)


## How many deeds the record holds.
func size() -> int:
	return _deeds.size()


## The same record as it stood at the end of `day`: every deed done on that
## day or before. The world and the standing of a cut record are that day's.
func cut(day: int) -> DeedLog:
	var earlier := DeedLog.new(_places, _verbs)
	for kept: Dictionary in _deeds:
		if int(kept["day"]) <= day:
			earlier._deeds.append(kept.duplicate())
	return earlier
