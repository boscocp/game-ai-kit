## The constraints of `level_constraints.json`, written as tests a
## `ConstraintProblem` can call: what `LevelConstraints` declares a level to
## be, one function each, in the file's order.
##
## The binary ones are tests of two candidates and are what AC-3 propagates.
## The global ones are tests of a partial level, worked out on the
## `LevelSketch` from the boxes and lamps placed so far, and each says no
## only when nothing placed later could make it yes.
##
## When not to use it: outside `LevelConstraints`; it reads that class's
## variables by name.
class_name LevelConstraintRules
extends RefCounted

const BOXES_APART: String = "boxes apart"  # shown through tr()
const OFF_THE_BOXES: String = "not under a box"  # shown through tr()
const PLACES_APART: String = "one guard place a cell"  # shown through tr()
const HIDING_APART: String = "hiding places apart"  # shown through tr()
const LAMPS_APART: String = "lamps apart"  # shown through tr()
const EXIT_REACHED: String = "the exit can be walked to"  # shown through tr()
const PLACES_REACHED: String = "every guard place can be walked to"  # shown through tr()
const OUT_OF_SIGHT: String = "no post in sight of the start"  # shown through tr()
const HIDING_NEAR: String = "a hiding place near each route"  # shown through tr()
const DARK_WAY: String = "a dark way to the exit"  # shown through tr()
## Every rule there is, binary first; `level_constraints.json` names, by
## these labels, the ones a level is declared with.
const LABELS: Array[String] = [BOXES_APART, OFF_THE_BOXES, PLACES_APART, HIDING_APART, LAMPS_APART,
		EXIT_REACHED, PLACES_REACHED, OUT_OF_SIGHT, HIDING_NEAR, DARK_WAY]


## Declare on `level`'s problem each constraint its rules file names under
## `constraints`, in the file's order, and list it in `level.declared`. A
## constraint left out of the list is not asked for; a name no rule here
## has is an error, said and skipped.
static func add(level: LevelConstraints) -> void:
	for label: String in level.rules["constraints"]:
		if not LABELS.has(label):
			push_error("level_constraints.json names '%s', which no rule declares" % label)  # not shown: a developer's message
			continue
		_declare(level, label)
		level.declared.append(label)


static func _declare(level: LevelConstraints, label: String) -> void:
	var guard_places: Array[String] = _guard_places(level)
	var problem: ConstraintProblem = level.problem
	match label:
		BOXES_APART:
			_binary_pairs(level, level.boxes, level.boxes, label, _boxes_apart.bind(level))
		OFF_THE_BOXES:
			_binary_pairs(level, guard_places + level.hiding, level.boxes, label, _off_the_box.bind(level))
		PLACES_APART:
			_binary_pairs(level, guard_places, guard_places, label, _apart_cells.bind(level))
		HIDING_APART:
			_binary_pairs(level, level.hiding, level.hiding, label, _hiding_apart.bind(level))
		LAMPS_APART:
			_binary_pairs(level, level.lamps, level.lamps, label, _lamps_apart.bind(level))
		EXIT_REACHED:
			problem.add_global(level.boxes.duplicate(), _exit_reached.bind(level), label)
		PLACES_REACHED:
			problem.add_global(level.boxes + guard_places, _places_reached.bind(level, guard_places), label)
		OUT_OF_SIGHT:
			problem.add_global(level.boxes + _posts(level), _out_of_sight.bind(level), label)
		HIDING_NEAR:
			_hiding_near_every_route(level, label)
		DARK_WAY:
			problem.add_global(level.boxes + level.lamps, _dark_way.bind(level), label)


# One "hiding place near" constraint for each patrol's route.
static func _hiding_near_every_route(level: LevelConstraints, label: String) -> void:
	for route: Array[String] in level.routes:
		level.problem.add_global(level.boxes + level.hiding + route, _hiding_near.bind(level, route), label)


