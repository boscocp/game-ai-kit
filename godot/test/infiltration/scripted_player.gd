## A player the properties drive instead of a person, one of six ways:
##
## - **loud**: the shortest walk to the exit, upright and sprinting;
## - **quiet**: crouched, re-planning every half second over `SneakGraph` --
##   dark cells cheap, watched ones dear -- and lying still while the next
##   cell is watched and its own is not; the cells it crossed are kept, as
##   `trail`;
## - **replay**: a given trail, walked upright and sprinting -- the quiet
##   route walked loudly;
## - **creep**: a given trail, crouched and never stopping;
## - **still**: prone where it is, not moving -- a player already hidden;
## - **hide**: upright towards the nearest guard until a guard is alert --
##   Metal Gear's evasion -- then a sprint to a hiding place no guard
##   watches, along the cells no guard watches when it can, as far from
##   the guards as can be reached, where it lies prone and stays.
##
## It reads what a player can see -- the guards' bodies and facings, the
## light -- and never what a guard thinks. Its `PlayerIntent` is the same a
## person's keys make.
##
## When not to use it: as an opponent anyone would call clever. It is a
## repeatable route, which is what a property needs.
class_name ScriptedPlayer
extends RefCounted

const REPLAN: float = 0.5
## How far a hiding place may be, along the walk, at least and at most.
const NEAREST_HIDING: int = 6
const FURTHEST_HIDING: int = 30

var mode: String = "loud"
var path: Array[Vector2i] = []
var replan_at: float = 0.0
## The cells the quiet player crossed, in order; the replay's route.
var trail: Array[Vector2i] = []
## Where the hiding player hides, once it has run; INF until then.
var hide_at: Vector2 = Vector2.INF
## When it reached its hiding place; INF until then.
var hidden_since: float = INF
## The quiet player's last pricing of the level, rebuilt when it re-plans.
var sneaking: SneakGraph = null


func _init(how: String, route: Array[Vector2i] = []) -> void:
	mode = how
	if how == "replay" or how == "creep":
		path = route.duplicate()


## What it asks for this step in `world`.
func intent(world: InfiltrationWorld) -> PlayerIntent:
	var made := PlayerIntent.new()
	match mode:
		"quiet":
			_sneak(world, made)
		"hide":
			_show_then_hide(world, made)
		"replay":
			made.sprint = true
			made.direction = _follow(world)
		"still":
			made.stance = "prone"
		"creep":
			made.stance = "crouched"
			made.direction = _follow(world)
		_:
			made.sprint = true
			made.direction = _towards(world, world.level.exit_place, world.level.arena.walk_graph)
	return made


func _sneak(world: InfiltrationWorld, made: PlayerIntent) -> void:
	made.stance = "crouched"
	var here: Vector2i = world.level.cell_of(world.player.position)
	if trail.is_empty() or trail[trail.size() - 1] != here:
		trail.append(here)
	if world.time >= replan_at or sneaking == null:
		replan_at = world.time + REPLAN
		sneaking = SneakGraph.new(world.level, world.guards, world.rules)
		path = _plan(world, world.level.exit_place, sneaking)
	if not path.is_empty() and sneaking.watched.has(path[0]) and not sneaking.watched.has(here):
		made.stance = "prone"
		return
	made.direction = _follow(world)


func _show_then_hide(world: InfiltrationWorld, made: PlayerIntent) -> void:
	if hide_at == Vector2.INF and _someone_alert(world):
		hide_at = _hiding_place(world)
		path = _plan(world, hide_at, SneakGraph.new(world.level, world.guards, world.rules))
	if hide_at == Vector2.INF:
		made.direction = _towards(world, _nearest_guard(world), world.level.arena.walk_graph)
		return
	if world.player.position.distance_to(hide_at) <= 0.5:
		made.stance = "prone"
		hidden_since = minf(hidden_since, world.time)
		return
	made.sprint = true
	made.direction = _follow(world)


func _towards(world: InfiltrationWorld, goal: Vector2, graph: GakSearchGraph) -> Vector2:
	if world.time >= replan_at or path.is_empty():
		replan_at = world.time + REPLAN
		path = _plan(world, goal, graph)
	return _follow(world)


func _plan(world: InfiltrationWorld, goal: Vector2, graph: GakSearchGraph) -> Array[Vector2i]:
	var found: SearchResult = AStarSearch.new().search(graph, world.level.cell_of(world.player.position), world.level.cell_of(goal))
	return found.path if found.reached else ([] as Array[Vector2i])


# The way to the next cell of the path, dropping cells it would reach
# within a step -- a sprinting step is longer than half a cell, and aiming
# at a centre it overshoots turns it back and forth.
func _follow(world: InfiltrationWorld) -> Vector2:
	var reach: float = maxf(0.2, float(world.rules.player["sprint_speed"]) * world.rules.step_seconds)
	while not path.is_empty() and world.player.position.distance_to(BotArena.centre_of(path[0])) < reach:
		path.pop_front()
	if path.is_empty():
		return Vector2.ZERO
	return (BotArena.centre_of(path[0]) - world.player.position).normalized()


static func _someone_alert(world: InfiltrationWorld) -> bool:
	return world.guards.any(func(guard: InfiltrationGuard) -> bool: return guard.alive() and guard.alert())


static func _nearest_guard(world: InfiltrationWorld) -> Vector2:
	var best: Vector2 = world.level.exit_place
	for guard: InfiltrationGuard in world.guards:
		if guard.alive() and guard.position.distance_to(world.player.position) < best.distance_to(world.player.position):
			best = guard.position
	return best


# The nearest hiding place or low-cover spot no guard watches now, at least
# NEAREST_HIDING and at most FURTHEST_HIDING steps away.
static func _hiding_place(world: InfiltrationWorld) -> Vector2:
	var watched: Dictionary = SneakGraph.new(world.level, world.guards, world.rules).watched
	var steps: PackedInt32Array = world.level.arena.steps_from([world.level.cell_of(world.player.position)])
	var best: Vector2 = world.player.position
	var best_room: float = -1.0
	for place: Vector2 in _hiding_candidates(world):
		var cell: Vector2i = world.level.cell_of(place)
		var walked: int = steps[cell.y * int(world.level.arena.width) + cell.x]
		var fits: bool = walked >= NEAREST_HIDING and walked <= FURTHEST_HIDING and not watched.has(cell)
		if fits and (best_room < 0.0 or walked < best_room):
			best = place
			best_room = walked
	return best


static func _hiding_candidates(world: InfiltrationWorld) -> Array[Vector2]:
	var places: Array[Vector2] = []
	for cell: Vector2i in world.level.hidden:
		places.append(BotArena.centre_of(cell))
	for spot: BotArena.Spot in world.level.arena.spots:
		if spot.low:
			places.append(spot.position)
	return places.filter(func(place: Vector2) -> bool: return world.level.walkable(world.level.cell_of(place)))

