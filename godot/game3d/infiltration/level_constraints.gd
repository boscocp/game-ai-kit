## An infiltration level declared, not drawn (T95): what a level must be,
## handed to `ConstraintSolver`, which finds one that is or says none is.
##
## `LevelGenerator` draws a whole level and keeps it when the exit and the
## guards' places can be walked to -- generate and test, up to 40 draws.
## Here the same seed draws the level's size and how many of each thing it
## has, and for each thing `candidates` places it might stand; those are the
## variables and their domains. The constraints, from
## `level_constraints.json`:
##
## * binary, so AC-3 crosses out what cannot stand together: boxes kept
##   apart, no place under a box, no two guard places on one cell, hiding
##   places apart, lamps apart;
## * global, checked on each partial level by the game's own rules
##   (`LevelSketch`): the exit can be walked to from the start; so can every
##   route point and post; no post is in sight of the start; each patrol's
##   route passes within a few steps of a hiding place; and a dark way leads
##   from the start to the exit. The last two are a designer's intent, which
##   generate and test can only hope for.
##
## Each global constraint answers false only when no completion could save
## it: boxes only ever close ways, lamps only ever light cells, so a partial
## level already walled off or lit through is refused at once; a post in
## sight is refused only once every box is placed, since a later box might
## hide it.
##
## The solver's ties go by the same seed, so a seed is one level. The
## director's reserve is added after, as `LevelGenerator` adds it.
##
## Complexity: exponential in the variables at worst, as any complete
## search; in practice tens to hundreds of assignments (`make
## measure-level-constraints`).
##
## When not to use it: for a level that must surprise its designer. Every
## constraint here narrows what can come out.
class_name LevelConstraints
extends RefCounted

const RULES: String = "res://game3d/infiltration/level_constraints.json"
const GUARD_TYPES: String = "res://game3d/infiltration/guard_types.json"
## What a restart adds to the seed its ties are broken by.
const RESTART_SALT: int = 7919
## The light everywhere no lamp reaches, as `LevelGenerator` sets it.
const AMBIENT: float = 0.1

var rules: Dictionary = {}
var seed_value: int = 1
var sketch: LevelSketch
var problem := ConstraintProblem.new()
var solver: ConstraintSolver
## The level's data in `InfiltrationLevel`'s shape, or {} when none was found.
var data: Dictionary = {}
## The labels of the constraints declared, as the rules file named them.
var declared: Array[String] = []
## The solver's answer, variable -> the index of its candidate; {} with none.
var assignment: Dictionary = {}
## Variable -> the places it may take; a value is an index into its list.
var candidates: Dictionary = {}
## The variables, by kind: `boxes`, `lamps`, `hiding`, `posts` (the sentry's
## and each patrol's first point) and `routes` (each patrol's three points).
var boxes: Array[String] = []
var lamps: Array[String] = []
var hiding: Array[String] = []
var routes: Array = []
var sentry: String = "sentry_post"  # not shown: an identifier
## How many times the search started again with fresh ties (see `solve`).
var restarts: int = 0
## Assignments and backtracks over every start, the ones given up included.
var spent: int = 0
var spent_backtracks: int = 0
var _layout: Dictionary = {}
var _boxes_cells: Dictionary = {}
var _sight: Dictionary = {}


## The level for `from_seed`, solved; `record` keeps the solver's steps for
## the generation view, and `overrides` replaces entries of the rules file
## (a test asking for the impossible). `data` is {} when no level meets every
## constraint -- `solver.gave_up` says whether that is proved or the limit.
##
## A search that runs into its `limit` starts again, up to `restarts` times,
## its ties broken by another seed: chronological backtracking can spend its
## whole budget undoing choices that were never the trouble (AIMA 6.3.3
## calls it thrashing), and a fresh order usually walks round it. `restarts`
## counts the fresh starts this level took.
static func solve(from_seed: int, record: bool = false, overrides: Dictionary = {}) -> LevelConstraints:
	var level := LevelConstraints.new()
	level.seed_value = from_seed
	level.rules = JSON.parse_string(FileAccess.get_file_as_string(RULES))
	level.rules.merge(overrides, true)
	level._sight = farthest_sight()
	level._declare()
	var found: Dictionary = {}
	for attempt: int in range(int(level.rules["restarts"]) + 1):
		level.restarts = attempt
		level.solver = ConstraintSolver.new(level.problem, from_seed + attempt * RESTART_SALT)
		level.solver.record = record
		level.solver.limit = int(level.rules["limit"])
		found = level.solver.solve()
		level.spent += level.solver.assignments
		level.spent_backtracks += level.solver.backtracks
		if not level.solver.gave_up:
			break
	# The constraints are Callables bound to this level, which holds the
	# problem that holds them: a cycle no reference count frees. The search
	# is over, and the view reads only the trace and the candidates.
	level.problem.binaries.clear()
	level.problem.globals.clear()
	level.sketch.forget()
	if not found.is_empty():
		level.assignment = found
		level.data = LevelGenerator.with_reserve(from_seed, level.level_of(found))
	return level


## The cell a guard place's value stands for, or a hiding place's centre.
func cell_of(name: String, value: int) -> Vector2i:
	var place: Variant = candidates[name][value]
	if place is Vector2i:
		return place
	if place.has("cell"):
		return place["cell"]
	return Vector2i(floori(float(place["x"])), floori(float(place["z"])))