# One binary constraint for each pair of a name in `firsts` and one in
# `seconds` -- each pair once when the two lists are the same. `test` is
# asked once for every pair of candidates, here, and kept as a table: AC-3
# and LCV ask the same pairs many times over.
static func _binary_pairs(level: LevelConstraints, firsts: Array[String], seconds: Array[String], label: String,
		test: Callable) -> void:
	var same: bool = firsts == seconds
	for index: int in range(firsts.size()):
		for other: int in range(index + 1 if same else 0, seconds.size()):
			_add_pair(level, firsts[index], seconds[other], label, test)


static func _add_pair(level: LevelConstraints, first: String, second: String, label: String, test: Callable) -> void:
	var table: PackedByteArray = _table(level, first, second, test)
	var count: int = (level.candidates[second] as Array).size()
	level.problem.add_binary(first, second, func(value: int, other_value: int) -> bool:
		return table[value * count + other_value] == 1, label)


# `test` on every pair of the two variables' candidates, row by row.
static func _table(level: LevelConstraints, first: String, second: String, test: Callable) -> PackedByteArray:
	var count: int = (level.candidates[second] as Array).size()
	var table := PackedByteArray()
	table.resize((level.candidates[first] as Array).size() * count)
	for value: int in range((level.candidates[first] as Array).size()):
		for other_value: int in range(count):
			table[value * count + other_value] = 1 if test.call(first, value, second, other_value) else 0
	return table


static func _guard_places(level: LevelConstraints) -> Array[String]:
	var places: Array[String] = []
	for route: Array[String] in level.routes:
		places.append_array(route)
	places.append(level.sentry)
	return places


# The posts a guard stands at first: the sentry's, and each patrol's first point.
static func _posts(level: LevelConstraints) -> Array[String]:
	var posts: Array[String] = [level.sentry]
	for route: Array[String] in level.routes:
		posts.append(route[0])
	return posts


# -- binary ---------------------------------------------------------------------

static func _boxes_apart(first: String, value: int, second: String, other_value: int, level: LevelConstraints) -> bool:
	var apart: float = float(level.rules["boxes_apart"])
	return not _footprint(level.candidates[first][value]).grow(apart).intersects(_footprint(level.candidates[second][other_value]))


static func _off_the_box(place: String, value: int, box: String, box_value: int, level: LevelConstraints) -> bool:
	var under: Dictionary = level.cells_under_box(box, box_value)
	return not _cells_of(level, place, value).any(func(cell: Vector2i) -> bool: return under.has(cell))


static func _apart_cells(first: String, value: int, second: String, other_value: int, level: LevelConstraints) -> bool:
	return level.cell_of(first, value) != level.cell_of(second, other_value)


static func _hiding_apart(first: String, value: int, second: String, other_value: int, level: LevelConstraints) -> bool:
	return not _footprint(level.candidates[first][value]).intersects(_footprint(level.candidates[second][other_value]))


static func _lamps_apart(first: String, value: int, second: String, other_value: int, level: LevelConstraints) -> bool:
	var lamp: Dictionary = level.candidates[first][value]
	var other_lamp: Dictionary = level.candidates[second][other_value]
	var away: float = Vector2(lamp["x"], lamp["z"]).distance_to(Vector2(other_lamp["x"], other_lamp["z"]))
	return away >= float(level.rules["lamps_apart"])


static func _footprint(thing: Dictionary) -> Rect2:
	var size := Vector2(float(thing["width"]), float(thing["depth"]))
	return Rect2(Vector2(float(thing["x"]), float(thing["z"])) - size / 2.0, size)


# The cells a place covers: one for a guard's, four for a hiding place.
static func _cells_of(level: LevelConstraints, name: String, value: int) -> Array[Vector2i]:
	var centre: Vector2i = level.cell_of(name, value)
	if not level.hiding.has(name):
		return [centre]
	return [centre + Vector2i(-1, -1), centre + Vector2i(0, -1), centre + Vector2i(-1, 0), centre]


# -- global ---------------------------------------------------------------------

static func _exit_reached(partial: Dictionary, level: LevelConstraints) -> bool:
	var steps: PackedInt32Array = _walk_from_start(partial, level)
	return level.sketch.steps_to(steps, level.sketch.exit_cell) >= 0


