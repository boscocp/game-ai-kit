## The fighting scenario's frame data, read from `characters.json`.
##
## Every number a fight is resolved by lives in that file, and none in code:
## a fighting game whose frame data is scattered through its methods cannot be
## balanced or reasoned about (T16). The file is a copy of
## `spec/frames/characters.json`, which is where T17 and T18 read it from
## Python; a test holds the two byte for byte.
##
## The file is checked when it is read, every number in it: a move missing a
## number, or holding a fraction or a negative, is refused with the reason. A
## frame count of 6.5 would play, and two machines would disagree about it;
## negative damage would heal.
##
## When not to use it: a game whose moves are animation-driven, with boxes
## drawn per frame in an editor. That is the same data with a tool in front.
class_name FightData
extends RefCounted

const PATH: String = "res://game/fighting/characters.json"

## The whole numbers every move must carry.
const MOVE_NUMBERS: Array[String] = ["startup", "active", "recovery", "damage", "hitstun", "blockstun", "hurtbox_reach"]
## A move's stance: whether it is done standing, or holding down.
const STANCES: Array[String] = ["standing", "crouching"]
## A move's height: which guard stops it. `mid` is stopped by either, `low`
## only crouching, `overhead` only standing, and a `throw` by neither.
const HEIGHTS: Array[String] = ["mid", "low", "overhead", "throw"]

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


## The move a character does for `button`, or "" when it has none. Holding
## down picks the crouching move for the button; a button with no crouching
## move does its standing one, so no button is dead while crouched.
func move_for_button(character_name: String, button: String, crouching: bool = false) -> String:
	var standing: String = _move_in_stance(character_name, button, "standing")
	if not crouching:
		return standing
	var low: String = _move_in_stance(character_name, button, "crouching")
	return low if low != "" else standing


## True when the move is a throw: never blocked, never a counter-hit.
func is_throw(character_name: String, move_name: String) -> bool:
	return move(character_name, move_name)["height"] == "throw"


func _move_in_stance(character_name: String, button: String, stance: String) -> String:
	var moves: Dictionary = character(character_name)["moves"]
	for name: String in moves:
		if moves[name]["button"] == button and moves[name]["stance"] == stance:
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
	var stage: Variant = table["stage"]
	var tops: Array = [table["buffer_frames"], table["pushback"], table["counter_hit"].get("damage_percent"),
			table["counter_hit"].get("extra_hitstun"), stage.get("width")] + Array(stage.get("starts", [null]))
	if not tops.all(_is_count):
		return "the stage, buffer, pushback and counter-hit numbers must all be whole and not negative"
	for name: String in table["characters"]:
		var problem: String = _character_problem(name, table["characters"][name])
		if problem != "":
			return problem
	return ""


func _character_problem(name: String, numbers: Dictionary) -> String:
	for key: String in CHARACTER_NUMBERS:
		if not _is_count(numbers.get(key)):
			return "%s's %s is not a whole number" % [name, key]
	if not numbers.get("moves") is Dictionary or numbers["moves"].is_empty():
		return "%s has no moves" % name
	for move_name: String in numbers["moves"]:
		var problem: String = _move_problem(name, move_name, numbers["moves"][move_name], numbers["moves"])
		if problem != "":
			return problem
	return _dead_button(name, numbers["moves"])


# A button with a crouching move and no standing one would do nothing when
# pressed standing: "no button is dead while crouched" needs the other way
# round to hold as well.
func _dead_button(name: String, moves: Dictionary) -> String:
	var standing: Array = moves.values().filter(func(frames: Dictionary) -> bool: return frames["stance"] == "standing")
	var buttons: Array = standing.map(func(frames: Dictionary) -> String: return frames["button"])
	for move_name: String in moves:
		if not buttons.has(moves[move_name]["button"]):
			return "%s's %s has no standing move on its button, so standing it does nothing" % [name, move_name]
	return ""


func _move_problem(name: String, move_name: String, frames: Dictionary, moves: Dictionary) -> String:
	var label: String = "%s's %s" % [name, move_name]
	for key: String in MOVE_NUMBERS:
		if not _is_count(frames.get(key)):
			return "%s has no whole, non-negative %s" % [label, key]
	if int(frames["startup"]) < 1 or int(frames["active"]) < 1:
		return "%s must have at least one startup and one active frame" % label
	if not FightInput.BUTTONS.has(frames.get("button")):
		return "%s has no button among %s" % [label, FightInput.BUTTONS.keys()]
	if not STANCES.has(frames.get("stance")) or not HEIGHTS.has(frames.get("height")):
		return "%s needs a stance among %s and a height among %s" % [label, STANCES, HEIGHTS]
	var is_throw: bool = frames["height"] == "throw"
	if is_throw != (frames["button"] == "throw") or (is_throw and frames["stance"] != "standing"):
		return "%s: a throw is done standing, on the throw button, and only a throw is" % label
	for other: String in moves:
		if other != move_name and moves[other].get("button") == frames["button"] and moves[other].get("stance") == frames["stance"]:
			return "%s and %s are both %s %s: a press could not tell them apart" % [label, other, frames["stance"], frames["button"]]
	if not _is_span(frames.get("hitbox")) or not _is_span(frames.get("cancel_window")):
		return "%s needs a hitbox and a cancel window, each two whole numbers, near first" % label
	for target: Variant in frames.get("cancels_into", [null]):
		if not moves.has(target):
			return "%s cancels into %s, which is not one of its moves" % [label, target]
	return ""


# True for a number with nothing after the point that is not negative: JSON
# reads every number as a float, so 6 and 6.0 are the same and 6.5 is not.
static func _is_count(value: Variant) -> bool:
	return (value is float or value is int) and float(value) == floorf(float(value)) and float(value) >= 0.0


# Two counts, the first no larger than the second: a hitbox's near and far
# edge, or a cancel window's first and last frame.
static func _is_span(value: Variant) -> bool:
	return value is Array and (value as Array).size() == 2 and (value as Array).all(_is_count) \
			and float(value[0]) <= float(value[1])
