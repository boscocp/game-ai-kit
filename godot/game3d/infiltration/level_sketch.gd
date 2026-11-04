## The ground a level solver reasons about before the level exists: a grid
## of one-metre cells, the boxes placed so far, and what follows from them --
## where a body can walk from the start, how far, how lit each cell is, and
## whether a line from the start's eyes is clear.
##
## A global constraint is asked thousands of times about partial levels, so
## building a `BotArena` for each question (cover spots and all) is out.
## This is the part of it the constraints read, by the same rules: a cell is
## blocked when its centre is within `InfiltrationLevel.BODY_RADIUS` of a
## box's footprint, a step goes to the four neighbours, a lamp lights as
## `InfiltrationLevel` lights, and a sight line is `BotArena`'s slab test.
## `level_constraints_test.gd` holds the walk grid equal to the arena's on
## every level it solves, so the two cannot quietly disagree.
##
## What follows from a set of boxes is kept, keyed by which boxes they are:
## the search asks again and again about the same boxes while it places the
## rest.
##
## Complexity: a flood is linear in the cells; a light map in cells times lamps.
##
## When not to use it: for a level with floors, stairs or platforms. The
## generator makes none, and this knows only ground-level boxes.
class_name LevelSketch
extends RefCounted

const FOUR: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

var width: int = 0
var depth: int = 0
var start: Vector2i = Vector2i.ZERO
var exit_cell: Vector2i = Vector2i.ZERO
var _floods: Dictionary = {}
var _blocked: Dictionary = {}
var _dark: Dictionary = {}


## A sketch `wide` by `deep` cells, walked from `from_cell` towards `to_cell`.
func _init(wide: int, deep: int, from_cell: Vector2i, to_cell: Vector2i) -> void:
	width = wide
	depth = deep
	start = from_cell
	exit_cell = to_cell


## Drop every flood, mask and light map kept during the search: once it is
## over, only the size, the start and the exit are read.
func forget() -> void:
	_floods.clear()
	_blocked.clear()
	_dark.clear()


## The cells a box blocks, by the arena's rule: every cell whose centre lies
## strictly inside its footprint grown by a body's radius.
static func cells_under(box: Dictionary) -> Array[Vector2i]:
	var block: AABB = box_of(box)
	var margin: float = InfiltrationLevel.BODY_RADIUS
	var grown := Rect2(block.position.x - margin, block.position.z - margin, block.size.x + 2.0 * margin,
			block.size.z + 2.0 * margin)
	var found: Array[Vector2i] = []
	for x: int in range(floori(grown.position.x), ceili(grown.end.x)):
		for z: int in range(floori(grown.position.y), ceili(grown.end.y)):
			found.append(Vector2i(x, z))
	return found.filter(func(cell: Vector2i) -> bool: return _strictly_inside(grown, Vector2(cell) + Vector2(0.5, 0.5)))


# Inside and not on an edge, as the arena's `_over` compares.
static func _strictly_inside(area: Rect2, place: Vector2) -> bool:
	return place.x > area.position.x and place.x < area.end.x and place.y > area.position.y and place.y < area.end.y


## The box's block in 3D, as `BotArena` reads one from data.
static func box_of(box: Dictionary) -> AABB:
	var size := Vector3(float(box["width"]), float(box["height"]), float(box["depth"]))
	return AABB(Vector3(float(box["x"]) - size.x / 2.0, 0.0, float(box["z"]) - size.z / 2.0), size)


## Which cells `boxes` block, as a row-major mask; `key` names the set, so
## the same boxes are worked out once.
func blocked(key: String, boxes: Array[Dictionary]) -> PackedByteArray:
	if _blocked.has(key):
		return _blocked[key]
	var mask := PackedByteArray()
	mask.resize(width * depth)
	for box: Dictionary in boxes:
		for cell: Vector2i in cells_under(box).filter(contains):
			mask[cell.y * width + cell.x] = 1
	_blocked[key] = mask
	return mask


