## One conformance vector: the board it describes and the claims it makes.
##
## This is separate from the runner that reads the files because a runner is a
## `SceneTree` and a `SceneTree` is awkward to test. The rules live here, where
## a test suite can hand them a deliberately broken vector and watch them say
## so.
##
## `lint-selftests` was never going to do it: `run_selftests.py` runs every
## script **in `scripts/`** that offers a `--self-test`, and insists on one from
## anything named `check_*.py`. It does not look outside `scripts/` and it runs
## Python and shell, so a gate written in GDScript under `godot/` is invisible
## to it whatever it is called.
##
## That mattered: a review deleted three of the runner's rules one at a time and
## every gate stayed green.
##
## When not to use it: anything but search vectors. The shape is specific and
## is documented in `spec/vectors/search/README.md`.
class_name SearchVector
extends RefCounted

const CHEAPEST: String = "cheapest_cost"
const FEWEST: String = "fewest_steps"


## Why this dictionary is not a usable vector, or "" when it is one.
##
## Every rule here was added because something got through: a JSON file that is
## a dictionary and nothing else used to reach the board builder and crash it,
## rows of different lengths were padded or truncated in silence, and a `from`
## off the board produced a conforming vector whose path walked in from nowhere.
static func why_not_a_vector(data: Dictionary) -> String:
	var shape: String = _why_shape_is_wrong(data)
	if shape != "":
		return shape
	var rows: Array = data["costs"]
	var width: int = (rows[0] as Array).size()
	for index: int in range(rows.size()):
		var row: Array = rows[index]
		if row.size() != width:
			return "row %d has %d cells and row 0 has %d" % [index, row.size(), width]
		var cell: String = _why_row_is_wrong(row, index)
		if cell != "":
			return cell
	return _why_ends_are_wrong(data, width, rows.size())


## The board this vector describes. `costs` is row-major and -1 is BLOCKED.
static func board_of(data: Dictionary) -> GakGridGraph:
	var rows: Array = data["costs"]
	var graph := GakGridGraph.new(int((rows[0] as Array).size()), rows.size())
	for y: int in range(rows.size()):
		var row: Array = rows[y]
		for x: int in range(row.size()):
			graph.set_cost(Vector2i(x, y), int(row[x]))
	return graph


## Everything this vector claims, checked against all four searches.
static func check(name: String, data: Dictionary, searches: Dictionary) -> Array[String]:
	var graph: GakGridGraph = board_of(data)
	var from := Vector2i(int(data["from"][0]), int(data["from"][1]))
	var to := Vector2i(int(data["to"][0]), int(data["to"][1]))
	var expected: Dictionary = data["expect"]
	var problems: Array[String] = []

	for label: String in searches:
		var search: GakSearch = searches[label]
		problems += _check_one(
			name, label, search.search(GridSearchGraph.new(graph), from, to), graph, from, to, expected
		)
	return problems


static func _why_shape_is_wrong(data: Dictionary) -> String:
	for field: String in ["costs", "from", "to", "expect"]:
		if not data.has(field):
			return "no `%s` field" % field
	if not (data["costs"] is Array) or (data["costs"] as Array).is_empty():
		return "`costs` is not a non-empty array of rows"
	var rows: Array = data["costs"]
	if not (rows[0] is Array) or (rows[0] as Array).is_empty():
		return "`costs` is not row-major: its first entry is not a non-empty row"
	for field: String in ["from", "to"]:
		if not (data[field] is Array) or (data[field] as Array).size() != 2:
			return "`%s` is not an [x, y] pair" % field
	if not (data["expect"] is Dictionary) or not (data["expect"] as Dictionary).has("reached"):
		return "`expect` has no `reached`"
	return ""


# A cost is BLOCKED or at least one. GakGridGraph clamps anything between, so a
# vector written with a 0 would silently become a 1 and still "conform".
static func _why_row_is_wrong(row: Array, index: int) -> String:
	for x: int in range(row.size()):
		var cost: int = int(row[x])
		if cost != GakGridGraph.BLOCKED and cost < GakGridGraph.DEFAULT_COST:
			return "cell (%d, %d) costs %d; use -1 for a wall or at least 1" % [x, index, cost]
	return ""


