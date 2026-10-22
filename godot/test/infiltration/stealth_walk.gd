## A guard standing on a generated level and a target wandering it: the
## world the honesty claim watches, and what the guard's senses make of it.
##
## The percept is built the way T70's level will build one -- the vision
## shape at the target's distance and angle, a line of sight walked over
## the cells, light at its feet, a footstep's loudness along the level --
## and holds nothing the senses did not give. The walk keeps where the
## target really is, which is exactly what a guard must not read.
##
## When not to use it: as T70's level. One guard, one target, no turns.
class_name StealthWalk
extends RefCounted

const FOOTSTEP_RADIUS: float = 6.0
const STAY_SHARE: float = 0.3

var level: GridGraph
var cells: Array[Vector2i] = []
var neighbours: Array[PackedInt32Array] = []
var guard: Vector2i = Vector2i.ZERO
var facing: Vector2 = Vector2.RIGHT
## The target's cell, as an index into `cells`, and whether it just moved.
var target: int = 0
var moved: bool = false
var light := LightMap.new(0.1)


## A walk on a level made from `rng`, or null when the level has too few
## free cells for a guard and a target.
static func make(rng: RandomNumberGenerator) -> StealthWalk:
	var walk := StealthWalk.new()
	walk.level = StealthWorlds.scattered(rng)
	walk.cells = StealthWorlds.free_cells(walk.level)
	if walk.cells.size() < 3:
		return null
	walk.neighbours = StealthWorlds.neighbour_list(walk.level, walk.cells)
	walk.guard = walk.cells[rng.randi_range(0, walk.cells.size() - 1)]
	walk.facing = Vector2.from_angle(rng.randf_range(-PI, PI))
	walk.target = rng.randi_range(0, walk.cells.size() - 1)
	for cell: Vector2i in walk.cells:
		walk.light.set_light(cell, rng.randf())
	return walk


## One step of the target: to a random neighbour, or staying put.
func wander(rng: RandomNumberGenerator) -> void:
	var next_to: PackedInt32Array = neighbours[target]
	moved = not next_to.is_empty() and rng.randf() >= STAY_SHARE
	if moved:
		target = next_to[rng.randi_range(0, next_to.size() - 1)]


## What a guard of `type` perceives of the target now, and nothing more.
func percept(type: GuardType) -> GuardPercept:
	var at: Vector2i = cells[target]
	var made := GuardPercept.new()
	made.sight = look_at(type, at, moved)
	if made.sight.perceived():
		made.seen_place = Vector2(at)
		made.distance = Vector2(at - guard).length()
		made.light = light.at(at)
		made.motion = 1.0 if moved else 0.0
	if moved:
		var flooded: Dictionary[Vector2i, float] = SoundPaths.lengths(level, at, FOOTSTEP_RADIUS, 1.0)
		made.loudness = SoundPaths.loudness_at(flooded, guard, FOOTSTEP_RADIUS, 1.0)
		made.heard_place = Vector2(at) if made.loudness > 0.0 else Vector2.ZERO
		made.heard_kind = "footstep" if made.loudness > 0.0 else ""
	return made


## The guard's look at a body standing on `cell`: the shape at its distance
## and angle, every body point clear when the line over the cells is.
func look_at(type: GuardType, cell: Vector2i, moving: bool) -> VisionPercept:
	var offset := Vector2(cell - guard)
	var angle: float = 0.0 if offset == Vector2.ZERO else rad_to_deg(absf(facing.angle_to(offset)))
	var clear: bool = LineOfSight.clear(level, guard, cell)
	var points: Array[bool] = [clear, clear, clear]
	return type.vision.percept(offset.length(), angle, points, type.needed_for("standing"), light.at(cell), moving, 0.0)


## The nodes the guard sees whatever stands there: each cell in a zone with
## a clear line.
func seen_nodes(type: GuardType) -> PackedInt32Array:
	var seen := PackedInt32Array()
	for index: int in range(cells.size()):
		var offset := Vector2(cells[index] - guard)
		var angle: float = 0.0 if offset == Vector2.ZERO else rad_to_deg(absf(facing.angle_to(offset)))
		if type.vision.zone_at(offset.length(), angle) != -1 and LineOfSight.clear(level, guard, cells[index]):
			seen.append(index)
	return seen
