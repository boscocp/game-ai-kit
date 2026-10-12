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
# Exit codes: 0 every vector passes, 1 a vector failed, 2 the vectors could not
# be read -- which includes finding none at all. A conformance run that
# inspects nothing and reports success is the failure this whole repository is
# arranged against.
extends SceneTree

const BFS_STEPS: String = "fewest_steps"
const CHEAPEST: String = "cheapest_cost"


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

	var failures: Array[String] = []
	for name: String in files:
		var vector: Dictionary = _read_vector(directory + "/" + name)
		if vector.is_empty():
			printerr("vectors_runner: %s is not readable JSON" % name)
			return 2
		# A JSON file that is a dictionary and nothing else used to reach the
		# board builder and crash it with a stack trace. Pointing this runner
		# at the wrong directory is an ordinary mistake and deserves a sentence.
		var wrong: String = _why_not_a_vector(vector)
		if wrong != "":
			printerr("vectors_runner: %s is not a search vector -- %s" % [name, wrong])
			return 2
		failures += _check_vector(name, vector)

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


# Why this dictionary is not a vector, or "" when it is one.
func _why_not_a_vector(vector: Dictionary) -> String:
	for field: String in ["costs", "from", "to", "expect"]:
		if not vector.has(field):
			return "no `%s` field" % field
	if not (vector["costs"] is Array) or (vector["costs"] as Array).is_empty():
		return "`costs` is not a non-empty array of rows"
	if not ((vector["costs"] as Array)[0] is Array):
		return "`costs` is not row-major: its first entry is not a row"
	for field: String in ["from", "to"]:
		if not (vector[field] is Array) or (vector[field] as Array).size() != 2:
			return "`%s` is not a [x, y] pair" % field
	if not (vector["expect"] is Dictionary) or not (vector["expect"] as Dictionary).has("reached"):
		return "`expect` has no `reached`"
	return ""


# Every claim one vector makes, checked against every search.
func _check_vector(name: String, vector: Dictionary) -> Array[String]:
	var graph: GridGraph = _board_of(vector)
	var from := Vector2i(int(vector["from"][0]), int(vector["from"][1]))
	var to := Vector2i(int(vector["to"][0]), int(vector["to"][1]))
	var expected: Dictionary = vector["expect"]
	var problems: Array[String] = []

	var results: Dictionary = {
		"breadth_first": BreadthFirstSearch.new().search(graph, from, to),
		"depth_first": DepthFirstSearch.new().search(graph, from, to),
		"dijkstra": DijkstraSearch.new().search(graph, from, to),
		"astar": AStarSearch.new().search(graph, from, to),
	}
	for label: String in results:
		problems += _check_one(name, label, results[label], graph, from, expected)
	return problems


func _check_one(name: String, label: String, result: SearchResult, graph: GridGraph,
		from: Vector2i, expected: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	var should_reach: bool = expected["reached"]

	if result.reached != should_reach:
		problems.append("%s/%s: reached=%s, expected %s"
			% [name, label, result.reached, should_reach])
		return problems
	if not should_reach:
		return _check_failure(name, label, result)

	var unwalkable: String = _why_unwalkable(graph, from, result.path)
	if unwalkable != "":
		problems.append("%s/%s: the path cannot be walked -- %s" % [name, label, unwalkable])
	problems += _check_numbers(name, label, result, expected)
	return problems


# The claims that are about one algorithm rather than all of them.
func _check_numbers(name: String, label: String, result: SearchResult,
		expected: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	var claims_cheapest: bool = label in ["dijkstra", "astar"] and expected.has(CHEAPEST)
	if claims_cheapest and result.cost != int(expected[CHEAPEST]):
		problems.append("%s/%s: cost %d, expected the cheapest %d"
			% [name, label, result.cost, int(expected[CHEAPEST])])

	var claims_fewest: bool = label == "breadth_first" and expected.has(BFS_STEPS)
	if claims_fewest and result.path.size() != int(expected[BFS_STEPS]):
		problems.append("%s/%s: %d steps, expected the fewest %d"
			% [name, label, result.path.size(), int(expected[BFS_STEPS])])
	return problems


func _check_failure(name: String, label: String, result: SearchResult) -> Array[String]:
	var problems: Array[String] = []
	if result.path.size() != 0:
		problems.append("%s/%s: unreachable, but returned a path" % [name, label])
	if result.cost != GridGraph.BLOCKED:
		problems.append("%s/%s: unreachable, but cost is %d" % [name, label, result.cost])
	if result.expanded.is_empty():
		problems.append("%s/%s: unreachable, and expanded nothing at all" % [name, label])
	return problems


# `costs` is row-major, and -1 is BLOCKED -- the board's own convention.
func _board_of(vector: Dictionary) -> GridGraph:
	var rows: Array = vector["costs"]
	var graph := GridGraph.new(int((rows[0] as Array).size()), rows.size())
	for y: int in range(rows.size()):
		var row: Array = rows[y]
		for x: int in range(row.size()):
			graph.set_cost(Vector2i(x, y), int(row[x]))
	return graph


func _why_unwalkable(graph: GridGraph, from: Vector2i, path: Array[Vector2i]) -> String:
	var previous: Vector2i = from
	for cell: Vector2i in path:
		if not GridGraph.DIRECTIONS.has(cell - previous):
			return "%s does not follow %s" % [cell, previous]
		if graph.is_blocked(cell):
			return "%s is blocked" % cell
		previous = cell
	return ""
