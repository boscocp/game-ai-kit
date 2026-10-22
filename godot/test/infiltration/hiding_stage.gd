## A search staged for the properties: the player lies prone at a hiding
## place no guard watches, and a radio report says it was seen a few metres
## away. How long the guards take to find it is what the belief is for.
##
## The report is a real event (`LevelSounds.emit`), heard by whoever the
## hearing reaches, carrying a place and an urgency, as a guard's would;
## nothing tells any guard where the player is. Its urgency is URGENCY,
## a guard searching rather than one in a fight. The hiding place and the
## reported place are drawn from the seed: the hiding place among the
## level's hiding places and low-cover spots no guard watches at the start,
## the reported place among the walk cells REPORTED_FROM to REPORTED_TO steps
## from it from which a body lying there cannot be seen -- the guards must
## search, not glance.
##
## When not to use it: as a scenario a player would meet. It starts in the
## middle of a search on purpose.
class_name HidingStage
extends RefCounted

const REPORTED_FROM: int = 8
const REPORTED_TO: int = 14
const FOUND_WITHIN: float = 1.5
const URGENCY: float = 0.8
## How sure a guard must be to have found the player, not glimpsed it.
const FOUND_SURE: float = 0.3


## Put the player in hiding in `world` and send the report; false when the
## level has no hiding place to stage it at.
static func stage(world: InfiltrationWorld, seed_value: int) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var hidings: Array[Vector2] = _unwatched_hidings(world)
	if hidings.is_empty():
		return false
	var hide_at: Vector2 = hidings[rng.randi_range(0, hidings.size() - 1)]
	var around: Array[Vector2] = _cells_steps_from(world, hide_at)
	if around.is_empty():
		return false
	world.player.position = hide_at
	world.player.stance = "prone"
	var reported: Vector2 = around[rng.randi_range(0, around.size() - 1)]
	world.sounds.emit(world, "radio_report", reported, -1, reported, URGENCY)
	return true


## Stage two searches at once: the player hidden as `stage` hides it, and
## two calls for help from the two guards furthest apart, each carrying the
## other's place -- heard along the level by whoever is in earshot, so the
## guards come to know two different places. False when it cannot be staged.
static func stage_two_calls(world: InfiltrationWorld, seed_value: int) -> bool:
	if world.guards.size() < 2 or not stage(world, seed_value):
		return false
	var pair: Array[InfiltrationGuard] = _furthest_apart(world.guards)
	world.sounds.emit(world, "call_for_help", pair[0].position, pair[0].id, pair[1].position, URGENCY)
	world.sounds.emit(world, "call_for_help", pair[1].position, pair[1].id, pair[0].position, URGENCY)
	return true


static func _furthest_apart(guards: Array[InfiltrationGuard]) -> Array[InfiltrationGuard]:
	var best: Array[InfiltrationGuard] = [guards[0], guards[1]]
	for pair: int in range(guards.size() * guards.size()):
		var one: InfiltrationGuard = guards[floori(pair / float(guards.size()))]
		var other: InfiltrationGuard = guards[pair % guards.size()]
		if one.position.distance_to(other.position) > best[0].position.distance_to(best[1].position):
			best = [one, other]
	return best


## True when a guard is within reach of the player or sees it.
static func found(world: InfiltrationWorld) -> bool:
	return world.guards.any(func(guard: InfiltrationGuard) -> bool:
		return guard.alive() and (guard.position.distance_to(world.player.position) <= FOUND_WITHIN or guard.percept.sight.certainty >= FOUND_SURE))


static func _unwatched_hidings(world: InfiltrationWorld) -> Array[Vector2]:
	var watched: Dictionary = SneakGraph.new(world.level, world.guards, world.rules).watched
	var found_places: Array[Vector2] = []
	for cell: Vector2i in world.level.hidden:
		if world.level.walkable(cell) and not watched.has(cell):
			found_places.append(BotArena.centre_of(cell))
	for spot: BotArena.Spot in world.level.arena.spots:
		var cell: Vector2i = world.level.cell_of(spot.position)
		if spot.low and world.level.walkable(cell) and not watched.has(cell):
			found_places.append(spot.position)
	return found_places


static func _cells_steps_from(world: InfiltrationWorld, place: Vector2) -> Array[Vector2]:
	var level: InfiltrationLevel = world.level
	var steps: PackedInt32Array = level.arena.steps_from([level.cell_of(place)])
	var lying: Vector3 = level.arena.above(place, world.rules.points_of("prone")[0])
	var found_places: Array[Vector2] = []
	for cell: Vector2i in level.cells:
		var walked: int = steps[cell.y * int(level.arena.width) + cell.x]
		var hidden_from: bool = not level.arena.clear_line(level.arena.above(BotArena.centre_of(cell), 1.6), lying)
		if walked >= REPORTED_FROM and walked <= REPORTED_TO and hidden_from:
			found_places.append(BotArena.centre_of(cell))
	return found_places
