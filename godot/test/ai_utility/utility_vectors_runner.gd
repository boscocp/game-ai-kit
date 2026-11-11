# Run the conformance vectors in spec/vectors/utility against ai_utility.
#
# Thin for the same reason as the other runners: every rule it applies lives in
# `UtilityVector`, where `utility_test.gd` hands it broken vectors and
# watches it object.
#
#     ./scripts/godot --headless --path godot -s res://test/ai_utility/utility_vectors_runner.gd \
#         -- /absolute/path/to/spec/vectors/utility
#
# Exit codes: 0 every vector passes, 1 a vector failed, 2 the vectors could not
# be read -- which includes finding none at all.
extends SceneTree


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.is_empty():
		printerr("utility_vectors_runner: give me the vectors directory after `--`")
		quit(2)
		return
	quit(_run(arguments[0]))


func _run(directory: String) -> int:
	var files: PackedStringArray = _vector_files(directory)
	if files.is_empty():
		printerr("utility_vectors_runner: no .json vectors under %s" % directory)
		return 2
	var failures: Array[String] = []
	for name: String in files:
		var vector: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory + "/" + name))
		var why: String = UtilityVector.why_not_a_vector(vector, name) if vector is Dictionary else "not JSON"
		if why != "":
			printerr("utility_vectors_runner: %s is not a utility vector -- %s" % [name, why])
			return 2
		failures.append_array(UtilityVector.check(name, vector))
	for failure: String in failures:
		print(failure)
	print("utility vectors: %d file(s), %d failure(s)" % [files.size(), failures.size()])
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
