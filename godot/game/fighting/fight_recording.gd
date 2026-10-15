## A fight, kept: the input log written to a file, and cut back into the rows
## behaviour cloning learns from (T18).
##
## What is kept is the log and nothing else -- the two characters and one
## pair of inputs per frame, as `FightReplay` reads it -- because T16 made a
## log a replay: the same inputs from the same start give the same fight, so
## every frame can be rebuilt from it. The rows are not stored by the game;
## `rows_of` replays a recording and writes them, and runs again whenever the
## situation's features change. A recording outlives the features cut from it.
##
## A row is one decision of the recorded player: the moment it began a new
## action, as T17 reads one, what it did, and the situation it saw
## `REACTION` frames before. Before, because a person decides on what was on
## screen a quarter of a second ago, and the cloned opponent is handed the
## fight as late (`FightDelay`): what it learns from and what it is later
## asked about are the same age.
##
## When not to use it: a log recorded under other frame data. A recording is
## inputs, not outcomes, and replays under whatever rules are current.
class_name FightRecording
extends RefCounted

## How late the recorded player is taken to have seen the fight, in frames:
## the same number the opponent is held to.
const REACTION: int = FightDelay.MINIMUM_REACTION
## A fight shorter than this, in frames, is not kept: a restart pressed by
## accident is not a fight. Five seconds.
const SHORTEST: int = 300
## Who a recording is of, when it is of a person.
const PERSON: String = "person"


## Where recordings live: `data/fights/` at the top of the repository, outside
## the Godot project, so the editor never imports them.
static func directory() -> String:
	return ProjectSettings.globalize_path("res://").path_join("../data/fights").simplify_path()


## Write a recording of `input_log` -- the scene's log, `[p1, p2]` a frame --
## fought as `characters`, against `facing`, by `player`, to `folder`, as
## `name`, or named for the moment when `name` is "". Its path is returned;
## "" when the fight was too short to keep or the file could not be written.
static func save(input_log: Array, characters: Array[String], facing: String, player: String, folder: String,
		name: String = "") -> String:
	if input_log.size() < SHORTEST:
		return ""
	DirAccess.make_dir_recursive_absolute(folder)
	if name == "":
		name = "%s-%s" % [Time.get_datetime_string_from_system().replace(":", "-"), Time.get_ticks_msec()]
	var path: String = folder.path_join(name + ".json")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	var recording: Dictionary = {"player": player, "facing": facing, "characters": characters, "inputs": input_log}
	file.store_string(JSON.stringify(recording) + "\n")
	return path


## The rows of player 0's decisions in `recording`, oldest first: each
## `{"situation": ..., "action": ...}`, the situation as `FightSituation.of`
## writes it, seen `REACTION` frames before the action began.
static func rows_of(recording: Dictionary, data: FightData) -> Array[Dictionary]:
	var characters: Array = recording["characters"]
	var state: FightState = FightState.starting(data, characters[0], characters[1])
	var past: Array[FightState] = [state]
	var rows: Array[Dictionary] = []
	var last: String = ""
	var previous: String = ""
	for pair: Array in recording["inputs"]:
		state = FightRules.step(state, [int(pair[0]), int(pair[1])] as Array[int], data)
		past.append(state)
		if past.size() > REACTION + 1:
			past.pop_front()
		var action: String = FightAction.of(state, 0, data)
		if action != "" and action != previous:
			rows.append({"situation": FightSituation.of(past[0], 0, last, data), "action": action})
			last = action
		previous = action
	return rows


## Every recording in `folder`, by file name, read; a file that is not one
## is named in `refused` rather than skipped in silence.
static func read_all(folder: String, refused: Array[String]) -> Dictionary:
	var found: Dictionary = {}
	var names: PackedStringArray = DirAccess.get_files_at(folder)
	names.sort()
	for name: String in names:
		if not name.ends_with(".json"):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join(name)))
		var wrong: String = why_not_a_recording(parsed)
		if wrong != "":
			refused.append("%s: %s" % [name, wrong])
			continue
		found[name] = parsed
	return found


## What is wrong with `parsed` as a recording, or "" when nothing is.
static func why_not_a_recording(parsed: Variant) -> String:
	if not parsed is Dictionary:
		return "not a JSON object"
	for field: String in ["player", "characters", "inputs"]:
		if not parsed.has(field):
			return "no \"%s\"" % field
	if not parsed["characters"] is Array or parsed["characters"].size() != 2:
		return "\"characters\" is not two names"
	if not parsed["inputs"] is Array:
		return "\"inputs\" is not a list"
	return ""
