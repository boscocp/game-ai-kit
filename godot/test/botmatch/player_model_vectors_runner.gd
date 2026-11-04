# Run the conformance vectors in spec/vectors/player_model against Godot's
# `PlayerModel` (T100).
#
# Each vector is the person's events and every interval's reading over
# them -- the counts, the share, the hit rate, the row and its aim error;
# `PlayerModel.replay` must reproduce them through the bot match's own
# table. The Python half is `python/tests/test_player_model_vectors.py`;
# the answers came from neither, from `spec/vectors/player_model/derive.py`.
#
#     ./scripts/godot --headless --path godot -s res://test/botmatch/player_model_vectors_runner.gd \
#         -- /absolute/path/to/spec/vectors/player_model
#
# Exit codes: 0 every reading matches, 1 one did not, 2 the vectors could
# not be read -- which includes finding none, because a conformance run
# that inspects nothing and reports success is the failure this repository
# is arranged against.
extends SceneTree

const FIELDS: Array[String] = ["description", "last_step", "events", "readings"]
## As near as a share must come: the file writes Python's doubles in full,
## and both sides do the same arithmetic.
const CLOSE: float = 1e-12


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.is_empty():
		printerr("player_model_vectors_runner: give me the vectors directory after `--`")
		quit(2)
		return
	quit(_run(arguments[0]))


func _run(directory: String) -> int:
	var files: PackedStringArray = _vector_files(directory)
	if files.is_empty():
		printerr("player_model_vectors_runner: no .json vectors under %s" % directory)
		return 2
	var rules := MatchRules.new()
	var failures: Array[String] = []
	var readings: int = 0
	for name: String in files:
		var vector: Dictionary = _read_vector(directory + "/" + name)
		if not vector.has_all(FIELDS) or (vector["readings"] as Array).is_empty():
			printerr("player_model_vectors_runner: %s is missing one of %s, or has no reading" % [name, FIELDS])
			return 2
		readings += (vector["readings"] as Array).size()
		failures += check_vector(name, vector, rules)
	for failure: String in failures:
		print(failure)
	print("player model vectors: %d file(s), %d reading(s), %d failure(s)" % [files.size(), readings, failures.size()])
	return 1 if not failures.is_empty() else 0


## What differs between the model and the vector, at the first reading it does.
static func check_vector(file: String, vector: Dictionary, rules: MatchRules) -> Array[String]:
	var interval_steps: int = roundi(float(rules.difficulty["interval"]) / rules.step)
	var found: Array[Dictionary] = PlayerModel.replay(rules.difficulty, vector["events"], int(vector["last_step"]),
			interval_steps)
	var wanted: Array = vector["readings"]
	if found.size() != wanted.size():
		return ["%s: %d reading(s), the vector has %d" % [file, found.size(), wanted.size()]]
	for index: int in range(found.size()):
		var differs: String = _reading_differs(found[index], wanted[index])
		if differs != "":
			return ["%s: step %d -- %s" % [file, int(wanted[index]["step"]), differs]]
	return []


static func _reading_differs(found: Dictionary, wanted: Dictionary) -> String:
	if int(found["step"]) != int(wanted["step"]):
		return "read at step %d" % found["step"]
	for count: String in wanted["counts"]:
		if int(found["counts"][count]) != int(wanted["counts"][count]):
			return "%s %d, the vector %d" % [count, found["counts"][count], wanted["counts"][count]]
	for share: String in ["share", "hit_rate"]:
		if absf(float(found[share]) - float(wanted[share])) > CLOSE:
			return "%s %.15f, the vector %.15f" % [share, found[share], wanted[share]]
	if int(found["row"]) != int(wanted["row"]) or float(found["aim_error_degrees"]) != float(wanted["aim_error_degrees"]):
		return "row %d (%.1f degrees), the vector %d" % [found["row"], found["aim_error_degrees"], wanted["row"]]
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