## The level `found` describes, in the shape `InfiltrationLevel.read` takes.
func level_of(found: Dictionary) -> Dictionary:
	var made: Dictionary = _layout.duplicate(true)
	made["boxes"] = boxes.map(func(name: String) -> Dictionary: return candidates[name][found[name]])
	made["lights"] = lamps.map(func(name: String) -> Dictionary: return candidates[name][found[name]])
	made["hiding"] = hiding.map(func(name: String) -> Dictionary: return candidates[name][found[name]])
	var guards: Array = []
	for route: Array in routes:
		var points: Array = route.map(func(name: String) -> Array: return _centre(cell_of(name, found[name])))
		guards.append({"type": "patrol", "route": points})  # not shown: an identifier
	var post: Dictionary = candidates[sentry][found[sentry]]
	guards.append({"type": "sentry", "post": _centre(post["cell"]), "facing": post["facing"]})  # not shown: an identifier
	made["guards"] = guards
	return made


# -- the variables and their domains -----------------------------------------

func _declare() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var width: int = rng.randi_range(28, 40)
	var depth: int = rng.randi_range(18, 28)
	var middle: float = floorf(depth / 2.0) + 0.5
	_layout = {"about": "A generated infiltration level, solved.", "width": width, "depth": depth, "points": [],  # not shown: the data's own note
		"spawns": {"player": [[1.5, middle]]}, "exit": [width - 1.5, middle], "ambient": AMBIENT}
	sketch = LevelSketch.new(width, depth, Vector2i(1, int(middle)), Vector2i(width - 2, int(middle)))
	for index: int in range(rng.randi_range(6, 12)):
		_variable(boxes, "box_%d" % index, func() -> Variant: return _box(rng))
	for index: int in range(rng.randi_range(3, 6)):
		_variable(lamps, "lamp_%d" % index, func() -> Variant: return _lamp(rng))
	for index: int in range(rng.randi_range(2, 4)):
		_variable(hiding, "hiding_%d" % index, func() -> Variant: return _hiding(rng))
	for patrol: int in range(2):
		var route: Array[String] = []
		for point: int in range(3):
			_variable(route, "patrol_%d_%d" % [patrol, point], func() -> Variant: return _guard_cell(rng))
		routes.append(route)
	_variable([] as Array[String], sentry, func() -> Variant: return {"cell": _guard_cell(rng), "facing": rng.randf_range(-90.0, 90.0)})
	LevelConstraintRules.add(self)


# A variable `name`, in `kind`'s list, with `candidates` places drawn by `draw`.
func _variable(kind: Array[String], name: String, draw: Callable) -> void:
	var places: Array = []
	for index: int in range(int(rules["candidates"])):
		places.append(draw.call())
	candidates[name] = places
	kind.append(name)
	problem.add_variable(name, range(places.size()))


# A box as `LevelGenerator` draws one, redrawn while it would cover the start
# or the exit: those two are fixed, so that is a unary constraint, met here.
func _box(rng: RandomNumberGenerator) -> Dictionary:
	while true:
		var long: bool = rng.randf() < 0.5
		var box: Dictionary = {"x": rng.randi_range(5, sketch.width - 6), "z": rng.randi_range(2, sketch.depth - 3),
			"width": 1 if long else 2, "depth": rng.randi_range(4, 8) if long else 2,
			"height": LevelGenerator.HEIGHTS[rng.randi_range(0, LevelGenerator.HEIGHTS.size() - 1)]}
		var cells: Array[Vector2i] = LevelSketch.cells_under(box)
		if not cells.has(sketch.start) and not cells.has(sketch.exit_cell):
			return box
	return {}


func _lamp(rng: RandomNumberGenerator) -> Dictionary:
	return {"x": rng.randi_range(3, sketch.width - 4), "z": rng.randi_range(2, sketch.depth - 3),
		"radius": rng.randf_range(4.0, 7.0), "value": 1.0}


func _hiding(rng: RandomNumberGenerator) -> Dictionary:
	return {"x": rng.randi_range(3, sketch.width - 4), "z": rng.randi_range(2, sketch.depth - 3),
		"width": 2, "depth": 2, "hides": 0.7}


func _guard_cell(rng: RandomNumberGenerator) -> Vector2i:
	return Vector2i(rng.randi_range(LevelGenerator.CLEAR_OF_START, sketch.width - 3), rng.randi_range(1, sketch.depth - 2))


static func _centre(cell: Vector2i) -> Array:
	return [cell.x + 0.5, cell.y + 0.5]


## Each guard type's farthest sight, in metres, from `guard_types.json`.
static func farthest_sight() -> Dictionary:
	var types: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GUARD_TYPES))["guards"]
	var farthest: Dictionary = {}
	for type: String in types:
		var far: float = 0.0
		for zone: Dictionary in types[type]["vision"]["zones"]:
			far = maxf(far, float(zone["far"]))
		farthest[type] = far
	return farthest


## The cells box variable `name` = `value` blocks, as a set, worked out once.
func cells_under_box(name: String, value: int) -> Dictionary:
	if not _boxes_cells.has(name):
		_boxes_cells[name] = (candidates[name] as Array).map(_cell_set)
	return _boxes_cells[name][value]


static func _cell_set(box: Dictionary) -> Dictionary:
	var under: Dictionary = {}
	for cell: Vector2i in LevelSketch.cells_under(box):
		under[cell] = true
	return under


## How far a guard of `type` sees.
func sight_of(type: String) -> float:
	return _sight[type]