## Steps from the start to every cell over the cells `mask` leaves open, row
## major, -1 where none reaches; kept by `key`.
func from_start(key: String, mask: PackedByteArray) -> PackedInt32Array:
	return flood_kept("start|" + key, [start], mask, PackedByteArray())


## `flood(sources, mask, only)`, kept by `key`, which must name all three.
func flood_kept(key: String, sources: Array[Vector2i], mask: PackedByteArray, only: PackedByteArray) -> PackedInt32Array:
	if not _floods.has(key):
		_floods[key] = flood(sources, mask, only)
	return _floods[key]


## Steps from the nearest of `sources` over cells open in `mask` and, when
## `only` is not empty, marked in it too; -1 where none reaches.
func flood(sources: Array[Vector2i], mask: PackedByteArray, only: PackedByteArray) -> PackedInt32Array:
	var steps := PackedInt32Array()
	steps.resize(width * depth)
	steps.fill(-1)
	var waiting: Array[Vector2i] = []
	for source: Vector2i in sources:
		if _open(source, mask, only) and steps[source.y * width + source.x] < 0:
			steps[source.y * width + source.x] = 0
			waiting.append(source)
	var head: int = 0
	while head < waiting.size():
		var cell: Vector2i = waiting[head]
		head += 1
		for next: Vector2i in _unreached(cell, steps, mask, only):
			steps[next.y * width + next.x] = steps[cell.y * width + cell.x] + 1
			waiting.append(next)
	return steps


# The open neighbours of `cell` that `steps` has not reached yet.
func _unreached(cell: Vector2i, steps: PackedInt32Array, mask: PackedByteArray, only: PackedByteArray) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for step: Vector2i in FOUR:
		var next: Vector2i = cell + step
		if _open(next, mask, only) and steps[next.y * width + next.x] < 0:
			found.append(next)
	return found


## Steps to `cell` in `steps`, -1 when unreached or off the grid.
func steps_to(steps: PackedInt32Array, cell: Vector2i) -> int:
	return steps[cell.y * width + cell.x] if contains(cell) else -1


## A mask of the cells darker than `below` under `lamps`, by
## `InfiltrationLevel`'s light: each lamp's value falling off in a straight
## line to its radius, the brightest one counting, never under `ambient`.
## Kept by `key`, which names the lamps.
func dark(key: String, lamps: Array[Dictionary], ambient: float, below: float) -> PackedByteArray:
	if _dark.has(key):
		return _dark[key]
	var mask := PackedByteArray()
	mask.resize(width * depth)
	for z: int in range(depth):
		for x: int in range(width):
			mask[z * width + x] = 1 if _light_at(Vector2(x + 0.5, z + 0.5), lamps, ambient) < below else 0
	_dark[key] = mask
	return mask


## The light at `centre`: the brightest lamp's there, or `ambient`.
static func _light_at(centre: Vector2, lamps: Array[Dictionary], ambient: float) -> float:
	var light: float = ambient
	for lamp: Dictionary in lamps:
		var away: float = centre.distance_to(Vector2(float(lamp["x"]), float(lamp["z"])))
		light = maxf(light, float(lamp["value"]) * (1.0 - away / float(lamp["radius"])))
	return light


## Whether a line from eyes `height` above the start's centre to the same
## height above `cell` passes every one of `boxes`.
func clear_from_start(cell: Vector2i, boxes: Array[Dictionary], height: float) -> bool:
	var from := Vector3(start.x + 0.5, height, start.y + 0.5)
	var to := Vector3(cell.x + 0.5, height, cell.y + 0.5)
	for box: Dictionary in boxes:
		if BotArena.segment_hits_box(from, to, box_of(box)):
			return false
	return true


## True when `cell` lies on the grid.
func contains(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < depth


func _open(cell: Vector2i, mask: PackedByteArray, only: PackedByteArray) -> bool:
	if not contains(cell) or mask[cell.y * width + cell.x] != 0:
		return false
	return only.is_empty() or only[cell.y * width + cell.x] != 0
