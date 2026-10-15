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
## `{"situation": ..., "action": ..., "frame": the frame it began on}`, the situation as `FightSituation.of`
## writes it, seen `REACTION` frames before the action began -- its `last`
## included, which is `last_seen` on that same frame.
static func rows_of(recording: Dictionary, data: FightData) -> Array[Dictionary]:
	var states: Array[FightState] = states_of(recording, data)
	var seen_last: PackedStringArray = last_seen(states, 0, data)
	var rows: Array[Dictionary] = []
	var previous: String = ""
	for frame: int in range(1, states.size()):
		var action: String = FightAction.of(states[frame], 0, data)
		if action != "" and action != previous:
			var seen: int = maxi(0, frame - REACTION)
			var situation: Dictionary = FightSituation.of(states[seen], 0, seen_last[seen], data)
			rows.append({"situation": situation, "action": action, "frame": frame})
		previous = action
	return rows


## Every frame of `recording`, the opening one first, replayed.
static func states_of(recording: Dictionary, data: FightData) -> Array[FightState]:
	var characters: Array = recording["characters"]
	var states: Array[FightState] = [FightState.starting(data, characters[0], characters[1])]
	for pair: Array in recording["inputs"]:
		states.append(FightRules.step(states.back(), [int(pair[0]), int(pair[1])] as Array[int], data))
	return states


## For every frame of `states`, the last action fighter `index` was seen
## doing on that frame or before it -- "" before its first. This is what a
## decision's `last` is, in the rows and in the game alike: a cloned
## opponent reads its own fighter off the late frames it is handed, so it
## can only know what it was doing as of the frame it decides from, and the
## rows are held to the same.
static func last_seen(states: Array[FightState], index: int, data: FightData) -> PackedStringArray:
	var seen: PackedStringArray = []
	var last: String = ""
	for state: FightState in states:
		var reading: String = FightAction.of(state, index, data)
		if reading != "":
			last = reading
		seen.append(last)
	return seen


## The rows file: a header, then each recording's rows, one row a line --
## its situation's words in `FightSituation.FEATURES` order, the action, and
## the frame it began on -- so a diff of the file reads as a diff of
## decisions, and Python can tell what an opponent `REACTION` frames late
## had seen by then.
static func rows_text(recordings: Dictionary, data: FightData) -> String:
	var header: Dictionary = {"generated_by": "godot/test/export_clone_rows.gd", "reaction": REACTION,
			"features": FightSituation.FEATURES, "actions": FightAction.ACTIONS}
	var lines: PackedStringArray = ["{", ' "header": %s,' % JSON.stringify(header), ' "sessions": [']
	var names: Array = recordings.keys()
	for index: int in range(names.size()):
		var recording: Dictionary = recordings[names[index]]
		var about: Dictionary = {"recording": names[index], "player": recording["player"]}
		about["characters"] = recording["characters"]
		lines.append('  {"about": %s, "rows": [' % JSON.stringify(about))
		var rows: PackedStringArray = []
		for row: Dictionary in rows_of(recording, data):
			rows.append("   " + JSON.stringify(_words(row)))
		lines.append(",\n".join(rows))
		lines.append("  ]}" + ("," if index < names.size() - 1 else ""))
	lines.append(" ]")
	lines.append("}")
	return "\n".join(lines) + "\n"


# A row as its situation's words, then its action.
static func _words(row: Dictionary) -> Array:
	var words: Array = []
	for feature: String in FightSituation.FEATURES:
		words.append(row["situation"][feature])
	words.append(row["action"])
	words.append(row["frame"])
	return words


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
