# Four claims about perception, asserted over generated maps rather than one.
#
#   1. sight is symmetric: if A sees B, B sees A. Bresenham's line alone is
#      not, which is why `LineOfSight` always draws it from the same end;
#   2. a wall or a tree on the line between two cells blocks sight from both
#      sides -- and on a board with nothing opaque, every cell sees every
#      other, so a sight that never sees anything cannot pass;
#   3. suspicion never falls while the player is in sight, whatever the
#      distance, light and noise of each turn;
#   4. on a danger map, each guard's own cell holds the map's maximum.
#
# And one the others lean on: the line itself is checked against geometry
# rather than against the code that drew it -- one cell per step along the
# longer axis, each within half a cell of the true segment. Property 2 picks
# its wall from `cells_between`, so without this a line drawn in the wrong
# place would agree with itself and pass.
#
# Fixed seed, so a failure reproduces exactly. Run directly, because T14's
# acceptance is a command with an exit code:
#
#     ./scripts/godot --headless --path godot -s res://test/perception_properties.gd
extends SceneTree

const TRIALS: int = 300
const SEED: int = 20261013
const SIZE: int = 12

# A route strength up to two is passed on purpose: the map promises to clamp
# into [0, 1], and without the clamp a route could outrank a guard.
#
# A share of cells made walls, and a share made trees. Enough that lines are
# often blocked, which is the case worth generating.
const WALL_CHANCE: float = 0.12
const TREE_CHANCE: float = 0.08

# Turns of observation per suspicion trial.
const TURNS: int = 30


func _init() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = SEED
	var failures: Array[String] = []
	for trial: int in range(TRIALS):
		var graph: GridGraph = _random_map(random)
		var one := _random_cell(random)
		var other := _random_cell(random)
		failures += _the_line_follows_the_segment(trial, one, other)
		failures += _nothing_opaque_hides_nothing(trial, one, other)
		failures += _sight_is_symmetric(trial, graph, one, other)
		failures += _a_wall_blocks_both_ways(trial, graph.duplicate_graph(), one, other, random)
		failures += _suspicion_holds_while_seen(trial, random)
		failures += _a_guard_s_cell_is_the_most_dangerous(trial, graph, random)
	for failure: String in failures:
		print(failure)
	print("perception properties: %d trials, %d failure(s)" % [TRIALS, failures.size()])
	quit(1 if not failures.is_empty() else 0)


func _the_line_follows_the_segment(trial: int, one: Vector2i, other: Vector2i) -> Array[String]:
	var cells: Array[Vector2i] = LineOfSight.cells_between(one, other)
	var span: Vector2i = (other - one).abs()
	var longer: int = maxi(span.x, span.y)
	if cells.size() != maxi(longer - 1, 0):
		return ["trial %d: %d cells between %s and %s, not %d" % [trial, cells.size(), one, other, longer - 1]]
	for cell: Vector2i in cells:
		if _off_the_segment(one, other, cell):
			return ["trial %d: %s is not on the line from %s to %s" % [trial, cell, one, other]]
	return []


# More than half a cell from the true segment, measured across the longer axis.
func _off_the_segment(one: Vector2i, other: Vector2i, cell: Vector2i) -> bool:
	var along_x: bool = absi(other.x - one.x) >= absi(other.y - one.y)
	var progress: float = float(cell.x - one.x) / (other.x - one.x) if along_x \
			else float(cell.y - one.y) / (other.y - one.y)
	var expected: Vector2 = Vector2(one).lerp(Vector2(other), progress)
	var drift: float = absf(cell.y - expected.y) if along_x else absf(cell.x - expected.x)
	return progress <= 0.0 or progress >= 1.0 or drift > 0.5 + 1e-9


func _nothing_opaque_hides_nothing(trial: int, one: Vector2i, other: Vector2i) -> Array[String]:
	if LineOfSight.clear(GridGraph.new(SIZE, SIZE), one, other):
		return []
	return ["trial %d: on an empty board %s does not see %s" % [trial, one, other]]


func _sight_is_symmetric(trial: int, graph: GridGraph, one: Vector2i, other: Vector2i) -> Array[String]:
	if LineOfSight.clear(graph, one, other) == LineOfSight.clear(graph, other, one):
		return []
	return ["trial %d: %s and %s disagree about whether they see each other" % [trial, one, other]]


func _a_wall_blocks_both_ways(trial: int, graph: GridGraph, one: Vector2i, other: Vector2i,
		random: RandomNumberGenerator) -> Array[String]:
	var between: Array[Vector2i] = LineOfSight.cells_between(one, other)
	if between.is_empty():
		return []
	var wall: Vector2i = between[random.randi_range(0, between.size() - 1)]
	if random.randf() < 0.5:
		graph.block(wall)
	else:
		graph.set_cost(wall, LineOfSight.DEFAULT_OPAQUE_FROM_COST)
	if not LineOfSight.clear(graph, one, other) and not LineOfSight.clear(graph, other, one):
		return []
	return ["trial %d: a wall at %s between %s and %s let sight through" % [trial, wall, one, other]]


func _suspicion_holds_while_seen(trial: int, random: RandomNumberGenerator) -> Array[String]:
	var suspicion := Suspicion.new()
	for turn: int in range(TURNS):
		var seen: bool = random.randf() < 0.6
		var before: float = suspicion.level
		var noise: float = random.randf() if random.randf() < 0.3 else 0.0
		suspicion.observe(seen, random.randf_range(0.0, Suspicion.SIGHT), random.randf(), noise)
		if seen and suspicion.level < before:
			var message: String = "trial %d turn %d: suspicion fell from %.3f to %.3f in sight"
			return [message % [trial, turn, before, suspicion.level]]
	return []


func _a_guard_s_cell_is_the_most_dangerous(trial: int, graph: GridGraph,
		random: RandomNumberGenerator) -> Array[String]:
	# Reach 0 one time in ten: the guard then sees only its own cell, and that
	# cell must still be the map's maximum.
	var reach: float = 0.0 if random.randf() < 0.1 else random.randf_range(2.0, 8.0)
	var cone := VisionCone.new(reach, random.randf_range(20.0, 180.0))
	var eyes: Array[Vector2i] = [_random_cell(random), _random_cell(random)]
	var facings: Array[Vector2i] = [GridGraph.DIRECTIONS[random.randi_range(0, 3)], Vector2i.ZERO]
	var map := InfluenceMap.of_watchers(graph, cone, eyes, facings)
	map.raise_along([_random_cell(random), _random_cell(random)] as Array[Vector2i], random.randf_range(0.0, 2.0))
	for eye: Vector2i in eyes:
		if map.value_at(eye) < map.strongest():
			var message: String = "trial %d: a guard at %s holds %.3f, the map's maximum is %.3f"
			return [message % [trial, eye, map.value_at(eye), map.strongest()]]
	return []


func _random_map(random: RandomNumberGenerator) -> GridGraph:
	var graph := GridGraph.new(SIZE, SIZE)
	for y: int in range(SIZE):
		for x: int in range(SIZE):
			_roll_cell(graph, Vector2i(x, y), random.randf())
	return graph


func _roll_cell(graph: GridGraph, cell: Vector2i, roll: float) -> void:
	if roll < WALL_CHANCE:
		graph.block(cell)
	elif roll < WALL_CHANCE + TREE_CHANCE:
		graph.set_cost(cell, LineOfSight.DEFAULT_OPAQUE_FROM_COST)


func _random_cell(random: RandomNumberGenerator) -> Vector2i:
	return Vector2i(random.randi_range(0, SIZE - 1), random.randi_range(0, SIZE - 1))
