# Run the conformance vectors in spec/vectors/valley against Godot's
# `ValleyRules`, `Standing`, `DeedLog` and `ValleySave` (T164).
#
# A `rebuilt` vector is a record of deeds and the world and the standing at
# the end of every day; the rules rebuilding each day from the record must
# reproduce them. A `refused` vector is a saved record's lines and the word
# its refusal must name. The Python half is
# `python/tests/test_valley_vectors.py`; the answers came from neither, from
# `spec/vectors/valley/derive.py`.
#
#     ./scripts/godot --headless --path godot -s res://test/valley/valley_vectors_runner.gd \
#         -- /absolute/path/to/spec/vectors/valley
#
# Exit codes: 0 every vector holds, 1 one did not, 2 the vectors could not
# be read -- which includes finding none, because a conformance run that
# inspects nothing and reports success is the failure this repository is
# arranged against.
extends SceneTree

## Every field each kind reads and its type, checked before any is read
## (T121): a cast that fails in a `-s` script is a SCRIPT ERROR the run
## survives. A world is a fact's name and whether it holds; a standing, a
## virtue's name and its sum.
const SHAPES: Dictionary = {
	"rebuilt": {
		"description": VectorShape.TEXT, "days": VectorShape.NUMBER,
		"deeds": [{"day": VectorShape.NUMBER, "verb": VectorShape.TEXT, "place": VectorShape.TEXT}],
		"worlds": [{"*": VectorShape.FLAG}], "standing": [{"*": VectorShape.NUMBER}],
	},
	"refused": {"description": VectorShape.TEXT, "lines": [VectorShape.TEXT], "names": VectorShape.TEXT},
}


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.is_empty():
		printerr("valley_vectors_runner: give me the vectors directory after `--`")
		quit(2)
		return
	quit(_run(arguments[0]))


func _run(directory: String) -> int:
	var files: PackedStringArray = _vector_files(directory)
	if files.is_empty():
		printerr("valley_vectors_runner: no .json vectors under %s" % directory)
		return 2
	var rules := ValleyRules.new()
	var standing := Standing.new()
	var failures: Array[String] = []
	var counted: Dictionary = {"rebuilt": 0, "refused": 0}
	for name: String in files:
		var vector: Dictionary = _read_vector(directory + "/" + name)
		var kind: String = str(vector.get("kind", ""))
		var why: String = VectorShape.why_not(vector, SHAPES[kind], name) if SHAPES.has(kind) else name + " has no known kind"
		if why == "" and not _names_something(vector):
			why = name + " names nothing"
		if why != "":
			printerr("valley_vectors_runner: %s" % why)
			return 2
		counted[kind] += 1
		if kind == "rebuilt":
			failures += check_rebuilt(name, vector, rules, standing)
		else:
			failures += check_refused(name, vector, rules)
	for failure: String in failures:
		print(failure)
	print("valley vectors: %d rebuilt, %d refused, %d failure(s)" % [counted["rebuilt"], counted["refused"], failures.size()])
	return 1 if not failures.is_empty() else 0


## What differs between the rebuilt days and the vector, at the first day
## it does: a fact or a virtue.
static func check_rebuilt(file: String, vector: Dictionary, rules: ValleyRules, standing: Standing) -> Array[String]:
	var record: DeedLog = rules.new_record()
	for deed: Dictionary in vector["deeds"]:
		var why: String = record.append(deed)
		if why != "":
			return ["%s: the record refused %s -- %s" % [file, deed, why]]
	for day: int in range(1, int(vector["days"]) + 1):
		var world: ValleyWorld = rules.rebuild(record, day)
		var differs: String = _facts_differ(world.facts, vector["worlds"][day - 1])
		if differs != "":
			return ["%s: day %d -- %s" % [file, day, differs]]
		var sums: Dictionary = standing.of(record.cut(day))
		var wanted: Dictionary = vector["standing"][day - 1]
		if _standing_differs(sums, wanted):
			return ["%s: day %d -- standing %s, the vector %s" % [file, day, sums, wanted]]
	return []


## Whether the refusal of the vector's lines names what the vector says,
## read as lines and as the file that holds them, a newline after each.
static func check_refused(file: String, vector: Dictionary, rules: ValleyRules) -> Array[String]:
	var lines := PackedStringArray(vector["lines"])
	var as_lines: String = ValleySave.read_lines(lines, rules.new_record())
	var as_text: String = ValleySave.read_text("\n".join(lines) + "\n", rules.new_record())
	for why: String in [as_lines, as_text]:
		if not str(vector["names"]) in why:
			return ["%s: refused with \"%s\", which does not name %s" % [file, why, vector["names"]]]
	return []


# A refused vector whose `names` is empty would hold any refusal, and a
# good record too: "" is in every string.
static func _names_something(vector: Dictionary) -> bool:
	return str(vector.get("kind")) != "refused" or str(vector.get("names", "")).strip_edges() != ""


static func _standing_differs(sums: Dictionary, wanted: Dictionary) -> bool:
	if sums.size() != wanted.size():
		return true
	for virtue: String in wanted:
		if int(sums.get(virtue, 0)) != int(wanted[virtue]):
			return true
	return false


static func _facts_differ(found: Dictionary, wanted: Dictionary) -> String:
	if found.size() != wanted.size():
		return "%d facts, the vector has %d" % [found.size(), wanted.size()]
	for name: String in wanted:
		if not found.has(name) or bool(found[name]) != bool(wanted[name]):
			return "%s is %s, the vector %s" % [name, found.get(name), wanted[name]]
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
