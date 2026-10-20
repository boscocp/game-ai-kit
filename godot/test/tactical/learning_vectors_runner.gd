# Run the conformance vectors in spec/vectors/learning against ai_learning.
#
# The third of its kind, and thin for the same reason as the other two: every
# rule it applies lives in `LearningVector`, where `learning_vector_test.gd`
# can hand it broken vectors and watch it object. A rule written here could be
# deleted and no gate in the repository would notice.
#
#     ./scripts/godot --headless --path godot -s res://test/tactical/learning_vectors_runner.gd \
#         -- /absolute/path/to/spec/vectors/learning
#
# Exit codes: 0 every vector passes, 1 a vector failed, 2 the vectors could not
# be read -- which includes finding none at all, because a conformance run that
# inspects nothing and reports success is the failure this repository is
# arranged against.
extends SceneTree


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.is_empty():
		printerr("learning_vectors_runner: give me the vectors directory after `--`")
		quit(2)
		return
	quit(_run(arguments[0]))


func _run(directory: String) -> int:
	var files: PackedStringArray = _vector_files(directory)
	if files.is_empty():
		printerr("learning_vectors_runner: no .json vectors under %s" % directory)
		return 2

	var failures: Array[String] = []
	var cases: int = 0
	for name: String in files:
		var vector: Dictionary = _read_vector(directory + "/" + name)
		if vector.is_empty():
			printerr("learning_vectors_runner: %s is not readable JSON" % name)
			return 2
		var wrong: String = LearningVector.why_not_a_vector(vector)
		if wrong != "":
			printerr("learning_vectors_runner: %s is not a learning vector -- %s" % [name, wrong])
			return 2
		cases += (vector["cases"] as Array).size()
		failures += LearningVector.check(name, vector)

	for failure: String in failures:
		print(failure)
	print("learning vectors: %d file(s), %d case(s), %d failure(s)" % [
		files.size(), cases, failures.size(),
	])
	return 1 if not failures.is_empty() else 0


func _vector_files(directory: String) -> PackedStringArray:
	var folder: DirAccess = DirAccess.open(directory)
	if folder == null:
		return PackedStringArray()
	var found := PackedStringArray()
	for name: String in folder.get_files():
		if name.ends_with(".json"):
			found.append(name)
	found.sort()
	return found


# The vector at this path, or {} when it cannot be read as an object.
#
# `JSON.new().parse()` rather than `JSON.parse_string()`: the static one
# prints an engine error of its own before returning null, so a malformed
# vector produced a stack trace followed by this runner's own message saying
# the same thing. Measured on the pinned engine; see docs/godot/.
func _read_vector(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var reader := JSON.new()
	if reader.parse(file.get_as_text()) != OK:
		return {}
	return reader.data if reader.data is Dictionary else {}
