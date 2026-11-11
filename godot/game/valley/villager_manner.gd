## How one of the valley's people meets the player (T165, ADR 0025): a
## fixed manner a designer wrote, read off the standing and the world.
##
## Three people have one -- the ferryman, the merchant, the priestess --
## each in `manners.json`: a list of rules read top to bottom, the first
## that holds setting the person's one consequence (a price, a door) and
## the greeting. A rule names the world's facts it needs and a virtue's
## least value; the last rule needs nothing. The manner never changes and
## is never saved; it reads the standing, rebuilt from the record, and the
## day's facts -- never a deed aimed at a person, since there is none.
## What it sets is a consequence, never a challenge: nothing in the valley
## is harder because of it, and what a person says changes nothing that
## persists.
##
## Reading a manner costs one look at each rule until one holds.
##
## When not to use it: for a person whose manner should change with what
## they lived through. That needs a memory of their own, which the valley
## keeps for nobody (ADR 0025).
class_name VillagerManner
extends RefCounted

const FILE: String = "res://game/valley/manners.json"
## The greeting is every person's second consequence.
const GREETING: String = "greeting"

## Who this is: `ferryman`, `merchant`, `priestess`.
var who: String = ""
## The place the person stands at.
var where: String = ""
## The consequence the person sets, one of `standing.json`'s, and its
## usual value.
var consequence: String = ""
var usual: int = 0
## The rules, in the file's order: `when`, `virtue`, `at_least`, `sets`,
## `says`, `why`.
var rules: Array[Dictionary] = []


func _init(person: String, table: Dictionary) -> void:
	who = person
	where = str(table["where"])
	consequence = str(table["consequence"])
	usual = int(table["usual"])
	rules.assign(table["rules"])


## The three people with a manner, in the file's order.
static func everyone() -> Array[VillagerManner]:
	var read: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	var found: Array[VillagerManner] = []
	for person: String in read["people"]:
		found.append(VillagerManner.new(person, read["people"][person]))
	return found


## How the person meets the player whose standing is `sums` (virtue ->
## value), on a day whose world has `facts`: the rule that held, by its
## index, the consequence it sets and the greeting.
func meets(sums: Dictionary, facts: Dictionary) -> Dictionary:
	for index: int in range(rules.size()):
		var rule: Dictionary = rules[index]
		if holds(rule, sums, facts):
			return {"rule": index, consequence: int(rule["sets"]), GREETING: str(rule["says"])}
	return {"rule": -1, consequence: usual, GREETING: ""}


## Whether `rule` holds for the standing `sums` and the world's `facts`.
static func holds(rule: Dictionary, sums: Dictionary, facts: Dictionary) -> bool:
	if not ValleyRules.holds(rule["when"], facts):
		return false
	var virtue: String = str(rule["virtue"])
	return virtue == "" or int(sums.get(virtue, 0)) >= int(rule["at_least"])
