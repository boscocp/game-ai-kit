## The player model's conformance vectors, read from disk for the runner and
## the suite (T100). Fixtures, never the model's state: fixed files written
## by `spec/vectors/player_model/derive.py`.
##
## A file of its own, and one that names neither the model nor
## `MatchDifficulty`, on purpose: N14 holds every script that does to
## reading no file at all, so the scripts that check the model are handed
## the vectors as dictionaries, as the match is handed its table by
## `MatchRules`. Nothing here holds or builds a model.
class_name ModelVectorFiles
extends RefCounted


## Where the vectors are, from the Godot project: `spec/` beside it.
static func directory() -> String:
	return ProjectSettings.globalize_path("res://").path_join("../spec/vectors/player_model").simplify_path()


## Every `.json` vector under `folder`, by file name, in name order; an
## unreadable one as an empty dictionary, for the caller to refuse.
static func read_all(folder: String) -> Dictionary:
	var vectors: Dictionary = {}
	var names: PackedStringArray = DirAccess.get_files_at(folder)
	names.sort()
	for name: String in names:
		if name.ends_with(".json"):
			vectors[name] = _read(folder.path_join(name))
	return vectors


# `JSON.new().parse()` rather than `JSON.parse_string()`, which prints an
# engine error of its own on a malformed file; see docs/godot/.
static func _read(path: String) -> Dictionary:
	var reader := JSON.new()
	if reader.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	return reader.data if reader.data is Dictionary else {}
