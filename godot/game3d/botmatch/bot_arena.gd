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
## Some boxes are ground to stand on: a platform, and a stair, which is cut
## into one step a metre. Every walk cell has a floor height -- the top of
## the highest of those under its middle, or zero -- and a bot stands on it,
## its eyes `eye_height` above it. A bot walks from one cell to the next
## only when the floor rises or falls by MAX_RISE at most, so it climbs a
## stair and never the side of a box: `ArenaWalk` is that graph, for A*.
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
## Measured from the floor a bot stands on, not from the ground.
const HIGH: float = 2.0
## The most the floor may rise or fall in one step a bot walks: a stair's
## step is half a metre, and the lowest box, 1.1 m, is well over it.
const MAX_RISE: float = 0.6
## A stair is cut into steps this long, one walk cell each.
const STEP_LENGTH: float = 1.0
## Which way a stair rises, by the name `arena.json` gives it.
const RISES: Dictionary = {
	"east": Vector2.RIGHT, "west": Vector2.LEFT, "south": Vector2.DOWN, "north": Vector2.UP,
}

## One place a bot can take cover.
class Spot extends RefCounted:
	var id: String = ""
	var position: Vector2 = Vector2.ZERO
	## The box it hides behind, and whether that box is low.
	var box: int = -1
	var low: bool = false


var width: float = 0.0
var depth: float = 0.0
## Every box, as a 3D block: x east, y up, z south. Cover, platforms and
## the steps of the stairs, all solid to a sight line.
var boxes: Array[AABB] = []
## The ones a bot can stand on: platforms and steps.
var floors: Array[AABB] = []
## The steps alone, which are no cover worth a spot.
var steps: Array[AABB] = []
## Each capture point's id and place on the floor.
var point_ids: Array[String] = []
var point_places: Array[Vector2] = []
## Each team's spawn places, by team name.
var spawns: Dictionary = {}
var spots: Array[Spot] = []
## Where a bot can walk: one metre cells, those too near a box blocked.
var walk: GridGraph
## Each walk cell's floor height, row-major like the grid.
var heights: PackedFloat64Array = PackedFloat64Array()
## The walk grid with its heights, as the graph A* searches.
var walk_graph: ArenaWalk


## Reads `path`; `body_radius` is how far from a box a bot's centre must keep.
func _init(body_radius: float, path: String = ARENA) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	width = float(data["width"])
	depth = float(data["depth"])
	for box: Dictionary in data["boxes"]:
		boxes.append(_block(box))
	for platform: Dictionary in data.get("platforms", []):
		floors.append(_block(platform))
	for stair: Dictionary in data.get("stairs", []):
		steps.append_array(_steps_of(stair))
	floors.append_array(steps)
	boxes.append_array(floors)
	for point: Dictionary in data["points"]:
		point_ids.append(str(point["id"]))
		point_places.append(Vector2(float(point["x"]), float(point["z"])))
	for team: String in data["spawns"]:
		var places: Array[Vector2] = []
		for pair: Array in data["spawns"][team]:
			places.append(Vector2(float(pair[0]), float(pair[1])))
		spawns[team] = places
	heights = _floor_heights()
	walk = _walk_grid(body_radius)
	walk_graph = ArenaWalk.new(walk, heights, MAX_RISE)
	spots = _cover_spots(body_radius)


# A block standing on the ground, from its middle and size in `arena.json`.
static func _block(entry: Dictionary) -> AABB:
	var size := Vector3(float(entry["width"]), float(entry["height"]), float(entry["depth"]))
	return AABB(Vector3(float(entry["x"]) - size.x / 2.0, 0.0, float(entry["z"]) - size.z / 2.0), size)


# A stair as its steps: STEP_LENGTH each along the way it rises, evenly up
# to its height, which is the floor it leads to. With n steps there are
# n + 1 rises -- the ground to the first, and the last to the top.
static func _steps_of(stair: Dictionary) -> Array[AABB]:
	var whole: AABB = _block(stair)
	var rises: Vector2 = RISES[str(stair["rises"])]
	var along_x: bool = rises.x != 0.0
	var count: int = roundi((whole.size.x if along_x else whole.size.z) / STEP_LENGTH)
	var found: Array[AABB] = []
	for index: int in range(count):
		# Counted from the low end, wherever that is.
		var from_low: int = index if (rises.x > 0.0 or rises.y > 0.0) else count - 1 - index
		var step := AABB(whole.position, whole.size)
		step.size.y = whole.size.y * (from_low + 1) / (count + 1)
		if along_x:
			step.position.x += index * STEP_LENGTH
			step.size.x = STEP_LENGTH
		else:
			step.position.z += index * STEP_LENGTH
			step.size.z = STEP_LENGTH
		found.append(step)
	return found


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