static func _why_ends_are_wrong(data: Dictionary, width: int, height: int) -> String:
	var board := GakGridGraph.new(width, height)
	for field: String in ["from", "to"]:
		var cell := Vector2i(int(data[field][0]), int(data[field][1]))
		if not board.contains(cell):
			return "`%s` is %s, which is not on a %dx%d board" % [field, cell, width, height]
	return ""


static func _check_one(name: String, label: String, result: SearchResult, graph: GakGridGraph,
		from: Vector2i, to: Vector2i, expected: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	var should_reach: bool = expected["reached"]

	if result.reached != should_reach:
		return ["%s/%s: reached=%s, expected %s" % [name, label, result.reached, should_reach]]
	if not result.expanded.has(from):
		problems.append("%s/%s: never looked at the cell it started on" % [name, label])
	if not should_reach:
		return problems + _check_failure(name, label, result)

	var unwalkable: String = _why_unwalkable(graph, from, result.path)
	if unwalkable != "":
		problems.append("%s/%s: the path cannot be walked -- %s" % [name, label, unwalkable])
	var astray: String = _why_it_does_not_arrive(from, to, result.path)
	if astray != "":
		problems.append("%s/%s: the path does not arrive -- %s" % [name, label, astray])
	return problems + _check_numbers(name, label, result, expected)


static func _check_numbers(name: String, label: String, result: SearchResult,
		expected: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	var claims_cheapest: bool = label in ["dijkstra", "astar"] and expected.has(CHEAPEST)
	if claims_cheapest and result.cost != int(expected[CHEAPEST]):
		problems.append("%s/%s: cost %d, expected the cheapest %d"
			% [name, label, result.cost, int(expected[CHEAPEST])])

	var claims_fewest: bool = label == "breadth_first" and expected.has(FEWEST)
	if claims_fewest and result.path.size() != int(expected[FEWEST]):
		problems.append("%s/%s: %d steps, expected the fewest %d"
			% [name, label, result.path.size(), int(expected[FEWEST])])
	return problems


static func _check_failure(name: String, label: String, result: SearchResult) -> Array[String]:
	var problems: Array[String] = []
	if result.path.size() != 0:
		problems.append("%s/%s: unreachable, but returned a path" % [name, label])
	if result.cost != SearchResult.NO_ROUTE:
		problems.append("%s/%s: unreachable, but cost is %d" % [name, label, result.cost])
	return problems


# Where the path finishes, which nothing here used to look at.
#
# Every other rule in this file is about the *steps*: that each one follows the
# last and lands on ground a unit may enter. All of them hold for a path that
# walks somewhere else entirely, so a search could report `reached` and hand
# back a legal stroll to the wrong cell and conform. The same shape as the
# finding the wave 08 review recorded about `from`: every step was legal, and
# the ends were nobody's business.
#
# An empty path is the one case with two readings, and the contract in
# `pathfinder.gd` settles it: a search that starts on its goal has no steps to
# report, and anything else with no steps did not arrive.
static func _why_it_does_not_arrive(from: Vector2i, to: Vector2i,
		path: Array[Vector2i]) -> String:
	if path.is_empty():
		if from == to:
			return ""
		return "it has no steps, and %s is not %s" % [from, to]
	var last: Vector2i = path[path.size() - 1]
	if last != to:
		return "it ends on %s, and the goal is %s" % [last, to]
	return ""


static func _why_unwalkable(graph: GakGridGraph, from: Vector2i,
		path: Array[Vector2i]) -> String:
	var previous: Vector2i = from
	for cell: Vector2i in path:
		if not GakGridGraph.DIRECTIONS.has(cell - previous):
			return "%s does not follow %s" % [cell, previous]
		if graph.is_blocked(cell):
			return "%s is blocked" % cell
		previous = cell
	return ""
