## The boss fight's three levels, read from `difficulty.json`: chosen by the
## person, in the example or with `--difficulty=<level>`, and never by how
## they play. Nothing about the player is counted to pick one.
##
## Each level sets what the boss's side is given: the player's token pools
## and the delays between grants (T154), how fast the boss's tells are and
## the shortest any may be shown for (T156), how many minions a wave brings
## and the most of each kind that may stand at once. So hard gives the
## boss's side more -- more tokens, shorter delays, bigger waves -- which
## `ai_planning`'s `Difficulty` calls "a lie told to the player". It is not
## one here because nothing is hidden: the level's numbers are on screen
## all fight long. That is why this is not `Difficulty`: that one teaches a
## level that changes only how much a searching AI thinks, and holds itself
## to it.
##
## Hard is faster, never unreadable: a level's minimum telegraph is never
## below the boss table's own, and every attack in every phase, at the
## level's speed, is shown for at least the level's minimum. Every level is
## checked when the file is read, not only the one chosen, and a level that
## breaks the rule refuses the whole file, by its name.
##
## When not to use it: to make the fight follow the person. That would be
## dynamic difficulty adjustment, which the owner chose not to use.
class_name BossDifficulty
extends RefCounted

const FILE: String = "res://game3d/bossfight/difficulty.json"
## The command line's word for a level: `-- --difficulty=hard`.
const FLAG: String = "--difficulty="
## The token kinds, and the fields a level must set for each.
const KINDS: Array[String] = ["melee", "ranged"]  # not shown: the data's field names

## The level chosen when none is named.
var default_level: String = ""
## Each level, as the file writes it, in its order.
var levels: Array[Dictionary] = []
## Why the file was refused, or "".
var refusal: String = ""
var _table_data: Dictionary = {}


## The shipped levels, against the shipped boss table, or refused ones.
static func read(path: String = FILE, table_path: String = BossTable.FILE) -> BossDifficulty:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var table_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(table_path))
	return from_data(parsed if parsed is Dictionary else {}, table_data if table_data is Dictionary else {})


## The levels in `data`, checked against the boss table in `table_data`.
static func from_data(data: Dictionary, table_data: Dictionary) -> BossDifficulty:
	var difficulty: BossDifficulty = new()
	difficulty._table_data = table_data
	difficulty.refusal = why_not_levels(data, table_data)
	if difficulty.refusal != "":
		return difficulty
	difficulty.default_level = str(data["default"])
	for fields: Dictionary in data["levels"]:
		difficulty.levels.append(fields)
	return difficulty


## The level the command line names in `arguments`, or "" for the default.
static func asked(arguments: PackedStringArray) -> String:
	for argument: String in arguments:
		if argument.begins_with(FLAG):
			return argument.trim_prefix(FLAG)
	return ""


## The levels' names, in the file's order.
func names() -> PackedStringArray:
	var found := PackedStringArray()
	for fields: Dictionary in levels:
		found.append(str(fields["name"]))
	return found


## The level after `level_name`, round to the first: what the key picks.
func after(level_name: String) -> String:
	var all: PackedStringArray = names()
	return all[(all.find(level_name) + 1) % all.size()] if not all.is_empty() else ""


## Why `level_name` cannot be played, or "": the file refused, or no level
## of that name -- said by name, with the names there are.
func why_not_level(level_name: String) -> String:
	if refusal != "":
		return refusal
	if not level_name in names():
		return "there is no difficulty called %s; the levels are %s" % [level_name, ", ".join(names())]  # not shown: a refusal for whoever edits the data or types the flag, in its keys' English
	return ""


## The fields of `level_name`, or of the default for "".
func level(level_name: String) -> Dictionary:
	var wanted: String = level_name if level_name != "" else default_level
	for fields: Dictionary in levels:
		if fields["name"] == wanted:
			return fields
	return {}


## The fight's rules at `level_name` ("" the default), from `path`. An
## unknown level gives the default's numbers with `refusal` naming it, so
## the fight is built, shows why, and never starts.
func rules_for(level_name: String, path: String = BossFightRules.FILE) -> BossFightRules:
	var rules: BossFightRules = BossFightRules.shared(path)
	var wanted: String = level_name if level_name != "" else default_level
	var objection: String = why_not_level(wanted)
	rules.apply(wanted, level(wanted) if objection == "" else level(default_level))
	if rules.refusal == "":
		rules.refusal = objection
	return rules


