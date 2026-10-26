## An infiltration level nobody drew, from a seed: the same guards, put on
## ground they were never tuned on (the owner's rule -- "em outro mapa ...
## deve saber se virar").
##
## Shelves and crates at random, lamps and hiding places at random, a start
## on the west edge and an exit on the east, two patrols on routes of
## random free cells and a sentry at a random post. A level is kept only
## when the exit can be walked to from the start and every route point and
## post from the start too; otherwise the next draw is tried. The data is
## `InfiltrationLevel`'s shape, so the same reader builds it.
##
## Linear in the cells per draw, for the flood that checks it.
##
## When not to use it: as a level to enjoy. It is varied, not designed.
class_name LevelGenerator
extends RefCounted

const TRIES: int = 40
## No guard is placed nearer the west edge than this, so the player starts
## out of every guard's sight, as a designer would place them.
const CLEAR_OF_START: int = 12
const HEIGHTS: Array[float] = [1.1, 2.5, 2.5]


## A playable level's data from `seed_value`, or {} when TRIES draws made none.
static func make(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for attempt: int in range(TRIES):
		var data: Dictionary = _draw(rng)
		if _playable(data):
			return data
	return {}


static func _draw(rng: RandomNumberGenerator) -> Dictionary:
	var width: int = rng.randi_range(28, 40)
	var depth: int = rng.randi_range(18, 28)
	var middle: float = floorf(depth / 2.0) + 0.5
	var data: Dictionary = {
		"about": "A generated infiltration level.", "width": width,  # not shown: the data's own note "depth": depth, "points": [],
		"spawns": {"player": [[1.5, middle]]}, "exit": [width - 1.5, middle],
		"boxes": _boxes(rng, width, depth), "ambient": 0.1,
		"lights": _scattered(rng, width, depth, rng.randi_range(3, 6), "light"),
		"hiding": _scattered(rng, width, depth, rng.randi_range(2, 4), "hiding"),
	}
	data["guards"] = _guards(rng, data)
	return data


static func _boxes(rng: RandomNumberGenerator, width: int, depth: int) -> Array:
	var boxes: Array = []
	for index: int in range(rng.randi_range(6, 12)):
		var long: bool = rng.randf() < 0.5
		boxes.append({"x": rng.randi_range(5, width - 6), "z": rng.randi_range(2, depth - 3),
			"width": 1 if long else 2, "depth": rng.randi_range(4, 8) if long else 2,
			"height": HEIGHTS[rng.randi_range(0, HEIGHTS.size() - 1)]})
	return boxes


static func _scattered(rng: RandomNumberGenerator, width: int, depth: int, count: int, kind: String) -> Array:
	var found: Array = []
	for index: int in range(count):
		var east: float = rng.randi_range(3, width - 4)
		var south: float = rng.randi_range(2, depth - 3)
		if kind == "light":
			found.append({"x": east, "z": south, "radius": rng.randf_range(4.0, 7.0), "value": 1.0})
		else:
			found.append({"x": east, "z": south, "width": 2, "depth": 2, "hides": 0.7})
	return found


# Two patrols on routes of three random free cells, and a sentry.
static func _guards(rng: RandomNumberGenerator, data: Dictionary) -> Array:
	var arena := BotArena.new(InfiltrationLevel.BODY_RADIUS, data)
	var free: Array[Vector2i] = []
	for cell: Vector2i in InfiltrationLevel.every_cell(arena):
		if cell.x >= CLEAR_OF_START and cell.x < int(arena.width) - 2 and not arena.walk.is_blocked(cell):
			free.append(cell)
	if free.size() < 8:
		return []
	var guards: Array = []
	for patrol: int in range(2):
		var route: Array = []
		for point: int in range(3):
			var cell: Vector2i = free[rng.randi_range(0, free.size() - 1)]
			route.append([cell.x + 0.5, cell.y + 0.5])
		guards.append({"type": "patrol", "route": route})  # not shown: an identifier
	var post: Vector2i = free[rng.randi_range(0, free.size() - 1)]
	guards.append({"type": "sentry", "post": [post.x + 0.5, post.y + 0.5], "facing": rng.randf_range(-90.0, 90.0)})  # not shown: an identifier
	return guards


# The exit and every guard's places can be walked to from the start.
static func _playable(data: Dictionary) -> bool:
	if (data["guards"] as Array).is_empty():
		return false
	var arena := BotArena.new(InfiltrationLevel.BODY_RADIUS, data)
	var from_start: PackedInt32Array = arena.steps_from([BotArena.cell_of(Vector2(data["spawns"]["player"][0][0], data["spawns"]["player"][0][1]))])
	var places: Array = [data["exit"]]
	for guard: Dictionary in data["guards"]:
		places.append_array(guard.get("route", []))
		if guard.has("post"):
			places.append(guard["post"])
	for pair: Array in places:
		var cell: Vector2i = BotArena.cell_of(Vector2(pair[0], pair[1]))
		if from_start[cell.y * int(arena.width) + cell.x] < 0:
			return false
	return true
