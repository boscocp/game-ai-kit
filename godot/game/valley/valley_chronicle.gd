## The valley's chronicle (T166): the moments of its story worth telling,
## found by story sifting over what happened, and told -- never acted on.
##
## What happened is a list of events derived from the record of deeds by
## the valley's own rules: each night, every fact the night changed (`{day,
## kind: "night", place, fact, value}`), then that day's deeds (`{day, kind:
## "deed", verb, place}`). It is rebuilt every time it is asked for, as the
## world is, and never saved: ADR 0025 keeps deeds and nothing derived.
##
## A night's change also names the deed behind it, when there is one
## (`cause_day`, `cause_verb`, `cause_place`): the deed that set a fact the
## rule read, followed back through the nights between. Burn the mill, and
## two nights later the market's bread is gone because of it -- not because
## of the well dug the day between (review 189, finding 3). A pattern joins
## the two on those fields, so a line names the cause, never merely the
## deed that came last.
##
## `chronicle.json` holds the patterns a designer wrote -- the third time
## the same deed was done to a place, the market losing its bread after a
## deed, a burnt place rebuilt -- and `StorySifter` finds every match. A
## line of the chronicle is one match: the pattern's name, the values its
## line is worded from, and the events it matched, so the screen can show
## why each line is there. The newest are told, `TOLD` at most.
##
## It only reads. Nothing here writes the record, the save or a world the
## game holds; `chronicle_test.gd` compares all three before and after.
##
## Telling costs a rebuild of every day, as `ValleyRules.rebuild` does, and
## a sift of each pattern; `ValleyGame` keeps the answer until the record
## or the day changes.
##
## When not to use it: to decide anything. A villager, a price or a door
## that read the chronicle would let a designer's choice of stories change
## the world; they read the facts.
class_name ValleyChronicle
extends RefCounted

const FILE: String = "res://game/valley/chronicle.json"
## How many lines are told, the newest.
const TOLD: int = 6

## The patterns, in the file's order.
var patterns: Array[Dictionary] = []
var sifter := StorySifter.new()


func _init(table: Dictionary = {}) -> void:
	var read: Dictionary = table if not table.is_empty() else JSON.parse_string(FileAccess.get_file_as_string(FILE))
	patterns.assign(read["patterns"])
	for pattern: Dictionary in patterns:
		if SiftPattern.problem(pattern) != "":
			push_error("chronicle.json: %s" % SiftPattern.problem(pattern))  # not shown: an engine error for the developer


## What happened in the valley up to the end of `day`, as events: each
## night's changed facts, then that day's deeds in the record's order.
static func events(rules: ValleyRules, record: DeedLog, day: int) -> Array[Dictionary]:
	var happened: Array[Dictionary] = []
	var world := ValleyWorld.new(rules.start)
	# For each fact a deed has reached, that deed, as the record keeps it.
	var causes: Dictionary = {}
	var done_deeds: Array[Dictionary] = record.deeds()
	var next: int = 0
	for today: int in range(1, day + 1):
		var following: ValleyWorld = rules.overnight(world)
		happened.append_array(changes(rules, world, following, causes, today))
		world = following
		while next < done_deeds.size() and int(done_deeds[next]["day"]) == today:
			# An event is the deed as kept, told apart from a night's change by
			# its kind; the record's own deed is never given the key.
			var event: Dictionary = done_deeds[next].duplicate()
			event["kind"] = "deed"
			happened.append(event)
			_caused_by(rules, done_deeds[next], causes)
			rules.apply(world, done_deeds[next])
			next += 1
	return happened


