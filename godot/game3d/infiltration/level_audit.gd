## Which of `level_constraints.json`'s conditions a finished level breaks,
## measured on the level the game builds -- `InfiltrationLevel` and its
## `BotArena` -- and not on the solver's sketch.
##
## Two uses. It holds the solver to its word: every level `LevelConstraints`
## returns must break nothing here, so a sketch that drifted from the arena
## is caught. And it measures generate and test: how many of the levels
## `LevelGenerator.make` keeps break the two conditions it never asked for.
##
## Complexity: a few floods of the level's cells.
##
## When not to use it: inside the search. Building the arena is what the
## sketch exists to avoid.
class_name LevelAudit
extends RefCounted


## The labels of `LevelConstraintRules` that the level `data` describes
## breaks, of the five global conditions, in the file's order.
static func broken(data: Dictionary) -> Array[String]:
	var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LevelConstraints.RULES))
	var level := InfiltrationLevel.read(data)
	var arena: BotArena = level.arena
	var from_start: PackedInt32Array = arena.steps_from([level.cell_of(level.start)])
	var found: Array[String] = []
	if _steps(arena, from_start, level.cell_of(level.exit_place)) < 0:
		found.append(LevelConstraintRules.EXIT_REACHED)
	if not _places(level).all(func(place: Vector2) -> bool: return _steps(arena, from_start, level.cell_of(place)) >= 0):
		found.append(LevelConstraintRules.PLACES_REACHED)
	if _a_post_in_sight(level, float(rules["eyes"])):
		found.append(LevelConstraintRules.OUT_OF_SIGHT)
	if not _hiding_near_every_route(level, data.get("hiding", []), rules["hiding_near_route"]):
		found.append(LevelConstraintRules.HIDING_NEAR)
	if not _dark_way(level, float(rules["dark_below"])):
		found.append(LevelConstraintRules.DARK_WAY)
	return found


static func _steps(arena: BotArena, steps: PackedInt32Array, cell: Vector2i) -> int:
	return steps[cell.y * int(arena.width) + cell.x]


static func _places(level: InfiltrationLevel) -> Array[Vector2]:
	var places: Array[Vector2] = []
	for spec: Dictionary in level.guard_specs:
		places.append_array(spec["route"])
		places.append(spec["post"])
	return places


# A guard's post -- the sentry's, a patrol's first point -- on a clear line
# from the start's eyes and within its type's farthest sight.
static func _a_post_in_sight(level: InfiltrationLevel, eyes: float) -> bool:
	var sight: Dictionary = LevelConstraints.farthest_sight()
	var from: Vector3 = level.arena.above(BotArena.centre_of(level.cell_of(level.start)), eyes)
	for spec: Dictionary in level.guard_specs:
		var post: Vector2 = BotArena.centre_of(level.cell_of(spec["post"]))
		var near: bool = BotArena.centre_of(level.cell_of(level.start)).distance_to(post) <= float(sight[spec["type"]])
		if near and level.arena.first_block(from, level.arena.above(post, eyes)) >= 1.0:
			return true
	return false


static func _hiding_near_every_route(level: InfiltrationLevel, places: Array, rule: Dictionary) -> bool:
	for spec: Dictionary in level.guard_specs:
		if spec["type"] != "patrol":  # not shown: an identifier
			continue
		var sources: Array[Vector2i] = []
		for point: Vector2 in spec["route"]:
			sources.append(level.cell_of(point))
		var steps: PackedInt32Array = level.arena.steps_from(sources)
		var near: Array = places.filter(func(place: Dictionary) -> bool: return _near(level, steps, place, int(rule["steps"])))
		if near.size() < int(rule["count"]):
			return false
	return true


# Whether a cell of hiding place `place`, as `InfiltrationLevel` lays its
# cells out, is at most `most` walk steps away in `steps`.
static func _near(level: InfiltrationLevel, steps: PackedInt32Array, place: Dictionary, most: int) -> bool:
	var corner := Vector2(float(place["x"]) - float(place["width"]) / 2.0, float(place["z"]) - float(place["depth"]) / 2.0)
	var cells: Array[Vector2i] = []
	for x: int in range(int(place["width"])):
		for z: int in range(int(place["depth"])):
			cells.append(BotArena.cell_of(corner + Vector2(x + 0.5, z + 0.5)))
	return cells.any(func(cell: Vector2i) -> bool:
		var away: int = _steps(level.arena, steps, cell) if level.arena.walk.contains(cell) else -1
		return away >= 0 and away <= most)


# A way from the start to the exit through walk cells all darker than `below`.
static func _dark_way(level: InfiltrationLevel, below: float) -> bool:
	var goal: Vector2i = level.cell_of(level.exit_place)
	var waiting: Array[Vector2i] = [level.cell_of(level.start)]
	var seen: Dictionary = {waiting[0]: true}
	var head: int = 0
	while head < waiting.size():
		var cell: Vector2i = waiting[head]
		head += 1
		if level.light.at(cell) >= below or not level.walkable(cell):
			continue
		if cell == goal:
			return true
		for next: Vector2i in level.arena.walk_graph.neighbours(cell).filter(func(near: Vector2i) -> bool: return not seen.has(near)):
			seen[next] = true
			waiting.append(next)
	return false
