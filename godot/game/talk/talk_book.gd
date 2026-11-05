## The recorded conversations, as the lines a player may choose next.
##
## Recorded mode plays with no model at all (tier 2; its Python replay is
## tier 1). The lines on offer are the ones a local model was once really
## asked, read from `data/talk/recordings/` at the top of the repository,
## outside the Godot project as ADR 0017 keeps recordings. After the player
## has said some lines, the choices are the next line of every recording
## that began with those same lines, so recordings that share a beginning
## branch where they part. The answer to a chosen line is the model's text
## recorded for it, handed to a `RecordedRuntime` and so to the validator
## exactly as a live answer would be: this file never reads it.
##
## Two recordings may share a beginning and differ in what the model said
## to it; the first, by file name, answers. Played straight through, a
## recording gives its own answers -- which is what the vectors check.
##
## When not to use it: in an exported game, which has no `data/` beside it;
## the book is then empty and the demo says so.
class_name TalkBook
extends RefCounted

## The recordings of one language, each `{name, players, texts}`, by file name.
var recordings: Array[Dictionary] = []


## Where the recordings live: `data/talk/recordings/` beside `godot/`.
static func folder() -> String:
	return ProjectSettings.globalize_path("res://").path_join("../data/talk/recordings").simplify_path()


## The recordings in `directory` whose `language` is `language`.
static func load_from(directory: String, language: String) -> TalkBook:
	var book := TalkBook.new()
	var names: PackedStringArray = DirAccess.get_files_at(directory)
	names.sort()
	for name: String in names:
		if not name.ends_with(".json"):
			continue
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join(name)))
		if data is Dictionary and (data as Dictionary).get("language") == language:
			book.recordings.append(_entry(name, data))
	return book


## The lines a player who has said `path` may say next, in file order, once each.
func choices(path: PackedStringArray) -> PackedStringArray:
	var lines := PackedStringArray()
	for recording: Dictionary in recordings:
		var next: String = _next_line(recording["players"], path)
		if next != "" and not lines.has(next):
			lines.append(next)
	return lines


## A runtime that answers `line`, said after `path`, as the first recording
## that has it was answered; one that fails the request when none has.
func runtime_for(path: PackedStringArray, line: String) -> RecordedRuntime:
	var asked: PackedStringArray = path.duplicate()
	asked.append(line)
	for recording: Dictionary in recordings:
		if _begins_with(recording["players"], asked):
			return RecordedRuntime.new(PackedStringArray([recording["texts"][path.size()]]))
	return RecordedRuntime.new()


# One recording's player lines and model texts, side by side.
static func _entry(name: String, data: Dictionary) -> Dictionary:
	var players := PackedStringArray()
	var texts := PackedStringArray()
	for turn: Variant in data.get("turns", []):
		if turn is Dictionary and turn.get("player") is String and turn.get("raw") is String:
			players.append(turn["player"])
			texts.append(turn["raw"])
	return {"name": name, "players": players, "texts": texts}


# The line `players` said after `path`, or "" when it did not begin so.
static func _next_line(players: PackedStringArray, path: PackedStringArray) -> String:
	if players.size() <= path.size() or not _begins_with(players, path):
		return ""
	return players[path.size()]


static func _begins_with(lines: PackedStringArray, start: PackedStringArray) -> bool:
	if lines.size() < start.size():
		return false
	for index: int in start.size():
		if lines[index] != start[index]:
			return false
	return true
