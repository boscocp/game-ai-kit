# Run the conformance vectors in spec/vectors/perception against ai_perception.
#
# Thin for the same reason as the other runners: every rule it applies lives
# in `PerceptionVector`, where `perception_vector_test.gd` hands it broken
# vectors and watches it object. Engine errors are counted too: a SCRIPT
# ERROR aborts the function it is in and the script would still print
# "0 failure(s)" (CLAUDE.md's trap).
#
#     ./scripts/godot --headless --path godot -s res://test/ai_perception/perception_vectors_runner.gd \
#         -- /absolute/path/to/spec/vectors/perception
#
# Exit codes: 0 every vector passes, 1 a vector failed or the engine reported
# an error, 2 the vectors could not be read -- which includes finding none.
extends SceneTree

var _errors := PerceptionErrors.new()


func _init() -> void:
	OS.add_logger(_errors)
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.is_empty():
		printerr("perception_vectors_runner: give me the vectors directory after `--`")
		quit(2)
		return
	quit(_run(arguments[0]))


func _run(directory: String) -> int:
	var files: PackedStringArray = _vector_files(directory)
	if files.is_empty():
		printerr("perception_vectors_runner: no .json vectors under %s" % directory)
		return 2
	var failures: Array[String] = []
	var counter: String = _errors.self_check()
	if counter != "":
		failures.append(counter)
	for name: String in files:
		var vector: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory + "/" + name))
		var why: String = PerceptionVector.why_not_a_vector(vector, name) if vector is Dictionary else "not JSON"
		if why != "":
			printerr("perception_vectors_runner: %s is not a perception vector -- %s" % [name, why])
			return 2
		failures.append_array(PerceptionVector.check(name, vector))
	if _errors.count > 0:
		failures.append("%d engine error(s) while answering the vectors" % _errors.count)
	for failure: String in failures:
		print(failure)
	print("perception vectors: %d file(s), %d failure(s)" % [files.size(), failures.size()])
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