static func _places_reached(partial: Dictionary, level: LevelConstraints, places: Array[String]) -> bool:
	var steps: PackedInt32Array = _walk_from_start(partial, level)
	for name: String in places:
		if partial.has(name) and level.sketch.steps_to(steps, level.cell_of(name, partial[name])) < 0:
			return false
	return true


# Only once every box is placed can a post be said to be in sight: before
# then, a box still to come might stand in the way.
static func _out_of_sight(partial: Dictionary, level: LevelConstraints) -> bool:
	if not level.boxes.all(func(name: String) -> bool: return partial.has(name)):
		return true
	var boxes: Array[Dictionary] = _placed(partial, level, level.boxes)
	var start := Vector2(level.sketch.start) + Vector2(0.5, 0.5)
	for name: String in _posts(level):
		if not partial.has(name):
			continue
		var cell: Vector2i = level.cell_of(name, partial[name])
		var reach: float = level.sight_of("sentry" if name == level.sentry else "patrol")  # not shown: an identifier
		var near: bool = start.distance_to(Vector2(cell) + Vector2(0.5, 0.5)) <= reach
		if near and level.sketch.clear_from_start(cell, boxes, float(level.rules["eyes"])):
			return false
	return true


# Counted with the boxes placed so far, which only ever lengthen a walk, and
# with every hiding place not yet placed taken as near: an upper bound.
static func _hiding_near(partial: Dictionary, level: LevelConstraints, route: Array[String]) -> bool:
	if not route.all(func(name: String) -> bool: return partial.has(name)):
		return true
	var rule: Dictionary = level.rules["hiding_near_route"]
	var sources: Array[Vector2i] = []
	for name: String in route:
		sources.append(level.cell_of(name, partial[name]))
	var key: String = "route|%s|%s" % [_key(partial, level.boxes), _key(partial, route)]
	var steps: PackedInt32Array = level.sketch.flood_kept(key, sources, _mask(partial, level), PackedByteArray())
	var near: int = 0
	for name: String in level.hiding:
		if not partial.has(name) or _within(level, steps, _cells_of(level, name, partial[name]), int(rule["steps"])):
			near += 1
	return near >= int(rule["count"])


# Whether any of `cells` is at most `most` steps away in `steps`.
static func _within(level: LevelConstraints, steps: PackedInt32Array, cells: Array[Vector2i], most: int) -> bool:
	for cell: Vector2i in cells:
		var away: int = level.sketch.steps_to(steps, cell)
		if away >= 0 and away <= most:
			return true
	return false


static func _dark_way(partial: Dictionary, level: LevelConstraints) -> bool:
	var lamps: Array[Dictionary] = _placed(partial, level, level.lamps)
	var dark: PackedByteArray = level.sketch.dark(_key(partial, level.lamps), lamps, LevelConstraints.AMBIENT,
			float(level.rules["dark_below"]))
	var key: String = "dark|%s|%s" % [_key(partial, level.boxes), _key(partial, level.lamps)]
	var steps: PackedInt32Array = level.sketch.flood_kept(key, [level.sketch.start], _mask(partial, level), dark)
	return level.sketch.steps_to(steps, level.sketch.exit_cell) >= 0


# -- what the partial level holds ---------------------------------------------

static func _walk_from_start(partial: Dictionary, level: LevelConstraints) -> PackedInt32Array:
	return level.sketch.from_start(_key(partial, level.boxes), _mask(partial, level))


static func _mask(partial: Dictionary, level: LevelConstraints) -> PackedByteArray:
	return level.sketch.blocked(_key(partial, level.boxes), _placed(partial, level, level.boxes))


static func _placed(partial: Dictionary, level: LevelConstraints, names: Array[String]) -> Array[Dictionary]:
	var placed: Array[Dictionary] = []
	for name: String in names:
		if partial.has(name):
			placed.append(level.candidates[name][partial[name]])
	return placed


# Which of `names` are placed where, as one string: the key the sketch keeps
# what follows from them by.
static func _key(partial: Dictionary, names: Array[String]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for name: String in names:
		parts.append(str(partial[name]) if partial.has(name) else "-")
	return ",".join(parts)
