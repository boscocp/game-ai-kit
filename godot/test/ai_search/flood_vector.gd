## One flood vector of `spec/vectors/search/`: a board, a start and a limit,
## and every cell `CostFlood` must reach with what it costs.
##
## Kept apart from `SearchVector` because a flood has no goal and answers a
## map, not a route; `search_test.gd` hands it broken vectors to watch it
## object, as the runner's other rules are held.
##
## When not to use it: a route vector. Those are `SearchVector`'s.
class_name FloodVector
extends RefCounted


## Why `data` is not a flood vector, or "" when it is one.
static func why_not_a_vector(data: Dictionary) -> String:
	for field: String in ["costs", "from", "limit", "expect"]:
		if not data.has(field):
			return "no `%s` field" % field
	if not (data["expect"] is Dictionary) or not (data["expect"].get("reached") is Array):
		return "`expect` has no `reached` list"
	if (data["expect"]["reached"] as Array).is_empty():
		return "`expect.reached` is empty; the start is always reached"
	return ""


## Every way `CostFlood` differs from the file, one line each.
static func check(name: String, data: Dictionary) -> Array[String]:
	var graph: GakGridGraph = SearchVector.board_of(data)
	var from := Vector2i(int(data["from"][0]), int(data["from"][1]))
	var reached: Dictionary[Vector2i, int] = CostFlood.within(GridSearchGraph.new(graph), from, int(data["limit"]))
	var expected: Array = data["expect"]["reached"]
	var problems: Array[String] = []
	if reached.size() != expected.size():
		problems.append("%s/flood: reached %d cells, the file says %d" % [name, reached.size(), expected.size()])
	for entry: Array in expected:
		var cell := Vector2i(int(entry[0]), int(entry[1]))
		if reached.get(cell, -1) != int(entry[2]):
			problems.append("%s/flood: %s costs %s, the file says %d" % [name, cell, reached.get(cell, "nothing"), int(entry[2])])
	return problems
