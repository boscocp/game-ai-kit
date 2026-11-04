# The minimal example on docs/techniques/ai_constraints.md, run by
# rooms_example_test.gd. A dungeon of four rooms in a row, and three things
# to put in them -- a key, the chest it opens, the guard of the chest --
# said as what must hold, not as how to place them.
extends Node

const ROOMS: Array[String] = ["hall", "library", "cellar", "tower"]

var _problem := ConstraintProblem.new()


func _ready() -> void:
	# Each thing may go in any room, by its index along the row.
	for thing: String in ["key", "chest", "guard"]:
		_problem.add_variable(thing, range(ROOMS.size()))
	# The key comes before the chest, so the player finds it first.
	_problem.add_binary("key", "chest", func(key: int, chest: int) -> bool: return key < chest, "key first")
	# The guard stands in the chest's room or the one beside it.
	_problem.add_binary("guard", "chest", func(guard: int, chest: int) -> bool: return absi(guard - chest) <= 1, "guarded")
	# Not where the key is: the player must be able to take it.
	_problem.add_binary("guard", "key", func(guard: int, key: int) -> bool: return guard != key, "key free")
	# Global, checked on each partial answer: the tower is used. It can only
	# say no once all three are placed, so until then it says yes.
	_problem.add_global(["key", "chest", "guard"], func(placed: Dictionary) -> bool:
		return placed.size() < 3 or placed.values().has(3), "tower used")
	# A misspelt name or an empty domain is refused here.
	if _problem.problem() != "":
		push_error(_problem.problem())


## Where each thing goes, by room name, for `seed_value`; {} when no
## placement satisfies every constraint.
func place(seed_value: int) -> Dictionary:
	var solver := ConstraintSolver.new(_problem, seed_value)
	var found: Dictionary = solver.solve()
	var named: Dictionary = {}
	for thing: String in found:
		named[thing] = ROOMS[found[thing]]
	return named