## The boss's table at `level_name`: every telegraph times the level's
## speed, and the level's minimum in place of the table's. The table's own
## check then refuses any attack shown for less. A level that cannot be
## played gives an empty table refused with the level's reason.
func table_for(level_name: String) -> BossTable:
	var wanted: String = level_name if level_name != "" else default_level
	var objection: String = why_not_level(wanted)
	if objection != "":
		var refused: BossTable = BossTable.new()
		refused.refusal = objection
		return refused
	return BossTable.from_data(at_level(_table_data, level(wanted)))


## `table_data` with the level in `fields` applied.
static func at_level(table_data: Dictionary, fields: Dictionary) -> Dictionary:
	var scaled: Dictionary = table_data.duplicate(true)
	var speed: float = float(fields.get("telegraph_scale", 1.0))
	scaled["minimum_telegraph"] = float(fields.get("minimum_telegraph", 0.0))
	for attack_name: String in scaled.get("attacks", {}):
		var attack: Dictionary = scaled["attacks"][attack_name]
		attack["telegraph"] = float(attack.get("telegraph", 0.0)) * speed
	return scaled


## Why `data` is not a set of levels for the boss table `table_data`, or "".
## Every level is checked: the rule holds across the whole table.
static func why_not_levels(data: Dictionary, table_data: Dictionary) -> String:
	if not (data.get("levels") is Array) or (data["levels"] as Array).is_empty():
		return "a difficulty file needs a list of levels"  # not shown: a refusal for whoever edits the data, in its keys' English
	var seen := PackedStringArray()
	for fields: Variant in data["levels"]:
		if not (fields is Dictionary):
			return "every level must be an object"  # not shown: a refusal for whoever edits the data, in its keys' English
		var level_name: String = str(fields.get("name", ""))
		if level_name == "" or level_name in seen:
			return "every level needs a name of its own; %s is not one" % level_name  # not shown: a refusal for whoever edits the data, in its keys' English
		seen.append(level_name)
		var objection: String = _why_not_one(fields, table_data)
		if objection != "":
			return "level %s: %s" % [level_name, objection]  # not shown: a refusal for whoever edits the data, in its keys' English
	if not str(data.get("default", "")) in seen:
		return "the default level %s is not one of %s" % [data.get("default", ""), ", ".join(seen)]  # not shown: a refusal for whoever edits the data, in its keys' English
	return ""


# One level: a pool of at least one token and a delay of no less than zero
# for each kind, a wave of at least one no larger than its cap, and tells
# that stay readable.
static func _why_not_one(fields: Dictionary, table_data: Dictionary) -> String:
	for kind: String in KINDS:
		var pool: int = int(fields.get("tokens", {}).get("pools", {}).get(kind, 0))
		var delay: float = float(fields.get("tokens", {}).get("delays", {}).get(kind, -1.0))
		var wave: int = int(fields.get("wave", {}).get(kind, 0))
		var cap: int = int(fields.get("wave_cap", {}).get(kind, 0))
		if pool < 1 or delay < 0.0:
			return "%s needs a pool of at least 1 and a delay of 0 or more" % kind  # not shown: a refusal for whoever edits the data, in its keys' English
		if wave < 1 or cap < wave:
			return "%s's wave is %d and its cap %d; a wave needs one minion, and no more than the cap" % [kind, wave, cap]  # not shown: a refusal for whoever edits the data, in its keys' English
	return _why_not_readable(fields, table_data)


# The tells: a speed above zero, a minimum no lower than the boss table's,
# and the table at this level still sound -- every attack shown for at
# least the level's minimum.
static func _why_not_readable(fields: Dictionary, table_data: Dictionary) -> String:
	if float(fields.get("telegraph_scale", 0.0)) <= 0.0:
		return "telegraph_scale must be above zero"  # not shown: a refusal for whoever edits the data, in its keys' English
	var floor_seconds: float = float(table_data.get("minimum_telegraph", 0.0))
	var minimum: float = float(fields.get("minimum_telegraph", 0.0))
	if minimum < floor_seconds:
		return "its minimum telegraph %.2f s is under the boss table's %.2f s" % [minimum, floor_seconds]  # not shown: a refusal for whoever edits the data, in its keys' English
	return BossTable.why_not_table(at_level(table_data, fields))
