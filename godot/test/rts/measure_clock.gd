# T55: the human clock's two values measured from the owner's recordings,
# and written to the file the game reads them from.
#
# Reads every person's recording in `data/rts/` (`make record-rts`),
# replays each, and writes the median reaction and the busiest five seconds
# to `RtsHumanClock.REFERENCE_PATH`, to be committed with them. The game
# only reads that file: measuring replays every recording tick by tick,
# seconds a match, and is done here, once, never while a person plays.
#
#     ./scripts/godot --headless --path godot -s res://test/rts/measure_clock.gd
#
# Exit codes: 0 written; 1 the file could not be written; 2 no recording of
# a person to measure.
extends SceneTree


func _init() -> void:
	var measured: Dictionary = RtsClockMeasure.measured_from(RtsClockMeasure.directory())
	if measured.is_empty():
		print("no recording of a person in %s: play `make record-rts` to the end of a match first" % RtsClockMeasure.directory())
		quit(2)
		return
	var path: String = ProjectSettings.globalize_path(RtsHumanClock.REFERENCE_PATH)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		print("could not write %s" % path)
		quit(1)
		return
	file.store_string(JSON.stringify(measured, "  ", true) + "\n")
	file.close()
	print("wrote %s: %.0f ms, %d commands in %.0f s -- %s" % [path, measured["reaction_ms"], measured["most_actions"],
		measured["window_seconds"], measured["source"]])
	quit(0)
