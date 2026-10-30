# Run the conformance vectors in spec/vectors/director against Godot's
# `Director` (T90).
#
# Each vector is an event list, the intensity after every step and every
# phase change; a fresh `Director` stepped on the events must reproduce
# them. The Python half is `python/tests/test_director_vectors.py`; the
# answers came from neither, from `spec/vectors/director/derive.py`.
#
#     ./scripts/godot --headless --path godot -s res://test/infiltration/director_vectors_runner.gd \
#         -- /absolute/path/to/spec/vectors/director
#
# Exit codes: 0 every step matches, 1 one did not, 2 the vectors could not
# be read -- which includes finding none, because a conformance run that
# inspects nothing and reports success is the failure this repository is
# arranged against.
extends SceneTree

const FIELDS: Array[String] = ["description", "steps", "events", "intensity", "changes"]
## As near as a step's intensity must come: the file writes Python's
## doubles in full, and both sides do the same arithmetic.
const CLOSE: float = 1e-9


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.is_empty():
		printerr("director_vectors_runner: give me the vectors directory after `--`")
		quit(2)
		return
	quit(_run(arguments[0]))


func _run(directory: String) -> int:
	var files: PackedStringArray = _vector_files(directory)
	if files.is_empty():
		printerr("director_vectors_runner: no .json vectors under %s" % directory)
		return 2
	var failures: Array[String] = []
	var steps: int = 0
	for name: String in files:
		var vector: Dictionary = _read_vector(directory + "/" + name)
		if not vector.has_all(FIELDS) or int(vector["steps"]) <= 0:
			printerr("director_vectors_runner: %s is missing one of %s, or has no step" % [name, FIELDS])
			return 2
		steps += int(vector["steps"])
		failures += check_vector(name, vector)
	for failure: String in failures:
		print(failure)
	print("director vectors: %d file(s), %d step(s), %d failure(s)" % [files.size(), steps, failures.size()])
	return 1 if not failures.is_empty() else 0


## What differs between the director and the vector, at the first step it does.
static func check_vector(file: String, vector: Dictionary) -> Array[String]:
	var director := Director.new()
	var by_step: Dictionary = {}
	for event: Dictionary in vector["events"]:
		var at: int = int(event["step"])
		by_step[at] = by_step.get(at, []) + [event]
	var changes: Array = []
	for number: int in range(int(vector["steps"])):
		var before: String = director.phase
		var entered: String = director.step(by_step.get(number, []))
		if entered != "":
			changes.append({"step": number, "from": before, "to": entered})
		var wanted: float = float(vector["intensity"][number])
		if absf(director.intensity - wanted) > CLOSE:
			return ["%s: step %d -- intensity %.12f, the vector %.12f" % [file, number, director.intensity, wanted]]
	return _changes_differ(file, changes, vector["changes"])


static func _changes_differ(file: String, found: Array, wanted: Array) -> Array[String]:
	if found.size() != wanted.size():
		return ["%s: %d phase change(s), the vector has %d -- %s" % [file, found.size(), wanted.size(), found]]
	for index: int in range(found.size()):
		var change: Dictionary = wanted[index]
		var same: bool = int(change["step"]) == int(found[index]["step"]) and change["from"] == found[index]["from"] \
			and change["to"] == found[index]["to"]
		if not same:
			return ["%s: change %d is %s, the vector %s" % [file, index, found[index], change]]
	return []


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


# `JSON.new().parse()` rather than `JSON.parse_string()`, which prints an
# engine error of its own on a malformed file; see docs/godot/.
func _read_vector(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var reader := JSON.new()
	if reader.parse(file.get_as_text()) != OK:
		return {}
	return reader.data if reader.data is Dictionary else {}
