# Run the conformance vectors in spec/vectors/maze against the GDScript maze.
#
# Each vector is a seed, the ghosts that play and Pac-Man's moves, and the
# snapshot after every step: Pac-Man's cell and facing, each ghost's cell,
# next move, how it chose it and its target, the pellets left, the mode and
# the outcome. `MazeGame` must reproduce every one. The Python half is
# `python/tests/test_maze_vectors.py`; the answers came from neither, from
# `spec/vectors/maze/derive.py`.
#
#     ./scripts/godot --headless --path godot -s res://test/maze/maze_vectors_runner.gd \
#         -- /absolute/path/to/spec/vectors/maze
#
# Exit codes: 0 every snapshot matches, 1 one did not, 2 the vectors could
# not be read -- which includes finding none, because a conformance run that
# inspects nothing and reports success is the failure this repository is
# arranged against.
extends SceneTree

## Every field this runner reads and its type, checked before it reads any
## (T121): a cast that fails in a `-s` script is a SCRIPT ERROR the run
## survives. A ghost in a snapshot is a tuple: its cell, its next move, how
## it chose it, and its target.
const SHAPE: Dictionary = {
	"description": VectorShape.TEXT, "seed": VectorShape.NUMBER, "ghosts": [VectorShape.TEXT],
	"moves": [VectorShape.TEXT],
	"trace": [{"facing": VectorShape.TEXT, "ghosts": [[VectorShape.NUMBER, VectorShape.NUMBER,
			VectorShape.TEXT, VectorShape.TEXT, VectorShape.NUMBER, VectorShape.NUMBER]], "mode": VectorShape.TEXT,
			"outcome": VectorShape.TEXT, "pacman": [VectorShape.NUMBER], "pellets": VectorShape.NUMBER}],
}


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.is_empty():
		printerr("maze_vectors_runner: give me the vectors directory after `--`")
		quit(2)
		return
	quit(_run(arguments[0]))


func _run(directory: String) -> int:
	var files: PackedStringArray = _vector_files(directory)
	if files.is_empty():
		printerr("maze_vectors_runner: no .json vectors under %s" % directory)
		return 2
	var failures: Array[String] = []
	var snapshots: int = 0
	for name: String in files:
		var vector: Dictionary = _read_vector(directory + "/" + name)
		var why: String = VectorShape.why_not(vector, SHAPE, name)
		if why != "" or (vector["trace"] as Array).is_empty():
			printerr("maze_vectors_runner: %s" % (why if why != "" else name + " has no trace"))
			return 2
		snapshots += (vector["trace"] as Array).size()
		failures += check_vector(name, vector)
	for failure: String in failures:
		print(failure)
	print("maze vectors: %d file(s), %d snapshot(s), %d failure(s)" % [files.size(), snapshots, failures.size()])
	return 1 if not failures.is_empty() else 0


## What differs between the game and the vector, at the first step it does.
static func check_vector(file: String, vector: Dictionary) -> Array[String]:
	var game := MazeGame.new(int(vector["seed"]), vector["ghosts"])
	var wanted: Array = normalised(vector["trace"])
	var found: Array = [game.snapshot()]
	for move: String in vector["moves"]:
		game.step(move)
		found.append(game.snapshot())
	if found.size() != wanted.size():
		return ["%s: %d snapshots, the vector has %d" % [file, found.size(), wanted.size()]]
	for index: int in range(found.size()):
		if JSON.stringify(found[index]) != JSON.stringify(wanted[index]):
			return ["%s: after move %d --\n  game   %s\n  vector %s" % [file, index, found[index], wanted[index]]]
	return []


## `value` with every whole float made an int: JSON reads 6 as 6.0, and the
## game's cells are ints.
static func normalised(value: Variant) -> Variant:
	if value is float and float(value) == floorf(value):
		return int(value)
	if value is Array:
		return (value as Array).map(normalised)
	if value is Dictionary:
		var copied: Dictionary = {}
		for key: Variant in value:
			copied[key] = normalised(value[key])
		return copied
	return value


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
