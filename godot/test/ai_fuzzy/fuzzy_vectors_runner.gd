# Run the conformance vectors in spec/vectors/fuzzy against ai_fuzzy.
#
# Thin for the same reason as the other three: every rule it applies lives in
# `FuzzyVector`, where `fuzzy_vector_test.gd` hands it broken vectors and
# watches it object.
#
#     ./scripts/godot --headless --path godot -s res://test/ai_fuzzy/fuzzy_vectors_runner.gd \
#         -- /absolute/path/to/spec/vectors/fuzzy
#
# Exit codes: 0 every vector passes, 1 a vector failed, 2 the vectors could not
# be read -- which includes finding none at all.
extends SceneTree


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.is_empty():
		printerr("fuzzy_vectors_runner: give me the vectors directory after `--`")
		quit(2)
		return
	quit(_run(arguments[0]))


func _run(directory: String) -> int:
	var files: PackedStringArray = _vector_files(directory)
	if files.is_empty():
		printerr("fuzzy_vectors_runner: no .json vectors under %s" % directory)
		return 2

	var failures: Array[String] = []
	var cases: int = 0
	for name: String in files:
		var vector: Dictionary = _read_vector(directory + "/" + name)
		if vector.is_empty():
			printerr("fuzzy_vectors_runner: %s is not readable JSON" % name)
			return 2
		var wrong: String = FuzzyVector.why_not_a_vector(vector)
		if wrong != "":
			printerr("fuzzy_vectors_runner: %s is not a fuzzy vector -- %s" % [name, wrong])
			return 2
		cases += (vector["cases"] as Array).size()
		failures += FuzzyVector.check(name, vector)

	for failure: String in failures:
		print(failure)
	print("fuzzy vectors: %d file(s), %d case(s), %d failure(s)" % [
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
