# The GDScript half of the combat conformance run (T26).
#
# Every vector in `spec/vectors/combat/` hands `TacticalCombat.fight` a list
# of rolls and says what must come out; `python/tests/test_combat_vectors.py`
# hands the same rolls to the dataset's `combat.fight`. Nothing here reads the
# Python side: the file in the middle is what the two agree about.
#
# A planted vector -- one expected number off by one -- must be caught before
# any real one is trusted.
#
#     ./scripts/godot --headless --path godot -s res://test/tactical/combat_vectors_runner.gd -- <spec/vectors/combat>
extends SceneTree

## Fewer than this and the directory is wrong, not the vectors.
const FEWEST_VECTORS: int = 7
## The types this runner reads, checked before it reads any (T121): a cast
## that fails in a `-s` script is a SCRIPT ERROR the run would survive.
const SHAPE: Dictionary = {
	"rolls": [VectorShape.NUMBER],
	"fight": {"defender_hits_back": VectorShape.FLAG, "*": VectorShape.NUMBER},
	"expect": {"attacker_won": VectorShape.FLAG, "attacker_left": VectorShape.NUMBER,
			"defender_left": VectorShape.NUMBER, "rolls_used": VectorShape.NUMBER},
}


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.is_empty():
		printerr("combat_vectors_runner: give me the vectors directory after `--`")
		quit(2)
		return
	quit(_run(arguments[0]))


func _run(directory: String) -> int:
	var vectors: Array[Dictionary] = _read(directory)
	if vectors.size() < FEWEST_VECTORS:
		printerr("combat_vectors_runner: %d vector(s) under %s, and %d is the fewest" % [
			vectors.size(), directory, FEWEST_VECTORS])
		return 2
	for vector: Dictionary in vectors:
		var why: String = VectorShape.why_not(vector, SHAPE, vector["name"])
		if why != "":
			printerr("combat_vectors_runner: %s" % why)
			return 2
	if not _planted_vector_fails(vectors[0]):
		return 1
	var failures: Array[String] = []
	for vector: Dictionary in vectors:
		failures += failures_of(vector)
	for failure: String in failures:
		print(failure)
	print("combat vectors: %d vector(s), %d failure(s)" % [vectors.size(), failures.size()])
	return 1 if not failures.is_empty() else 0


## What is wrong with the fight this vector writes down, as lines.
func failures_of(vector: Dictionary) -> Array[String]:
	var rolls: Array = vector["rolls"]
	var used: Array[int] = [0]
	var roll: Callable = func() -> int:
		used[0] += 1
		return int(rolls[used[0] - 1])
	var inputs: Dictionary = {}
	for key: String in vector["fight"]:
		inputs[key] = vector["fight"][key] if key == "defender_hits_back" else int(vector["fight"][key])
	var outcome: Dictionary = TacticalCombat.fight(inputs, roll)
	var expect: Dictionary = vector["expect"]
	var found: Array[String] = []
	for key: String in ["attacker_won", "attacker_left", "defender_left"]:
		var wanted: Variant = expect[key] if key == "attacker_won" else int(expect[key])
		if outcome[key] != wanted:
			found.append("%s: %s is %s, the vector says %s" % [vector["name"], key, outcome[key], wanted])
	if used[0] != int(expect["rolls_used"]):
		found.append("%s: used %d rolls, the vector says %d" % [vector["name"], used[0], expect["rolls_used"]])
	return found


func _planted_vector_fails(vector: Dictionary) -> bool:
	var wrong: Dictionary = vector.duplicate(true)
	wrong["expect"]["defender_left"] = int(wrong["expect"]["defender_left"]) + 1
	var caught: bool = not failures_of(wrong).is_empty()
	print("%s: planted, a defender left one off %s" % ["ok" if caught else "FAIL",
		"is caught" if caught else "passes unnoticed"])
	return caught


func _read(directory: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for file: String in Array(DirAccess.get_files_at(directory)).filter(func(name: String) -> bool: return name.ends_with(".json")):
		var vector: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join(file)))
		if vector is Dictionary:
			vector["name"] = file
			found.append(vector)
	return found
