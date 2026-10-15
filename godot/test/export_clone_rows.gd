# T18: replay every recorded fight and write the rows behaviour cloning
# learns from -- one per decision of the recorded player.
#
#     ./scripts/godot --headless --path godot -s res://test/export_clone_rows.gd \
#         -- /absolute/path/to/data/fights /absolute/path/to/data/cloning/rows.json [--check]
#
# The rows are cut here, in GDScript, because only GDScript can replay a
# fight: Python never sees one. `FightRecording.rows_of` does the cutting and
# `FightSituation` writes each situation, the same function the cloned
# opponent asks in the game. With `--check` nothing is written: the rows are
# cut again and compared with the file, so rows that have fallen behind the
# recordings, or the features, are caught.
#
# Exit codes: 0 written, or up to date; 1 `--check` found the file stale;
# 2 the frame data, a recording or the arguments could not be read, or
# there were no recordings at all.
extends SceneTree


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() < 2:
		printerr("export_clone_rows: give me the recordings folder and the rows file after `--`")
		quit(2)
		return
	quit(_run(arguments[0], arguments[1], arguments.has("--check")))


func _run(folder: String, rows_path: String, checking: bool) -> int:
	var data := FightData.read()
	if data.refusal != "":
		printerr("export_clone_rows: the frame data was refused: %s" % data.refusal)
		return 2
	var refused: Array[String] = []
	var recordings: Dictionary = FightRecording.read_all(folder, refused)
	for reason: String in refused:
		printerr("export_clone_rows: not a recording -- %s" % reason)
	if not refused.is_empty() or recordings.is_empty():
		printerr("export_clone_rows: %d recording(s) under %s, %d refused" % [recordings.size(), folder, refused.size()])
		return 2
	var text: String = rows_text(recordings, data)
	if checking:
		var current: String = FileAccess.get_file_as_string(rows_path)
		var fresh: bool = current == text
		var verdict: String = "matches" if fresh else "does not match what is cut from"
		print("%s: %s %s the %d recording(s)" % ["ok" if fresh else "STALE", rows_path, verdict, recordings.size()])
		return 0 if fresh else 1
	var file: FileAccess = FileAccess.open(rows_path, FileAccess.WRITE)
	if file == null:
		printerr("export_clone_rows: cannot write %s" % rows_path)
		return 2
	file.store_string(text)
	print("export_clone_rows: %d recording(s) -> %s" % [recordings.size(), rows_path])
	return 0


## The rows file: a header, then each recording's rows, one row a line --
## its situation's words in `FightSituation.FEATURES` order, then the action
## -- so a diff of the file reads as a diff of decisions.
func rows_text(recordings: Dictionary, data: FightData) -> String:
	var header: Dictionary = {"generated_by": "godot/test/export_clone_rows.gd", "reaction": FightRecording.REACTION,
			"features": FightSituation.FEATURES, "actions": FightAction.ACTIONS}
	var lines: PackedStringArray = ["{", ' "header": %s,' % JSON.stringify(header), ' "sessions": [']
	var names: Array = recordings.keys()
	for index: int in range(names.size()):
		var recording: Dictionary = recordings[names[index]]
		var about: Dictionary = {"recording": names[index], "player": recording["player"]}
		about["characters"] = recording["characters"]
		lines.append('  {"about": %s, "rows": [' % JSON.stringify(about))
		var rows: PackedStringArray = []
		for row: Dictionary in FightRecording.rows_of(recording, data):
			rows.append("   " + JSON.stringify(_words(row)))
		lines.append(",\n".join(rows))
		lines.append("  ]}" + ("," if index < names.size() - 1 else ""))
	lines.append(" ]")
	lines.append("}")
	return "\n".join(lines) + "\n"


# A row as its situation's words, then its action.
func _words(row: Dictionary) -> Array:
	var words: Array = []
	for feature: String in FightSituation.FEATURES:
		words.append(row["situation"][feature])
	words.append(row["action"])
	return words
