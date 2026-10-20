# T18: replay every recorded fight and write the rows behaviour cloning
# learns from -- one per decision of the recorded player.
#
#     ./scripts/godot --headless --path godot -s res://test/fighting/export_clone_rows.gd \
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
	var text: String = FightRecording.rows_text(recordings, data)
	if checking:
		var fresh: bool = FileAccess.get_file_as_string(rows_path) == text
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
