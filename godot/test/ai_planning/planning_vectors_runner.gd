# Run the conformance vectors in spec/vectors/planning against the planner.
#
# The twin of `vectors_runner.gd`, and thin for the same reason: every rule it
# applies lives in `PlanningVector`, where `planning_vector_test.gd` can hand it
# broken vectors and watch it object. A rule written here could be deleted and
# no gate in the repository would notice.
#
#     ./scripts/godot --headless --path godot -s res://test/ai_planning/planning_vectors_runner.gd \
#         -- /absolute/path/to/spec/vectors/planning
#
# Exit codes: 0 every vector passes, 1 a vector failed, 2 the vectors could not
# be read -- which includes finding none at all, because a conformance run that
# inspects nothing and reports success is the failure this repository is
# arranged against.
extends SceneTree


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.is_empty():
		printerr("planning_vectors_runner: give me the vectors directory after `--`")
		quit(2)
		return
	quit(_run(arguments[0]))


func _run(directory: String) -> int:
	var files: PackedStringArray = _vector_files(directory)
	if files.is_empty():
		printerr("planning_vectors_runner: no .json vectors under %s" % directory)
		return 2

	var planner := StripsPlanner.new()
	var failures: Array[String] = []
	for name: String in files:
		var vector: Dictionary = _read_vector(directory + "/" + name)
		if vector.is_empty():
			printerr("planning_vectors_runner: %s is not readable JSON" % name)
			return 2
		var refusal: String = _why_refused(directory, name, vector)
		if refusal != "":
			printerr(refusal)
			return 2
		failures += PlanningVector.check(name, vector, planner)

	for failure: String in failures:
		print(failure)
	print("planning vectors: %d file(s), %d failure(s)" % [files.size(), failures.size()])
	return 1 if not failures.is_empty() else 0


# Why this file cannot be used as a vector at all, as a sentence to print.
func _why_refused(directory: String, name: String, vector: Dictionary) -> String:
	var wrong: String = PlanningVector.why_not_a_vector(vector)
	if wrong != "":
		return "planning_vectors_runner: %s is not a planning vector -- %s" % [name, wrong]
	var missing: String = PlanningVector.why_files_are_missing(directory, vector)
	if missing != "":
		return "planning_vectors_runner: %s -- %s" % [name, missing]
	return ""


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


func _read_vector(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}
