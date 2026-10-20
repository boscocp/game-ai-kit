## One side's belief about who holds the map: its own strength and the
## enemy's, spread over the ground, the enemy's partly remembered.
##
## An influence map in the RTS sense, which is not `ai_perception`'s. That
## one keeps the strongest watcher per cell, because two guards watching a
## cell make it no more watched. Here influence **adds up**: two squads hold
## a region twice as firmly. Each unit spreads its strength -- what it cost,
## scaled by the health it has left -- over the cells within `RADIUS`,
## falling off in a straight line.
##
## Under fog the enemy half is an estimate, and that is the point of
## drawing it. What a side sees now counts in full. What it saw and can no
## longer see counts less the longer ago it was, gone after
## `MEMORY_SECONDS`: a player remembers an army that marched behind a hill,
## and stops trusting the memory. Buildings, which do not walk away, are
## remembered until seen gone. Nothing is ever read that the side was not
## shown, so the estimate can be wrong -- that is fog working.
##
## Kept on a grid of `CELL`-cell squares, 12 x 8 on this map: squads ask
## about regions, not cells, and the coarse grid is what makes a rebuild
## every decision cheap. Drawn on the screen with `I`.
##
## When not to use it: a board small enough to see whole, with no fog. Then
## count the units in a region and skip the spreading.
class_name RtsInfluence
extends RefCounted

## The side of each grid square, in cells.
const CELL: int = 4
## How far a unit's strength reaches, in cells.
const RADIUS: float = 8.0
## How long an enemy seen and lost is still believed in.
const MEMORY_SECONDS: float = 45.0

var width: int
var height: int
## Own strength, enemy strength, per grid square, row-major.
var own: PackedFloat32Array
var enemy: PackedFloat32Array

## Regions this side has looked at and found no enemy base in, by name:
## a home taken down, an expansion nobody took.
var cleared: Dictionary = {}

## Enemy units this side has seen: id -> {kind, position, health, tick}.
var _seen: Dictionary = {}


func _init(board_width: int, board_height: int) -> void:
	width = ceili(float(board_width) / CELL)
	height = ceili(float(board_height) / CELL)
	own.resize(width * height)
	enemy.resize(width * height)


## Rebuild the map from `view`, remembering what it shows and forgetting
## what is too old or was seen gone.
func update(view: RtsSnapshot) -> void:
	_remember(view)
	_look_at_regions(view)
	own.fill(0.0)
	enemy.fill(0.0)
	for unit: Dictionary in view.mine():
		_spread(own, unit["position"], strength(unit["kind"], unit["health"]))
	for id: int in _seen:
		var memory: Dictionary = _seen[id]
		var trust: float = _trust(memory, view.tick)
		_spread(enemy, memory["position"], strength(memory["kind"], memory["health"]) * trust)


## A unit's weight: what it cost, both resources alike, scaled by the health
## it has left. Workers and buildings weigh nothing: influence is about who
## can fight for the ground.
static func strength(kind: String, health: int) -> float:
	if not RtsKinds.fights(kind):
		return 0.0
	var price: int = 0
	for resource: String in RtsKinds.RESOURCES:
		price += RtsKinds.cost(kind)[resource]
	return price * float(health) / float(RtsKinds.of(kind, "health"))


## Own and enemy influence at `cell`, as [own, enemy].
func at(cell: Vector2i) -> Array[float]:
	var index: int = _index_of(cell)
	return [own[index], enemy[index]] as Array[float]


## The enemy buildings this side believes stand, as {kind, position}: what
## it has seen and not since seen fall.
func remembered_buildings() -> Array[Dictionary]:
	var standing: Array[Dictionary] = []
	for id: int in _seen:
		if RtsKinds.is_building(_seen[id]["kind"]):
			standing.append({"kind": _seen[id]["kind"], "position": _seen[id]["position"]})
	return standing


## True when this side believes an enemy base stands within a few cells
## of `cell`: one seen there and not since seen fallen.
func base_believed_near(cell: Vector2i) -> bool:
	for building: Dictionary in remembered_buildings():
		if building["kind"] == RtsKinds.BASE and (building["position"] as Vector2).distance_to(Vector2(cell)) < 4.0:
			return true
	return false


# A region whose cell is in sight is cleared when no enemy base is believed
# near it, and uncleared the moment one is.
func _look_at_regions(view: RtsSnapshot) -> void:
	for region: String in RtsScenario.REGIONS:
		var cell: Vector2i = RtsScenario.REGIONS[region]["cell"]
		if base_believed_near(cell):
			cleared.erase(region)
		elif _in_sight(view, Vector2(cell) + Vector2(0.5, 0.5)):
			cleared[region] = true


## The enemy fighters seen, by kind, counting each one once, ever: what the
## commander reads to choose its counter.
func seen_fighters() -> Dictionary:
	var counts: Dictionary = {}
	for id: int in _seen:
		var kind: String = _seen[id]["kind"]
		if RtsKinds.fights(kind):
			counts[kind] = counts.get(kind, 0) + 1
	return counts


func _remember(view: RtsSnapshot) -> void:
	var shown: Dictionary = {}
	for unit: Dictionary in view.enemies():
		shown[unit["id"]] = true
		_seen[unit["id"]] = {"kind": unit["kind"], "position": unit["position"], "health": unit["health"],
			"tick": view.tick}
	for id: int in _seen.keys():
		if shown.has(id):
			continue
		var memory: Dictionary = _seen[id]
		var gone: bool = _trust(memory, view.tick) <= 0.0 and not RtsKinds.is_building(memory["kind"])
		# A building is forgotten when its cell is in sight and it is not there.
		if gone or (RtsKinds.is_building(memory["kind"]) and _in_sight(view, memory["position"])):
			_seen.erase(id)


# 1 for what is seen now, falling to 0 over MEMORY_SECONDS; a building is
# trusted until seen gone.
func _trust(memory: Dictionary, now: int) -> float:
	if RtsKinds.is_building(memory["kind"]):
		return 1.0
	var age: float = float(now - int(memory["tick"])) / RtsWorld.TICKS_PER_SECOND
	return clampf(1.0 - age / MEMORY_SECONDS, 0.0, 1.0)


static func _in_sight(view: RtsSnapshot, position: Vector2) -> bool:
	for unit: Dictionary in view.mine():
		if (unit["position"] as Vector2).distance_to(position) <= RtsKinds.sight(unit["kind"], unit["complete"]):
			return true
	return false


func _spread(layer: PackedFloat32Array, from: Vector2, weight: float) -> void:
	if weight <= 0.0:
		return
	for index: int in range(width * height):
		var centre := Vector2((index % width + 0.5) * CELL, (index / width + 0.5) * CELL)
		var distance: float = centre.distance_to(from)
		if distance < RADIUS:
			layer[index] += weight * (1.0 - distance / RADIUS)


func _index_of(cell: Vector2i) -> int:
	var column: int = clampi(cell.x / CELL, 0, width - 1)
	var row: int = clampi(cell.y / CELL, 0, height - 1)
	return row * width + column
