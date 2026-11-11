## The player's standing in the valley (T164, ADR 0025): for each virtue,
## the sum of fixed weights over the record's deeds.
##
## `standing.json` holds one weight per verb and place for each virtue --
## care and fear -- each with a reason a designer wrote. The weights are
## read once and never change; the standing changes only when a deed is
## added to the record, and it is rebuilt from the record, never saved.
## Two players who did the same deeds stand the same, however they played:
## it estimates nothing about the person, and it sets no difficulty, only
## the consequences `standing.json` lists -- a price, a door, a greeting.
## `gameaikit.valley.standing` is the same sum.
##
## Reading the standing costs one look-up per deed and virtue.
##
## When not to use it: as a model of the player. A number fitted to how
## someone plays, or kept between sessions, is a profile (ADR 0016, N14).
class_name Standing
extends RefCounted

const FILE: String = "res://game/valley/standing.json"

## The virtues, in the file's order.
var virtues: Array[String] = []
## The consequences the standing may set, and nothing else.
var consequences: Array[String] = []
# For each "verb place", its weight for every virtue and its reason.
var _weights: Dictionary = {}


func _init(table: Dictionary = {}) -> void:
	_load_weights(table if not table.is_empty() else read_file())


## The weights as `standing.json` writes them.
static func read_file() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(FILE))


## The standing `record` sums to: for each virtue, the weight of every deed.
func of(record: DeedLog) -> Dictionary:
	var sums: Dictionary = {}
	for virtue: String in virtues:
		sums[virtue] = 0
	for deed: Dictionary in record.deeds():
		for virtue: String in virtues:
			sums[virtue] += weight(deed, virtue)
	return sums


## The weight of `deed` for `virtue`, as a designer wrote it.
func weight(deed: Dictionary, virtue: String) -> int:
	return int(_row(deed)[virtue])


## Why `deed` weighs what it does, in the designer's words.
func why(deed: Dictionary) -> String:
	return str(_row(deed)["why"])


## The deeds that make up `virtue` in `record`, each with its weight and
## its reason: every deed that moved it, in the record's order. They sum
## to the virtue, so a screen can say what the player did to stand there.
func contributions(record: DeedLog, virtue: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for deed: Dictionary in record.deeds():
		if weight(deed, virtue) != 0:
			found.append({"deed": deed, "weight": weight(deed, virtue), "why": why(deed)})
	return found


# The one place the weights are written: once, from the file, before any
# deed is read.
func _load_weights(table: Dictionary) -> void:
	virtues.assign((table["virtues"] as Dictionary).keys())
	consequences.assign((table["consequences"] as Dictionary).keys())
	for row: Dictionary in table["weights"]:
		_weights["%s %s" % [row["verb"], row["place"]]] = row


func _row(deed: Dictionary) -> Dictionary:
	return _weights["%s %s" % [deed["verb"], deed["place"]]]
