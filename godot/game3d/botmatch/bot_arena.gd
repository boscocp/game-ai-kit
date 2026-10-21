## The bot match's ground: its boxes, where a bot can walk, where it can
## take cover, and whether a line between two points is clear.
##
## Read from `arena.json`. A box is an axis-aligned block standing on the
## floor, so a sight line is a segment against a few boxes, answered exactly
## by the slab test -- no physics engine needed, which is what lets a match
## run headless at many times real speed and the Python side reason about the
## same arena. `botmatch_test.gd` holds this against Godot's own ray casts on
## the same boxes, so the two cannot quietly disagree.
##
## Cover spots are generated once: along every face of every box, a bot's
## width out from it, no two closer than SPOT_SPACING. They are the
## candidates `TacticalPositions` chooses among.
class_name BotArena
extends RefCounted

const ARENA: String = "res://game3d/botmatch/arena.json"
## No two spots along a face closer than this, in metres.
const SPOT_SPACING: float = 1.5
## How far out from a face a spot stands, beyond the bot's radius.
const SPOT_CLEARANCE: float = 0.4
## A box this tall or more hides a standing bot; lower ones only a crouching.
const HIGH: float = 2.0

## One place a bot can take cover.
class Spot extends RefCounted:
	var id: String = ""
	var position: Vector2 = Vector2.ZERO
	## The box it hides behind, and whether that box is low.
	var box: int = -1
	var low: bool = false


var width: float = 0.0
var depth: float = 0.0
## Every box, as a 3D block: x east, y up, z south.
var boxes: Array[AABB] = []
## Each capture point's id and place on the floor.
var point_ids: Array[String] = []
var point_places: Array[Vector2] = []
## Each team's spawn places, by team name.
var spawns: Dictionary = {}
var spots: Array[Spot] = []
## Where a bot can walk: one metre cells, those too near a box blocked.
var walk: GridGraph


## Reads `path`; `body_radius` is how far from a box a bot's centre must keep.
func _init(body_radius: float, path: String = ARENA) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	width = float(data["width"])
	depth = float(data["depth"])
	for box: Dictionary in data["boxes"]:
		var size := Vector3(float(box["width"]), float(box["height"]), float(box["depth"]))
		var corner := Vector3(float(box["x"]) - size.x / 2.0, 0.0, float(box["z"]) - size.z / 2.0)
		boxes.append(AABB(corner, size))
	for point: Dictionary in data["points"]:
		point_ids.append(str(point["id"]))
		point_places.append(Vector2(float(point["x"]), float(point["z"])))
	for team: String in data["spawns"]:
		var places: Array[Vector2] = []
		for pair: Array in data["spawns"][team]:
			places.append(Vector2(float(pair[0]), float(pair[1])))
		spawns[team] = places
	walk = _walk_grid(body_radius)
	spots = _cover_spots(body_radius)


## Whether the segment from `from` to `to` passes no box. The slab test: a
## segment misses a box when the parameter ranges in which it is between each
## pair of faces do not overlap.
func clear_line(from: Vector3, to: Vector3) -> bool:
	for box: AABB in boxes:
		if segment_hits_box(from, to, box):
			return false
	return true


## How far along the segment from `from` to `to` the first box is met, as a
## share of its length; 1.0 when no box is. Where a shot that missed stops.
func first_block(from: Vector3, to: Vector3) -> float:
	var nearest: float = 1.0
	for box: AABB in boxes:
		nearest = minf(nearest, entry_into(from, to, box))
	return nearest


## The slab test for one box. Touching a face counts as a hit.
static func segment_hits_box(from: Vector3, to: Vector3, box: AABB) -> bool:
	return entry_into(from, to, box) <= 1.0


## Where the segment enters the box, as a share of its length, or INF when it
## does not. The slab test: the segment is inside the box where it is
## between every pair of faces at once.
static func entry_into(from: Vector3, to: Vector3, box: AABB) -> float:
	var entering: float = 0.0
	var leaving: float = 1.0
	var direction: Vector3 = to - from
	for axis: int in range(3):
		var low: float = box.position[axis]
		var high: float = box.end[axis]
		# Parallel to this pair of faces: inside them all along, or never.
		var parallel: bool = absf(direction[axis]) < 1e-9
		if parallel and (from[axis] < low or from[axis] > high):
			return INF
		if parallel:
			continue
		var first: float = (low - from[axis]) / direction[axis]
		var second: float = (high - from[axis]) / direction[axis]
		entering = maxf(entering, minf(first, second))
		leaving = minf(leaving, maxf(first, second))
	return entering if entering <= leaving else INF


