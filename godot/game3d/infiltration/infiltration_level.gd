## One infiltration level, read from data: the bot match's ground, plus the
## light on each cell, the places that hide a body, where the player starts
## and leaves, and the guards' posts and routes.
##
## The ground is `BotArena`'s, from the same JSON shape as `arena.json`, and
## walked by its `ArenaWalk` -- boxes, platforms, stairs and their heights
## (the owner's instruction: reuse the bot match). On top of it, T69's light
## per cell [Leonard 2003], a hiding share per cell [Rabin 2015], and the
## free walk cells as a neighbour list, which is all a `BeliefMap` is
## given. The guards' code reads a level only through this, so a second
## level, or one a generator made, needs data, not code.
##
## Sound floods the same walk graph, 4-connected: a radius is a diamond,
## ground slow to walk is quieter to hear across, and a door is only open
## or shut (T69's review). It is kept, and said, rather than a second graph
## for sound: on these levels every walk cell costs one, and there are no
## doors.
##
## When not to use it: a level with doors that open and close, or floors
## above floors. The walk grid has one floor per cell.
class_name InfiltrationLevel
extends RefCounted

const WAREHOUSE: String = "res://game3d/infiltration/levels/the_warehouse.json"
const COURTYARD: String = "res://game3d/infiltration/levels/the_courtyard.json"
## The hand-made levels, in the order the demo offers them.
const HAND_MADE: Array[String] = [WAREHOUSE, COURTYARD]
## How far a body's centre keeps from a box, as the bot match's rules say.
const BODY_RADIUS: float = 0.4

var name: String = ""
var arena: BotArena
var light: LightMap
## Walk cell -> the share of a body a hiding place covers there.
var hidden: Dictionary[Vector2i, float] = {}
var start: Vector2 = Vector2.ZERO
var exit_place: Vector2 = Vector2.ZERO
## Each guard as the level places it: `type`, `route` (Array[Vector2]),
## `post` (Vector2, or INF) and `facing` (radians).
var guard_specs: Array[Dictionary] = []
## The free walk cells, and each one's index; their neighbour list.
var cells: Array[Vector2i] = []
var index_of: Dictionary[Vector2i, int] = {}
var neighbours: Array[PackedInt32Array] = []


## The level `source` describes: a file's path, or the data already parsed.
static func read(source: Variant, level_name: String = "") -> InfiltrationLevel:
	var data: Dictionary = source if source is Dictionary else JSON.parse_string(FileAccess.get_file_as_string(source))
	var level := InfiltrationLevel.new()
	level.name = level_name if level_name != "" else (str(source).get_file().get_basename() if source is String else "generated")
	level.arena = BotArena.new(BODY_RADIUS, data)
	level.start = _place(data["spawns"]["player"][0])
	level.exit_place = _place(data["exit"])
	level.light = _light_of(data, level.arena)
	level.hidden = _hidden_of(data)
	for spec: Dictionary in data["guards"]:
		level.guard_specs.append(_guard_spec(spec))
	level._index_cells()
	return level


## The walk cell a floor point is in.
func cell_of(place: Vector2) -> Vector2i:
	return BotArena.cell_of(place)


## True when a body can stand in `cell`.
func walkable(cell: Vector2i) -> bool:
	return index_of.has(cell)


## The light at the feet of a body standing at `place`.
func light_at(place: Vector2) -> float:
	return light.at(cell_of(place))


## The share of a body a hiding place covers at `place`.
func hidden_at(place: Vector2) -> float:
	return hidden.get(cell_of(place), 0.0)


## Every cell of `arena`'s walk grid, walled or not, row by row.
static func every_cell(arena: BotArena) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for row: int in range(int(arena.depth)):
		for column: int in range(int(arena.width)):
			found.append(Vector2i(column, row))
	return found


func _index_cells() -> void:
	for cell: Vector2i in every_cell(arena):
		if not arena.walk.is_blocked(cell):
			index_of[cell] = cells.size()
			cells.append(cell)
	for cell: Vector2i in cells:
		var near := PackedInt32Array()
		for next: Vector2i in arena.walk_graph.neighbours(cell):
			near.append(index_of[next])
		neighbours.append(near)


static func _place(pair: Array) -> Vector2:
	return Vector2(float(pair[0]), float(pair[1]))


# Every cell lit by the brightest lamp reaching it, falling off in a straight
# line to its radius, and never below the ambient light.
static func _light_of(data: Dictionary, arena: BotArena) -> LightMap:
	var map := LightMap.new(float(data.get("ambient", 0.0)))
	for cell: Vector2i in every_cell(arena):
		map.set_light(cell, _brightest(data.get("lights", []), cell, map.ambient))
	return map


static func _brightest(lamps: Array, cell: Vector2i, ambient: float) -> float:
	var brightest: float = ambient
	for lamp: Dictionary in lamps:
		var away: float = BotArena.centre_of(cell).distance_to(_place([lamp["x"], lamp["z"]]))
		brightest = maxf(brightest, float(lamp["value"]) * (1.0 - away / float(lamp["radius"])))
	return brightest


static func _hidden_of(data: Dictionary) -> Dictionary[Vector2i, float]:
	var found: Dictionary[Vector2i, float] = {}
	for place: Dictionary in data.get("hiding", []):
		var corner := Vector2(float(place["x"]) - float(place["width"]) / 2.0, float(place["z"]) - float(place["depth"]) / 2.0)
		for x: int in range(int(place["width"])):
			for z: int in range(int(place["depth"])):
				found[BotArena.cell_of(corner + Vector2(x + 0.5, z + 0.5))] = float(place["hides"])
	return found


static func _guard_spec(spec: Dictionary) -> Dictionary:
	var route: Array[Vector2] = []
	for pair: Array in spec.get("route", []):
		route.append(_place(pair))
	var post: Vector2 = _place(spec["post"]) if spec.has("post") else (route[0] if not route.is_empty() else Vector2.ZERO)
	return {"type": str(spec["type"]), "route": route, "post": post, "facing": deg_to_rad(float(spec.get("facing", 0.0)))}
