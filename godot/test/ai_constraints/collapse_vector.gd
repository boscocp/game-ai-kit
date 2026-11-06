## One wave function collapse vector from spec/vectors/constraints/collapse:
## whether it is one, the collapse it describes, and which of its claims a
## collapse fails. The runner and `collapse_vector_test.gd` both read through
## it, so the rules the suite plants broken vectors against are the runner's.
class_name CollapseVector
extends RefCounted

const KEYS: Array[String] = ["attempts", "collapsed", "contradictions", "description", "height", "map", "pinned",
		"restarts", "seed", "tiles", "width"]


## Why `vector` is not a usable vector, or "" when it is one -- the same
## rules, C1 to C6, as `test_constraints_collapse.py`.
static func why_not_a_vector(vector: Dictionary) -> String:
	var keys: Array = vector.keys()
	keys.sort()
	if keys != KEYS:
		return "C1 its keys are %s, not %s" % [keys, KEYS]
	var wrong_tiles: String = TileGrid.why_not({"tiles": vector["tiles"]})
	if wrong_tiles != "":
		return "C2 its tiles are not a tile set: %s" % wrong_tiles
	if not _pins_fit(vector):
		return "C3 it pins a cell off the map, or to a tile not in its set"
	if (vector["contradictions"] as Array).size() != int(vector["restarts"]):
		return "C4 its restarts do not count the contradictions it names"
	if (vector["map"] == null) != (int(vector["restarts"]) == int(vector["attempts"])):
		return "C5 it has a map and no attempt left, or no map and attempts to spare"
	if vector["map"] != null and (vector["collapsed"] as Array).size() != int(vector["width"]) * int(vector["height"]):
		return "C6 its map was finished without collapsing every cell"
	return ""


## The collapse the vector describes, recording its steps; `collapse` is a
## planted subclass's instance to configure instead, when given.
static func collapse_of(vector: Dictionary, collapse: WaveCollapse = null) -> WaveCollapse:
	var made: WaveCollapse = collapse if collapse != null else WaveCollapse.new(problem_of(vector), weights_of(vector))
	made.first_seed = int(vector["seed"])
	made.attempts = int(vector["attempts"])
	made.record = true
	return made


## The problem the vector's tile set declares on its grid.
static func problem_of(vector: Dictionary) -> ConstraintProblem:
	return TileGrid.problem({"tiles": vector["tiles"]}, _size(vector), vector["pinned"])


## The vector's tile -> weight.
static func weights_of(vector: Dictionary) -> Dictionary:
	return TileGrid.weights_of({"tiles": vector["tiles"]})


## Every claim of `vector` that `collapse` does not reproduce.
static func wrong_claims(vector: Dictionary, collapse: WaveCollapse) -> Array[String]:
	var found: Dictionary = collapse.solve()
	var drawn: Variant = TileGrid.rows_of(found, _size(vector)) if not found.is_empty() else null
	var collapsed: Array = collapse.chosen() if not found.is_empty() else []
	var wanted_map: Variant = Array(vector["map"]) if vector["map"] != null else null
	var claims: Array = [["map", drawn, wanted_map], ["collapsed", collapsed, vector["collapsed"]],
			["restarts", collapse.restarts, int(vector["restarts"])],
			["contradictions", Array(collapse.contradictions), vector["contradictions"]]]
	var wrong: Array[String] = []
	for claim: Array in claims:
		if not _same(claim[1], claim[2]):
			wrong.append("%s: %s, the vector says %s" % claim)
	return wrong


# Equal as JSON would be: a typed array and the untyped one JSON reads.
static func _same(got: Variant, wanted: Variant) -> bool:
	return JSON.stringify(got) == JSON.stringify(wanted)


static func _size(vector: Dictionary) -> Vector2i:
	return Vector2i(int(vector["width"]), int(vector["height"]))


# Every pinned cell is on the map, and pinned only to tiles in the set.
static func _pins_fit(vector: Dictionary) -> bool:
	var tiles: Dictionary = weights_of(vector)
	for name: String in vector["pinned"]:
		var cell: Vector2i = TileGrid.cell_of(name)
		if not Rect2i(Vector2i.ZERO, _size(vector)).has_point(cell):
			return false
		if (vector["pinned"][name] as Array).any(func(tile: Variant) -> bool: return not tiles.has(tile)):
			return false
	return true
