# Run the conformance vectors in spec/vectors/search against all four searches.
#
# The vectors sit outside the Godot project on purpose: the Python side of the
# kit is held to the same answers, and a file inside `res://` would quietly
# become the addon's property. Godot reads an absolute path happily in a
# non-exported build -- measured on 4.7.2 -- so the directory arrives as a
# command-line argument after `--`.
#
#     ./scripts/godot --headless --path godot -s res://test/vectors_runner.gd \
#         -- /absolute/path/to/spec/vectors/search
#
# This file is deliberately thin. Every rule it enforces lives in
# `SearchVector`, where `search_vector_test.gd` can hand it broken vectors and
# watch it object -- a review deleted three of those rules one at a time, from
# here, and every gate stayed green. `lint-selftests` could not have helped:
# it only ever looks inside `scripts/`, and this is GDScript.
#
# Exit codes: 0 every vector passes, 1 a vector failed, 2 the vectors could not
# be read -- which includes finding none at all. A conformance run that
# inspects nothing and reports success is the failure this whole repository is
# arranged against.
extends SceneTree


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.is_empty():
		printerr("vectors_runner: give me the vectors directory after `--`")
		quit(2)
		return
	quit(_run(arguments[0]))


func _run(directory: String) -> int:
	var files: PackedStringArray = _vector_files(directory)
	if files.is_empty():
		printerr("vectors_runner: no .json vectors under %s" % directory)
		return 2

	var searches: Dictionary = {
		"breadth_first": BreadthFirstSearch.new(),
		"depth_first": DepthFirstSearch.new(),
		"dijkstra": DijkstraSearch.new(),
		"astar": AStarSearch.new(),
	}
	var failures: Array[String] = []
	for name: String in files:
		var vector: Dictionary = _read_vector(directory + "/" + name)
		if vector.is_empty():
			printerr("vectors_runner: %s is not readable JSON" % name)
			return 2
		var wrong: String = SearchVector.why_not_a_vector(vector)
		if wrong != "":
			printerr("vectors_runner: %s is not a search vector -- %s" % [name, wrong])
			return 2
		failures += SearchVector.check(name, vector, searches)

	for failure: String in failures:
		print(failure)
	print("search vectors: %d file(s), %d failure(s)" % [files.size(), failures.size()])
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


func _read_vector(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}
