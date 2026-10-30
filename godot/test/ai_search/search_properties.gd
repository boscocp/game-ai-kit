# The property an A* must have, asserted over many boards rather than inspected
# on one.
#
# A single example proves an implementation works on that example. These two
# claims are about *every* board, so they are checked on a few hundred of them,
# generated from a fixed seed so a failure can be reproduced exactly:
#
#   1. with an admissible heuristic, A* returns a route of the same cost as
#      Dijkstra. If this breaks, A* is fast and quietly wrong, which is the
#      worst of the three outcomes;
#   2. A* expands no more cells than Dijkstra. This is why anybody pays for the
#      heuristic, and it holds because Manhattan distance on a grid whose cells
#      cost at least one is not merely admissible but consistent.
#
# Run directly rather than through gdUnit4, because T3's acceptance needs a
# command with an exit code and this is one:
#
#     ./scripts/godot --headless --path godot -s res://test/ai_search/search_properties.gd
extends SceneTree

const TRIALS: int = 300
const SEED: int = 20261012
const SIZE: int = 9
const DEAREST_GROUND: int = 9

# Roughly this share of cells are walls. High enough that a goal is sometimes
# unreachable, which is a case worth generating rather than avoiding.
const WALL_CHANCE: float = 0.22


func _init() -> void:
	var failures: Array[String] = _run_trials()
	for failure: String in failures:
		print(failure)
	print("search properties: %d trials, %d failure(s)" % [TRIALS, failures.size()])
	quit(1 if not failures.is_empty() else 0)


func _run_trials() -> Array[String]:
	var random := RandomNumberGenerator.new()
	random.seed = SEED
	var dijkstra := DijkstraSearch.new()
	var astar := AStarSearch.new()
	var failures: Array[String] = []

	for trial: int in range(TRIALS):
		var graph: GakGridGraph = _random_board(random)
		var from := Vector2i(random.randi_range(0, SIZE - 1), random.randi_range(0, SIZE - 1))
		var to := Vector2i(random.randi_range(0, SIZE - 1), random.randi_range(0, SIZE - 1))
		if graph.is_blocked(from) or graph.is_blocked(to):
			continue
		failures += _compare(trial, graph, from, to, dijkstra, astar)

	return failures


# Both searches on one board, and what they disagreed about.
func _compare(trial: int, graph: GakGridGraph, from: Vector2i, to: Vector2i,
		dijkstra: DijkstraSearch, astar: AStarSearch) -> Array[String]:
	var slow: SearchResult = dijkstra.search(GridSearchGraph.new(graph), from, to)
	var quick: SearchResult = astar.search(GridSearchGraph.new(graph), from, to)
	var problems: Array[String] = []

	if slow.reached != quick.reached:
		problems.append(
			"trial %d %s->%s: dijkstra reached=%s, astar reached=%s"
			% [trial, from, to, slow.reached, quick.reached]
		)
		return problems
	if slow.reached and slow.cost != quick.cost:
		problems.append(
			"trial %d %s->%s: dijkstra cost %d, astar cost %d -- the heuristic is not admissible"
			% [trial, from, to, slow.cost, quick.cost]
		)
	if quick.expanded.size() > slow.expanded.size():
		problems.append(
			"trial %d %s->%s: astar expanded %d, dijkstra only %d"
			% [trial, from, to, quick.expanded.size(), slow.expanded.size()]
		)
	return problems


# A board of random ground, never cheaper than one -- which is the condition
# the heuristic's admissibility rests on, stated in astar.gd.
func _random_board(random: RandomNumberGenerator) -> GakGridGraph:
	var graph := GakGridGraph.new(SIZE, SIZE)
	for y: int in range(SIZE):
		for x: int in range(SIZE):
			_fill_cell(graph, random, Vector2i(x, y))
	return graph


func _fill_cell(graph: GakGridGraph, random: RandomNumberGenerator, cell: Vector2i) -> void:
	if random.randf() < WALL_CHANCE:
		graph.block(cell)
		return
	graph.set_cost(cell, random.randi_range(GakGridGraph.DEFAULT_COST, DEAREST_GROUND))