## The floor height a bot at `place` stands on: its walk cell's, and the
## ground's off the grid.
func floor_at(place: Vector2) -> float:
	var cell: Vector2i = cell_of(place)
	var on_grid: bool = cell.x >= 0 and cell.y >= 0 and cell.x < int(width) and cell.y < int(depth)
	return heights[cell.y * int(width) + cell.x] if on_grid else 0.0


## The point `height` above the floor at `place`, in 3D: where a bot's eyes
## or chest are when it stands there.
func above(place: Vector2, height: float) -> Vector3:
	return Vector3(place.x, floor_at(place) + height, place.y)


## Whether a bot can walk straight from `from` to `to`: every walk cell the
## line passes, sampled each quarter metre, is open, and the floor between
## one and the next rises or falls by MAX_RISE at most.
func walkable(from: Vector2, to: Vector2) -> bool:
	var samples: int = maxi(1, ceili(from.distance_to(to) / 0.25))
	var floor_before: float = floor_at(from)
	for index: int in range(samples + 1):
		var place: Vector2 = from.lerp(to, float(index) / samples)
		if walk.is_blocked(cell_of(place)) or absf(floor_at(place) - floor_before) > MAX_RISE:
			return false
		floor_before = floor_at(place)
	return true


## Every spot within `radius` of `place`, in the spots' order.
func spots_near(place: Vector2, radius: float) -> Array[Spot]:
	var near: Array[Spot] = []
	for spot: Spot in spots:
		if spot.position.distance_to(place) <= radius:
			near.append(spot)
	return near


# Each cell's floor: the top of the highest floor block over its middle.
func _floor_heights() -> PackedFloat64Array:
	var found := PackedFloat64Array()
	found.resize(int(width) * int(depth))
	for z: int in range(int(depth)):
		for x: int in range(int(width)):
			found[z * int(width) + x] = _floor_under(centre_of(Vector2i(x, z)))
	return found


func _floor_under(place: Vector2) -> float:
	var top: float = 0.0
	for block: AABB in floors:
		if _over(block, place, 0.0):
			top = maxf(top, block.end.y)
	return top


func _walk_grid(body_radius: float) -> GridGraph:
	var grid := GridGraph.new(int(width), int(depth))
	for x: int in range(int(width)):
		for z: int in range(int(depth)):
			var near: bool = _too_near_a_box(centre_of(Vector2i(x, z)), body_radius)
			grid.set_cost(Vector2i(x, z), GridGraph.BLOCKED if near else GridGraph.DEFAULT_COST)
	return grid


# Whether a body at `place` would be inside a box, `margin` round it, that
# stands more than MAX_RISE above the floor there. The platform a bot stands
# on is under it, not in its way; the next step up is no higher than a step.
func _too_near_a_box(place: Vector2, margin: float) -> bool:
	var standing_on: float = floor_at(place)
	for box: AABB in boxes:
		if box.end.y > standing_on + MAX_RISE and _over(box, place, margin):
			return true
	return false


# Whether `place` is over the box's footprint grown by `margin`.
static func _over(box: AABB, place: Vector2, margin: float) -> bool:
	var inside_x: bool = place.x > box.position.x - margin and place.x < box.end.x + margin
	var inside_z: bool = place.y > box.position.z - margin and place.y < box.end.z + margin
	return inside_x and inside_z


# Along each of a box's four faces, spots a bot's width out, kept only where
# a bot can stand: on the floor, in an open walk cell, clear of every box.
# A step is no box to hide behind, so it has none.
func _cover_spots(body_radius: float) -> Array[Spot]:
	var found: Array[Spot] = []
	var out: float = body_radius + SPOT_CLEARANCE
	for index: int in range(boxes.size()):
		if steps.has(boxes[index]):
			continue
		var places: Array[Vector2] = _face_places(boxes[index], out)
		for place: Vector2 in places.filter(func(at: Vector2) -> bool: return can_stand(at, body_radius)):
			found.append(_spot(found.size(), place, index))
	return found


func _spot(number: int, place: Vector2, box: int) -> Spot:
	var spot := Spot.new()
	spot.id = "s%d" % number
	spot.position = place
	spot.box = box
	spot.low = boxes[box].end.y - floor_at(place) < HIGH
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


## Whether a bot at `from` can take one small step to `to`: it can stand
## there, and the floor rises or falls by MAX_RISE at most -- up a stair, not
## off a platform's edge.
func can_step(from: Vector2, to: Vector2, body_radius: float) -> bool:
	return can_stand(to, body_radius) and absf(floor_at(to) - floor_at(from)) <= MAX_RISE
