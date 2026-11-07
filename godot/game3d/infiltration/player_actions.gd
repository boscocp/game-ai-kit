## What the player does besides moving: throw a distraction, take a guard
## down from behind, shoot, or open and shut a door (T115).
##
## A thrown object is a T69 event where it lands, heard along the level by
## whoever is near it -- a guard who hears it goes to look, if its scores
## say so. A takedown needs the guard within reach, the player at its back,
## and the guard not alert; it leaves a body, which other guards may see,
## and a sound. A shot is the bot match's ray, from the eyes along the aim,
## stopped by the first box, and it is heard far.
##
## When not to use it: for a guard's shots. Those are `GuardActs`'.
class_name PlayerActions
extends RefCounted

## The radius of a guard's body against a shot, in metres.
const BODY: float = 0.4
const CHEST: float = 1.2
## How near a door the player must stand to open or shut it, in metres.
const DOOR_REACH: float = 1.5


## Carry out `intent`'s throw, takedown and shot in `world`.
static func apply(world: InfiltrationWorld, intent: PlayerIntent) -> void:
	var player: InfiltrationPlayer = world.player
	if intent.throw_at != Vector2.INF and intent.throw_at.distance_to(player.position) <= float(world.rules.player["throw_range"]):
		world.sounds.emit(world, "thrown_object", intent.throw_at, -1)  # not shown: an identifier
	if intent.takedown:
		_take_down(world)
	if intent.shoot != Vector3.ZERO:
		_shoot(world, intent.shoot.normalized())
	if intent.use_door:
		var door: int = door_within_reach(world)
		if door != -1:
			world.doors_open[door] = not world.doors_open[door]


## The door the player could open or shut now, by index -- the nearest
## within `DOOR_REACH` -- or -1.
static func door_within_reach(world: InfiltrationWorld) -> int:
	var nearest: int = -1
	for index: int in range(world.level.doors.size()):
		var away: float = world.player.position.distance_to(world.level.doors[index]["place"])
		if away <= DOOR_REACH and (nearest == -1 or away < world.player.position.distance_to(world.level.doors[nearest]["place"])):
			nearest = index
	return nearest


## The guard the player could take down now, or null: within reach, the
## player at its back, and not alert.
static func takedown_target(world: InfiltrationWorld) -> InfiltrationGuard:
	var behind: float = 180.0 - float(world.rules.player["takedown_behind"]) / 2.0
	for guard: InfiltrationGuard in world.guards:
		var offset: Vector2 = world.player.position - guard.position
		var near: bool = offset.length() <= float(world.rules.player["takedown_range"])
		if guard.alive() and near and not guard.alert() and GuardEyes.angle_off(guard.facing, offset) >= behind:
			return guard
	return null


static func _take_down(world: InfiltrationWorld) -> void:
	var guard: InfiltrationGuard = takedown_target(world)
	if guard == null:
		return
	down(world, guard)
	world.sounds.emit(world, "takedown", world.player.position, -1)  # not shown: an identifier


static func _shoot(world: InfiltrationWorld, aim: Vector3) -> void:
	var player: InfiltrationPlayer = world.player
	var eye: Vector3 = world.level.arena.above(player.position, world.rules.points_of(player.stance)[0])
	var reach: float = minf(float(world.rules.player["shot_range"]), world.level.arena.first_block(eye, eye + aim * float(world.rules.player["shot_range"])) * float(world.rules.player["shot_range"]))
	var struck: InfiltrationGuard = null
	var nearest: float = reach
	for guard: InfiltrationGuard in world.guards:
		var chest: Vector3 = world.level.arena.above(guard.position, CHEST)
		var along: float = (chest - eye).dot(aim)
		if guard.alive() and along > 0.0 and along < nearest and (eye + aim * along).distance_to(chest) <= BODY:
			struck = guard
			nearest = along
	world.sounds.emit(world, "shot", player.position, -1)  # not shown: an identifier
	if struck != null:
		struck.hit_at = world.time
		struck.health -= float(world.rules.player["shot_damage"])
		if not struck.alive():
			down(world, struck)


## `guard` downed where it stands: a body left, and a call it was making
## never sent.
static func down(world: InfiltrationWorld, guard: InfiltrationGuard) -> void:
	guard.health = 0.0
	guard.calling_until = -1.0
	world.bodies.append(guard.position)
