## The valley's rules (T164, ADR 0025): the world of any day, rebuilt from
## the record of deeds and from rules a designer wrote.
##
## `valley_rules.json` holds the first day's valley, what each verb does to
## the place it acts on, and the rules that carry a consequence from one
## place to another overnight, each with why: a burnt barn leaves the
## market without bread the next day. A night reads every rule against the
## day that ended and writes into the next, so the order of the rules
## changes nothing, and a consequence that passes through two places takes
## two nights. Nothing is random and nothing is kept: the same record gives
## the same world, rebuilt as often as asked. `gameaikit.valley.rules` is
## the same machine, and spec/vectors/valley holds the two to one answer.
##
## Rebuilding day n costs n nights of every rule, and each deed once.
##
## When not to use it: for a world whose consequences need numbers that
## grow -- a price, a crowd. Every fact here is true or false, which is what
## a reader can follow from deed to rule to consequence.
class_name ValleyRules
extends RefCounted

const FILE: String = "res://game/valley/valley_rules.json"

## The valley's places, by name.
var places: Array[String] = []
## Every fact of the first day.
var start: Dictionary = {}
## For each verb, the places it acts on, each with the facts it sets there
## and why.
var verbs: Dictionary = {}
## The overnight rules, in the file's order: `when`, `then`, `why`.
var rules: Array[Dictionary] = []


func _init(table: Dictionary = {}) -> void:
	var read: Dictionary = table if not table.is_empty() else read_file()
	places.assign((read["places"] as Dictionary).keys())
	start = read["start"]
	verbs = read["verbs"]
	rules.assign(read["rules"])


## The rules as `valley_rules.json` writes them.
static func read_file() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(FILE))


## An empty record that knows this valley's verbs and places, so it can
## refuse a deed that names anything else.
func new_record() -> DeedLog:
	return DeedLog.new(places, verbs)


## The world at the end of `day`: the first day's valley, then for each day
## one night of the rules and that day's deeds, in the record's order.
## Deeds after `day` are not read, so a record cut at `day` gives the same.
func rebuild(record: DeedLog, day: int) -> ValleyWorld:
	var world := ValleyWorld.new(start)
	var done_deeds: Array[Dictionary] = record.deeds()
	var next: int = 0
	for today: int in range(1, day + 1):
		world = overnight(world)
		while next < done_deeds.size() and int(done_deeds[next]["day"]) == today:
			apply(world, done_deeds[next])
			next += 1
	return world


## The next day's world, before its deeds: every rule whose `when` holds on
## `world`'s day writes its `then` into the next. All are read from the day
## that ended, none from what another rule wrote that night.
func overnight(world: ValleyWorld) -> ValleyWorld:
	var following: ValleyWorld = world.next_day()
	for rule: Dictionary in rules:
		if not holds(rule["when"], world.facts):
			continue
		var then: Dictionary = rule["then"]
		for name: String in then:
			following.write(name, bool(then[name]), str(rule["why"]))
	return following


## Whether every fact `when` names has its value in `facts`.
static func holds(when: Dictionary, facts: Dictionary) -> bool:
	for name: String in when:
		if bool(facts[name]) != bool(when[name]):
			return false
	return true


## Do `deed` in `world`, at once: the facts its verb sets on its place.
func apply(world: ValleyWorld, deed: Dictionary) -> void:
	var place: String = str(deed["place"])
	var act: Dictionary = verbs[str(deed["verb"])][place]
	var why: String = "day %d, %s the %s: %s" % [int(deed["day"]), deed["verb"], place, act["why"]]
	var sets: Dictionary = act["sets"]
	for fact: String in sets:
		world.write("%s.%s" % [place, fact], bool(sets[fact]), why)
