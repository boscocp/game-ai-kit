# Run the conformance vectors in spec/vectors/racing3d against RaceDriver3D.
#
# Thin for the same reason as the other runners: every rule it applies lives
# in `Racing3DVector`, where `racing3d_vector_test.gd` hands it broken
# vectors and watches it object.
#
#     ./scripts/godot --headless --path godot -s res://test/racing3d/racing3d_vectors_runner.gd \
#         -- /absolute/path/to/spec/vectors/racing3d
#
# Any engine error while it runs is a failure (`Racing3DErrors`): a key a
# vector lacks used to print a SCRIPT ERROR and end "0 failure(s)".
#
# Exit codes: 0 every vector passes, 1 a vector failed or an engine error
# was logged, 2 the vectors could not be read -- which includes finding none
# at all.
extends SceneTree

var _errors := Racing3DErrors.new()


func _init() -> void:
	OS.add_logger(_errors)
	var planted: String = _errors.self_check()
	if planted != "":
		printerr(planted)
		quit(1)
		return
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.is_empty():
		printerr("racing3d_vectors_runner: give me the vectors directory after `--`")
		quit(2)
		return
	quit(_run(arguments[0]))


func _run(directory: String) -> int:
	var files: PackedStringArray = _vector_files(directory)
	if files.is_empty():
		printerr("racing3d_vectors_runner: no .json vectors under %s" % directory)
		return 2
	var failures: Array[String] = []
	for name: String in files:
		var vector: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory + "/" + name))
		if not (vector is Dictionary) or Racing3DVector.why_not_a_vector(vector) != "":
			printerr("racing3d_vectors_runner: %s is not a racing vector" % name)
			return 2
		failures.append_array(Racing3DVector.check(name, vector))
	var engine: String = _errors.finding("the vectors")
	if engine != "":
		failures.append(engine)
	for failure: String in failures:
		print(failure)
	print("racing3d vectors: %d file(s), %d failure(s)" % [files.size(), failures.size()])
	return 1 if not failures.is_empty() else 0


func _vector_files(directory: String) -> PackedStringArray:
	var found := PackedStringArray()
	var folder: DirAccess = DirAccess.open(directory)
	if folder == null:
		return found
	for name: String in folder.get_files():
		if name.ends_with(".json"):
			found.append(name)
	found.sort()
	return found
