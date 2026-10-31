# Run the conformance vectors in spec/vectors/squad against the GDScript shot.
#
# Each vector is a small map, a shooter, a target and a die; `SquadCover`
# and `SquadCombat` must come to the cover, the flank, the chance, the hit
# and the health it wrote down by hand. The Python half is
# `python/tests/test_squad_vectors.py`; `squad_vectors_test.gd` runs this
# same check as a gdUnit suite.
#
#     ./scripts/godot --headless --path godot -s res://test/squad/squad_vectors_runner.gd \
#         -- /absolute/path/to/spec/vectors/squad
#
# Exit codes: 0 every vector matches, 1 one did not, 2 the vectors could not
# be read -- which includes finding none, because a conformance run that
# inspects nothing and reports success is the failure this repository is
# arranged against.
extends SceneTree

const FIELDS: Array[String] = ["description", "map", "shooter", "target", "roll", "expected"]


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.is_empty():
		printerr("squad_vectors_runner: give me the vectors directory after `--`")
		quit(2)
		return
	quit(_run(arguments[0]))


func _run(directory: String) -> int:
	var files: PackedStringArray = vector_files(directory)
	if files.is_empty():
		printerr("squad_vectors_runner: no .json vectors under %s" % directory)
		return 2
	var failures: Array[String] = []
	for name: String in files:
		var vector: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join(name)))
		if not vector is Dictionary or not (vector as Dictionary).has_all(FIELDS):
			printerr("squad_vectors_runner: %s is not a vector with %s" % [name, FIELDS])
			return 2
		failures += check_vector(name, vector)
	for failure: String in failures:
		print(failure)
	print("squad vectors: %d file(s), %d failure(s)" % [files.size(), failures.size()])
	return 1 if not failures.is_empty() else 0


## The vector files in `directory`, sorted.
static func vector_files(directory: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for name: String in DirAccess.get_files_at(directory):
		if name.ends_with(".json"):
			found.append(name)
	found.sort()
	return found


## What the game makes of one vector, or nothing when it is the vector's.
static func check_vector(file: String, vector: Dictionary) -> Array[String]:
	var found: Dictionary = outcome(vector)
	var wanted: Dictionary = vector["expected"]
	for field: String in ["cover", "flanked", "chance", "hit", "target_left"]:
		if JSON.stringify(found[field]) != JSON.stringify(_whole(wanted[field])):
			return ["%s: %s is %s, the vector has %s" % [file, field, found[field], wanted[field]]]
	return []


## The cover, the flank and the shot, worked out by `SquadCover` and
## `SquadCombat` from the vector's map, pieces and die.
static func outcome(vector: Dictionary) -> Dictionary:
	var rows: Array[String] = []
	rows.assign(vector["map"])
	var shooter: Dictionary = vector["shooter"]
	var target: Dictionary = vector["target"]
	var covered: Dictionary = SquadCover.of(rows, _cell(shooter["cell"]), _cell(target["cell"]))
	var inputs: Dictionary = {
		"aim": SquadTable.number(shooter["type"], "aim"),
		"defence": SquadTable.number(target["type"], "defence"),
		"cover": covered["cover"],
		"damage": SquadTable.number(shooter["type"], "damage"),
		"target_health": int(target["health"]),
	}
	var fired: Dictionary = SquadCombat.shot(inputs, int(vector["roll"]))
	return {"cover": covered["cover"], "flanked": covered["flanked"], "chance": fired["chance"],
		"hit": fired["hit"], "target_left": fired["target_left"]}


static func _cell(pair: Array) -> Vector2i:
	return Vector2i(int(pair[0]), int(pair[1]))


# JSON reads 7 as 7.0; the game's numbers are ints.
static func _whole(value: Variant) -> Variant:
	return int(value) if value is float else value