## The facts that differ from `before` to `after`, as night events of `day`,
## each with the deed behind it when one is; `causes` is brought up to date.
static func changes(rules: ValleyRules, before: ValleyWorld, after: ValleyWorld, causes: Dictionary,
		day: int) -> Array[Dictionary]:
	var changed: Array[Dictionary] = []
	var known: Dictionary = causes.duplicate()
	for name: String in after.facts:
		if bool(before.facts[name]) == bool(after.facts[name]):
			continue
		var parts: PackedStringArray = name.split(".")
		var event: Dictionary = {"day": day, "kind": "night", "place": parts[0], "fact": parts[1]}
		event["value"] = bool(after.facts[name])
		var cause: Dictionary = cause_of(rules, before, name, bool(after.facts[name]), known)
		causes.erase(name)
		if not cause.is_empty():
			causes[name] = cause
			event["cause_day"] = cause["day"]
			event["cause_verb"] = cause["verb"]
			event["cause_place"] = cause["place"]
		changed.append(event)
	return changed


## The deed behind `name` becoming `value` overnight from `world`: of the
## rules that wrote it, the latest deed behind a fact one of them read; or
## an empty dictionary when no deed is behind it.
static func cause_of(rules: ValleyRules, world: ValleyWorld, name: String, value: bool,
		known: Dictionary) -> Dictionary:
	var latest: Dictionary = {}
	for rule: Dictionary in rules.rules:
		var then: Dictionary = rule["then"]
		if then.has(name) and bool(then[name]) == value and ValleyRules.holds(rule["when"], world.facts):
			latest = _later(latest, _latest_cause(rule["when"], known))
	return latest


# The latest deed behind any of the facts `when` reads, or {}.
static func _latest_cause(when: Dictionary, known: Dictionary) -> Dictionary:
	var latest: Dictionary = {}
	for fact: String in when:
		latest = _later(latest, known.get(fact, {}))
	return latest


# The later of two deeds by day; the first on a tie; {} counts as none.
static func _later(first: Dictionary, second: Dictionary) -> Dictionary:
	if second.is_empty() or (not first.is_empty() and int(first["day"]) >= int(second["day"])):
		return first
	return second


# Every fact `deed` sets is now caused by it.
static func _caused_by(rules: ValleyRules, deed: Dictionary, causes: Dictionary) -> void:
	var place: String = str(deed["place"])
	for fact: String in rules.verbs[str(deed["verb"])][place]["sets"]:
		causes["%s.%s" % [place, fact]] = deed.duplicate()


## The chronicle up to the end of `day`: the newest `TOLD` lines, oldest
## first. Each is `{pattern, day, values, events}` -- the pattern's name,
## the day of its last event, the values its line is worded from, and the
## events it matched, in the record's order. Lines are ordered by their
## last event, then by the pattern's place in the file, then by their
## first event, so the same record always tells the same chronicle.
func tell(rules: ValleyRules, record: DeedLog, day: int) -> Array[Dictionary]:
	var happened: Array[Dictionary] = events(rules, record, day)
	var ranked: Array[Array] = []
	for place: int in range(patterns.size()):
		for match: Dictionary in sifter.sift(happened, patterns[place]):
			var indices: Array = (match["events"] as Dictionary).values()
			ranked.append([indices.max(), place, indices.min(), line_of(patterns[place], match, happened)])
	ranked.sort_custom(_earlier)
	var lines: Array[Dictionary] = []
	for entry: Array in ranked.slice(maxi(ranked.size() - TOLD, 0)):
		lines.append(entry[3])
	return lines


# Whether `first` is told before `second`: by last event, pattern, first event.
func _earlier(first: Array, second: Array) -> bool:
	for key: int in range(3):
		if int(first[key]) != int(second[key]):
			return int(first[key]) < int(second[key])
	return false


## One line of the chronicle, from one match: its bindings and each event's
## day (`first.day`) as the values to word it from, and the events matched.
static func line_of(pattern: Dictionary, match: Dictionary, happened: Array[Dictionary]) -> Dictionary:
	var values: Dictionary = (match["bindings"] as Dictionary).duplicate()
	var indices: Array[int] = []
	for name: String in match["events"]:
		var index: int = int(match["events"][name])
		values["%s.day" % name] = happened[index]["day"]
		indices.append(index)
	indices.sort()
	var matched: Array[Dictionary] = []
	for index: int in indices:
		matched.append(happened[index].duplicate())
	return {"pattern": pattern["name"], "day": matched[-1]["day"], "values": values, "events": matched}
