# Run the conformance vectors in spec/vectors/menace against the GDScript
# MENACE player.
#
# Each case gives a board, the box it must fold into, the box's beads and a
# uniform draw, and the real square MENACE must play -- or null when the box
# is empty. The draw is in the file because Python's random generator and
# Godot's differ, so a seed could not be what the two sides agree on.
#
#     ./scripts/godot --headless --path godot -s res://test/menace_vectors_runner.gd \
#         -- /absolute/path/to/spec/vectors/menace
#
# Exit codes: 0 every case passes, 1 a case failed, 2 the vectors could not
# be read -- which includes finding none at all, because a conformance run
# that inspects nothing and reports success is the failure this repository is
# arranged against.
extends SceneTree

const FIELDS: Array[String] = ["name", "board", "box", "beads", "draw", "move"]


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.is_empty():
		printerr("menace_vectors_runner: give me the vectors directory after `--`")
		quit(2)
		return
	quit(_run(arguments[0]))


func _run(directory: String) -> int:
	var files: PackedStringArray = _vector_files(directory)
	if files.is_empty():
		printerr("menace_vectors_runner: no .json vectors under %s" % directory)
		return 2
	var failures: Array[String] = []
	var cases: int = 0
	for name: String in files:
		var found: Array = _cases_in(_read_vector(directory + "/" + name))
		if found.is_empty():
			printerr("menace_vectors_runner: %s has no cases, or a case without %s" % [name, FIELDS])
			return 2
		cases += found.size()
		for case: Dictionary in found:
			failures += check_case(name, case)
	for failure: String in failures:
		print(failure)
	print("menace vectors: %d file(s), %d case(s), %d failure(s)" % [files.size(), cases, failures.size()])
	return 1 if not failures.is_empty() else 0


# The vector's cases, or [] when it has none or one is missing a field.
func _cases_in(vector: Dictionary) -> Array:
	var cases: Variant = vector.get("cases")
	if not cases is Array:
		return []
	for case: Variant in cases:
		if not case is Dictionary or not (case as Dictionary).has_all(FIELDS):
			return []
	return cases


## What is wrong with one case, checked against the file and nothing else.
static func check_case(file: String, case: Dictionary) -> Array[String]:
	var label: String = "%s: %s" % [file, case["name"]]
	var box: String = TicTacToeBoard.canonical(case["board"])[0]
	if box != case["box"]:
		return ["%s -- folds into box %s, the vector says %s" % [label, box, case["box"]]]
	var player: MenacePlayer = MenacePlayer.with_box(box, case["beads"])
	var move: int = player.move_for(0, case["board"], float(case["draw"]))
	var wanted: int = -1 if case["move"] == null else int(case["move"])
	if move != wanted:
		return ["%s -- plays %d, the vector says %d" % [label, move, wanted]]
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
