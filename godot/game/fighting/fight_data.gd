## The fighting scenario's frame data, read from `characters.json`.
##
## Every number a fight is resolved by lives in that file, and none in code:
## a fighting game whose frame data is scattered through its methods cannot be
## balanced or reasoned about (T16). The file is a copy of
## `spec/frames/characters.json`, which is where T17 and T18 read it from
## Python; a test holds the two byte for byte.
##
## The file is checked when it is read. A move missing a number, or holding a
## fraction, is refused with the reason: a frame count of 6.5 would play, and
## two machines would disagree about it.
##
## When not to use it: a game whose moves are animation-driven, with boxes
## drawn per frame in an editor. That is the same data with a tool in front.
class_name FightData
extends RefCounted

const PATH: String = "res://game/fighting/characters.json"

## The whole numbers every move must carry.
const MOVE_NUMBERS: Array[String] = ["startup", "active", "recovery", "damage", "hitstun", "blockstun", "hurtbox_reach"]
## The whole numbers every character must carry.
const CHARACTER_NUMBERS: Array[String] = ["health", "walk_speed", "body"]

## Everything the file says.
var table: Dictionary = {}
## Why the file was refused, or "" when it was read.
var refusal: String = ""


## The frame data at `path`. Check `refusal` before using it.
static func read(path: String = PATH) -> FightData:
	var data := FightData.new()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		data.refusal = "%s is not a JSON object" % path
		return data
	data.table = parsed
	data.refusal = data._problem()
	return data


## One character's numbers and moves.
func character(name: String) -> Dictionary:
	return table["characters"][name]


## Every character's name, in the file's order.
func character_names() -> Array[String]:
	var names: Array[String] = []
	names.assign(table["characters"].keys())
	return names


## A character's move by name.
func move(character_name: String, move_name: String) -> Dictionary:
	return character(character_name)["moves"][move_name]


## The move a character does for `button`, or "" when it has none.
func move_for_button(character_name: String, button: String) -> String:
	var moves: Dictionary = character(character_name)["moves"]
	for name: String in moves:
		if moves[name]["button"] == button:
			return name
	return ""


## A move's whole length in frames: startup, active and recovery.
func length_of(character_name: String, move_name: String) -> int:
	var frames: Dictionary = move(character_name, move_name)
	return int(frames["startup"]) + int(frames["active"]) + int(frames["recovery"])


## A number from the top of the file, as a whole number.
func number(key: String) -> int:
	return int(table[key])


# What is wrong with the file, or "" when nothing is.
func _problem() -> String:
	for key: String in ["stage", "buffer_frames", "pushback", "counter_hit", "characters"]:
		if not table.has(key):
			return "the frame data has no `%s`" % key
	for name: String in table["characters"]:
		var problem: String = _character_problem(name, table["characters"][name])
		if problem != "":
			return problem
	return ""


func _character_problem(name: String, numbers: Dictionary) -> String:
	for key: String in CHARACTER_NUMBERS:
		if not _is_whole(numbers.get(key)):
			return "%s's %s is not a whole number" % [name, key]
	for move_name: String in numbers.get("moves", {}):
		var problem: String = _move_problem(name, move_name, numbers["moves"][move_name])
		if problem != "":
			return problem
	return ""


func _move_problem(name: String, move_name: String, frames: Dictionary) -> String:
	for key: String in MOVE_NUMBERS:
		if not _is_whole(frames.get(key)):
			return "%s's %s has no whole-number %s" % [name, move_name, key]
	if int(frames["startup"]) < 1 or int(frames["active"]) < 1:
		return "%s's %s must have at least one startup and one active frame" % [name, move_name]
	return ""


# True for a number with nothing after the point: JSON reads every number as
# a float, so 6 and 6.0 are the same and 6.5 is not.
static func _is_whole(value: Variant) -> bool:
	return (value is float or value is int) and float(value) == floorf(float(value))