## The walk cell a floor point is in.
static func cell_of(place: Vector2) -> Vector2i:
	return Vector2i(floori(place.x), floori(place.y))


## The middle of a walk cell, on the floor.
static func centre_of(cell: Vector2i) -> Vector2:
	return Vector2(cell) + Vector2(0.5, 0.5)


## Whether a bot can walk straight from `from` to `to`: every walk cell the
## line passes, sampled each quarter metre, is open.
func walkable(from: Vector2, to: Vector2) -> bool:
	var samples: int = maxi(1, ceili(from.distance_to(to) / 0.25))
	for index: int in range(samples + 1):
		var cell: Vector2i = cell_of(from.lerp(to, float(index) / samples))
		if walk.is_blocked(cell):
			return false
	return true


## Every spot within `radius` of `place`, in the spots' order.
func spots_near(place: Vector2, radius: float) -> Array[Spot]:
	var near: Array[Spot] = []
	for spot: Spot in spots:
		if spot.position.distance_to(place) <= radius:
			near.append(spot)
	return near


func _walk_grid(body_radius: float) -> GridGraph:
	var grid := GridGraph.new(int(width), int(depth))
	for x: int in range(int(width)):
		for z: int in range(int(depth)):
			var near: bool = _too_near_a_box(centre_of(Vector2i(x, z)), body_radius)
			grid.set_cost(Vector2i(x, z), GridGraph.BLOCKED if near else GridGraph.DEFAULT_COST)
	return grid


func _too_near_a_box(place: Vector2, margin: float) -> bool:
	for box: AABB in boxes:
		var inside_x: bool = place.x > box.position.x - margin and place.x < box.end.x + margin
		var inside_z: bool = place.y > box.position.z - margin and place.y < box.end.z + margin
		if inside_x and inside_z:
			return true
	return false


# Along each of a box's four faces, spots a bot's width out, kept only where
# a bot can stand: on the floor, in an open walk cell, clear of every box.
func _cover_spots(body_radius: float) -> Array[Spot]:
	var found: Array[Spot] = []
	var out: float = body_radius + SPOT_CLEARANCE
	for index: int in range(boxes.size()):
		var places: Array[Vector2] = _face_places(boxes[index], out)
		for place: Vector2 in places.filter(func(at: Vector2) -> bool: return can_stand(at, body_radius)):
			found.append(_spot(found.size(), place, index))
	return found


func _spot(number: int, place: Vector2, box: int) -> Spot:
	var spot := Spot.new()
	spot.id = "s%d" % number
	spot.position = place
	spot.box = box
	spot.low = boxes[box].size.y < HIGH
	return spot


func _face_places(box: AABB, out: float) -> Array[Vector2]:
	var places: Array[Vector2] = []
	var west: float = box.position.x - out
	var east: float = box.end.x + out
	var north: float = box.position.z - out
	var south: float = box.end.z + out
	for along: float in _along(box.position.z, box.end.z):
		places.append(Vector2(west, along))
		places.append(Vector2(east, along))
	for along: float in _along(box.position.x, box.end.x):
		places.append(Vector2(along, north))
		places.append(Vector2(along, south))
	return places


# Places along one face, SPOT_SPACING apart and centred on it.
func _along(start: float, end: float) -> Array[float]:
	var count: int = maxi(1, floori((end - start) / SPOT_SPACING))
	var step: float = (end - start) / count
	var places: Array[float] = []
	for index: int in range(count):
		places.append(start + step * (index + 0.5))
	return places


## Whether a bot can stand at `place`: on the floor, in an open walk cell,
## clear of every box.
func can_stand(place: Vector2, body_radius: float) -> bool:
	var on_floor: bool = place.x > body_radius and place.y > body_radius \
			and place.x < width - body_radius and place.y < depth - body_radius
	return on_floor and not walk.is_blocked(cell_of(place)) and not _too_near_a_box(place, body_radius)
