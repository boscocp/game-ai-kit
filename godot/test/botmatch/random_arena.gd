## A bot match arena nobody drew: made from a seed, random within the
## mirror, so the effects test can play the same agents on a map they were
## never tuned on (T67's portability). The same seed is the same arena.
##
## Its size, its three points on the mirror line, its boxes -- low cover,
## pillars and walls -- and a platform with its stair are drawn at random on
## the west half and copied across x = width / 2, so neither side has better
## ground; the spawns sit in the middle of their cells, as `arena.json`
## says they must. An arena is kept only when a bot can stand on every
## point, spawn and resupply and walk from its spawn to each of them, to the
## other spawn and to the power weapon; otherwise the next draw is tried.
class_name RandomArena
extends RefCounted

## Draws tried before giving up: a seed that never makes a playable map is
## a fault of this generator, and the test says so.
const TRIES: int = 60
## Boxes on each half, at least and at most.
const FEWEST_BOXES: int = 7
const MOST_BOXES: int = 13
## Boxes stand this far from the spawn wall and from the mirror line, so a
## spawn and a point are never inside one.
const SPAWN_CLEAR: float = 7.0
const LINE_CLEAR: float = 2.0
## The heights a box may be: low cover, a pillar, a wall.
const HEIGHTS: Array[float] = [1.1, 2.5, 5.0]


## A playable arena's data, as `BotArena` reads it, from `seed_value`; an
## empty Dictionary when TRIES draws made none.
static func make(seed_value: int, body_radius: float = 0.4) -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	for _try: int in range(TRIES):
		var data: Dictionary = draw(random)
		if playable(BotArena.new(body_radius, data), body_radius):
			return data
	return {}


## One draw, playable or not.
static func draw(random: RandomNumberGenerator) -> Dictionary:
	var width: float = 40.0 + 2.0 * random.randi_range(0, 8)
	var depth: float = 28.0 + 2.0 * random.randi_range(0, 6)
	var middle: float = width / 2.0
	var data: Dictionary = {"about": "made by RandomArena", "width": width, "depth": depth}
	data["points"] = [
		{"id": "A", "x": middle, "z": roundf(random.randf_range(4.0, depth * 0.3))},
		{"id": "B", "x": middle, "z": roundf(depth / 2.0 + random.randf_range(-2.0, 2.0))},
		{"id": "C", "x": middle, "z": roundf(random.randf_range(depth * 0.7, depth - 4.0))},
	]
	data["spawns"] = _spawns(width, depth)
	var home: float = floorf(depth / 2.0) + 0.5
	data["resupply"] = {"blue": [4.5, home], "red": [width - 4.5, home]}
	data["power"] = [middle, floorf(random.randf_range(depth * 0.3, depth * 0.7)) + 0.5]
	data["boxes"] = _mirrored(_boxes(random, middle, depth), width)
	var raised: Array = _platform(random, middle, depth)
	data["platforms"] = _mirrored([raised[0]], width)
	data["stairs"] = _mirrored([raised[1]], width)
	return data


## Whether `arena` can be played: every point, spawn and resupply is a place
## a bot stands, and from blue's first spawn a walk reaches them all, red's
## spawns and the power weapon.
static func playable(arena: BotArena, body_radius: float) -> bool:
	var places: Array[Vector2] = arena.point_places.duplicate()
	places.append_array(arena.spawns["blue"])
	places.append_array(arena.spawns["red"])
	places.append(arena.resupply["blue"])
	places.append(arena.resupply["red"])
	if not places.all(func(place: Vector2) -> bool: return arena.can_stand(place, body_radius)):
		return false
	var start: Array[Vector2i] = [BotArena.cell_of(arena.spawns["blue"][0])]
	var steps: PackedInt32Array = arena.steps_from(start)
	places.append(arena.power_place)
	return places.all(func(place: Vector2) -> bool: return _reached(arena, steps, place))


# Whether the flood `steps` reached a cell `place` can be walked to from.
static func _reached(arena: BotArena, steps: PackedInt32Array, place: Vector2) -> bool:
	for cell: Vector2i in BotArena.cells_at(place):
		if arena.walk.contains(cell) and steps[cell.y * int(arena.width) + cell.x] >= 0:
			return true
	return false


# Six spawns a side in the middle of their cells, red's the mirror of blue's.
static func _spawns(width: float, depth: float) -> Dictionary:
	var home: float = floorf(depth / 2.0)
	var blue: Array = []
	for offset: float in [-3.0, -1.0, 2.0, 4.0]:
		blue.append([3.5, home + offset + 0.5])
	blue.append([4.5, home - 0.5])
	blue.append([4.5, home + 0.5])
	var red: Array = blue.map(func(pair: Array) -> Array: return [width - pair[0], pair[1]])
	return {"blue": blue, "red": red}


# Boxes on the west half, clear of the spawns and of the mirror line.
static func _boxes(random: RandomNumberGenerator, middle: float, depth: float) -> Array:
	var boxes: Array = []
	for _box: int in range(random.randi_range(FEWEST_BOXES, MOST_BOXES)):
		var size := Vector2(random.randi_range(1, 4), random.randi_range(1, 6))
		var low: float = SPAWN_CLEAR + size.x / 2.0
		var high: float = middle - LINE_CLEAR - size.x / 2.0
		var x: float = roundf(random.randf_range(low, high) * 2.0) / 2.0
		var z_middle: float = roundf(random.randf_range(size.y / 2.0, depth - size.y / 2.0) * 2.0) / 2.0
		var height: float = HEIGHTS[random.randi_range(0, HEIGHTS.size() - 1)]
		boxes.append({"x": x, "z": z_middle, "width": size.x, "depth": size.y, "height": height})
	return boxes


# A platform 2.5 m up, and a stair of four half-metre steps rising east to
# it from its west side.
static func _platform(random: RandomNumberGenerator, middle: float, depth: float) -> Array:
	var x: float = floorf(random.randf_range(SPAWN_CLEAR + 6.0, middle - LINE_CLEAR - 2.0))
	var z_middle: float = floorf(random.randf_range(4.0, depth - 4.0))
	var platform: Dictionary = {"x": x, "z": z_middle, "width": 4, "depth": 4, "height": 2.5}
	var stair: Dictionary = {"x": x - 4.0, "z": z_middle, "width": 4, "depth": 2, "height": 2.5, "rises": "east"}
	return [platform, stair]


# Every entry and its copy across the mirror line; a stair's copy rises the
# other way.
static func _mirrored(entries: Array, width: float) -> Array:
	var both: Array = entries.duplicate(true)
	for entry: Dictionary in entries:
		var copy: Dictionary = entry.duplicate()
		copy["x"] = width - float(entry["x"])
		if entry.has("rises"):
			copy["rises"] = {"east": "west", "west": "east"}.get(entry["rises"], entry["rises"])
		both.append(copy)
	return both
