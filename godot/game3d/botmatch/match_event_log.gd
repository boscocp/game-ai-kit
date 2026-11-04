## A bot match's events, kept (T100): what condition 3 of ADR 0016's
## amendment replays. The person's bot's shots, hits, hurts, kills and
## deaths, in order, each with the step it happened in, and the seed and
## arena the match was played from.
##
## Events, not counts: the player model is rebuilt from them by
## `PlayerModel.replay`, and nothing here reads one back into a model. It is
## its own file because N14 holds the model and every script naming it to
## writing nothing; this writer is neither, and writes only what ADR 0017
## allows -- nothing unless the match was opened with `-- --record`
## (`make record-botmatch`), and the screen says so.
##
## When not to use it: as a save game. A log is read by a test or a person,
## never by the match at start.
class_name MatchEventLog
extends RefCounted

## Where logs are kept: this checkout's own `user://` (ADR 0022), so a
## person's play is never committed by accident.
const FOLDER: String = "user://botmatch-logs"
## Where the test suites write theirs: gdUnit4 empties `user://tmp` after
## every suite.
const TESTS: String = "user://tmp/botmatch-logs"
## Asked for on the command line, after `--`.
const ASKED: String = "--record"


## Whether this run was opened to record.
static func asked() -> bool:
	return OS.get_cmdline_user_args().has(ASKED)


## The log of `world`, as a dictionary: the seed and arena it was played
## from, the length of a step in seconds, the last step it ran, the
## difficulty table it read through, and the person's events -- enough for
## `PlayerModel.replay` to rebuild every reading from the log alone.
static func of(world: BotMatch, seed_value: int, arena: String) -> Dictionary:
	return {"seed": seed_value, "arena": arena, "step": world.rules.step, "last_step": world.steps_done - 1,
			"difficulty": world.rules.difficulty, "events": world.person_events}


## Write `match_log` to `folder` as `name`.json, or named for the moment when
## `name` is "". Its path is returned; "" when there were no events to keep
## or the file could not be written.
static func save(match_log: Dictionary, folder: String = FOLDER, name: String = "") -> String:
	if (match_log["events"] as Array).is_empty():
		return ""
	DirAccess.make_dir_recursive_absolute(folder)
	if name == "":
		name = "%s-%d" % [Time.get_datetime_string_from_system().replace(":", "-"), Time.get_ticks_msec()]
	var path: String = folder.path_join(name + ".json")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(JSON.stringify(match_log) + "\n")
	return path


## A log written by `save`, read back with its numbers as written: each
## event's step an int, as the match counted it. Empty when unreadable.
static func read(path: String) -> Dictionary:
	var reader := JSON.new()
	if reader.parse(FileAccess.get_file_as_string(path)) != OK or not reader.data is Dictionary:
		return {}
	var match_log: Dictionary = reader.data
	var events: Array[Dictionary] = []
	for event: Dictionary in match_log.get("events", []):
		events.append({"step": int(event["step"]), "kind": str(event["kind"]), "points": int(event["points"])})
	match_log["events"] = events
	match_log["seed"] = int(match_log["seed"])
	match_log["last_step"] = int(match_log["last_step"])
	return match_log
