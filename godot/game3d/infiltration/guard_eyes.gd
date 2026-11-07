## What a guard's eyes give it on the infiltration level: its look at the
## player, the cells it would have seen a hidden body in, the bodies, and
## the doors (T115).
##
## The look is T69's: the guard type's `VisionShape` at the player's
## distance and angle; each of the player's three body points -- their
## heights the stance's row -- clear or blocked by the boxes, answered by
## `BotArena`'s slab test, so a crate hides a crouched body's chest and not
## a standing one's head; light at the feet and the hiding share of the
## cell. The guard is given that percept, never the player's position.
##
## **Seen means a body there would have been perceived** (the T69 review's
## finding 10). A cell counts as searched only when a body lying prone in
## it -- the most hidden stance -- would have given this eye a certainty of
## at least the rules' `seen_threshold`, in that cell's light and hiding.
## Counting every cell in a zone with a clear line, as T69's properties did,
## zeroes the belief where a hidden player really is, and the guards lose
## them for good. One ray a cell suffices: a box stands on the floor, so if
## the line to the lowest point is clear, the lines to higher points are.
##
## Linear in the cells within the zones' reach, one ray each.
##
## When not to use it: a level with overhangs, where a high line can be
## blocked and a low one clear. Then cast to every point.
class_name GuardEyes
extends RefCounted

## The height on a door a guard's eye looks at, in metres: its middle.
const DOOR_MIDDLE: float = 1.0


## The guard's look at the player, as T69's percept: nothing of where the
## player is unless the eye perceived it.
static func look_at_player(guard: InfiltrationGuard, player: InfiltrationPlayer, level: InfiltrationLevel,
		rules: InfiltrationRules, seconds: float) -> GuardPercept:
	var made := GuardPercept.new()
	var eye: Vector3 = guard.eye(level.arena, rules)
	var points: Array[bool] = []
	for height: float in rules.points_of(player.stance):
		points.append(level.arena.clear_line(eye, level.arena.above(player.position, height)))
	var offset: Vector2 = player.position - guard.position
	made.sight = guard.type.vision.percept(offset.length(), angle_off(guard.facing, offset), points,
		guard.type.needed_for(player.stance), level.light_at(player.position), player.motion(rules, seconds) > 0.3,
		level.hidden_at(player.position))
	if made.sight.perceived():
		made.seen_place = player.position
		made.distance = offset.length()
		made.light = level.light_at(player.position)
		made.motion = player.motion(rules, seconds)
	return made


## Degrees between the guard's facing and the direction of `offset`, 0 to 180.
static func angle_off(facing: float, offset: Vector2) -> float:
	if offset == Vector2.ZERO:
		return 0.0
	return rad_to_deg(absf(Vector2.from_angle(facing).angle_to(offset)))


## The level's cells, by index, in which a body lying prone would have been
## perceived by this guard now at the rules' threshold.
static func seen_cells(guard: InfiltrationGuard, level: InfiltrationLevel, rules: InfiltrationRules) -> PackedInt32Array:
	var seen := PackedInt32Array()
	var reach: float = _reach(guard.type)
	for index: int in range(level.cells.size()):
		var place: Vector2 = BotArena.centre_of(level.cells[index])
		if place.distance_to(guard.position) <= reach and would_see(guard, level, rules, place):
			seen.append(index)
	return seen


## True when a body lying prone at `place` would give this guard's eye a
## certainty of at least `seen_threshold`.
static func would_see(guard: InfiltrationGuard, level: InfiltrationLevel, rules: InfiltrationRules, place: Vector2) -> bool:
	var offset: Vector2 = place - guard.position
	var zone: int = guard.type.vision.zone_at(offset.length(), angle_off(guard.facing, offset))
	if zone == -1:
		return false
	var lowest: float = rules.points_of("prone")[rules.points_of("prone").size() - 1]  # not shown: an identifier
	var sure: float = guard.type.vision.certainty_in(zone, level.light_at(place), false, level.hidden_at(place))
	return sure >= rules.guard("seen_threshold") and level.arena.clear_line(guard.eye(level.arena, rules), level.arena.above(place, lowest))


## Planted for the properties: T69's reading of "seen" -- in a zone with a
## clear line to a standing chest -- which zeroes a hidden player's cell.
static func seen_cells_by_line(guard: InfiltrationGuard, level: InfiltrationLevel, rules: InfiltrationRules) -> PackedInt32Array:
	var seen := PackedInt32Array()
	var reach: float = _reach(guard.type)
	for index: int in range(level.cells.size()):
		var place: Vector2 = BotArena.centre_of(level.cells[index])
		var offset: Vector2 = place - guard.position
		if offset.length() > reach or guard.type.vision.zone_at(offset.length(), angle_off(guard.facing, offset)) == -1:
			continue
		if level.arena.clear_line(guard.eye(level.arena, rules), level.arena.above(place, 1.2)):
			seen.append(index)
	return seen


## True when this guard sees a body lying at `place`: in a zone, lit enough,
## and a clear line to it.
static func sees_body(guard: InfiltrationGuard, level: InfiltrationLevel, rules: InfiltrationRules, place: Vector2) -> bool:
	return would_see(guard, level, rules, place)


## True when this guard sees the door at `place`: in one of its zones, with
## a clear line to the door's middle. A door is tall and pale, so the light
## and a hiding place's cover are not read (T115).
static func sees_door(guard: InfiltrationGuard, level: InfiltrationLevel, rules: InfiltrationRules, place: Vector2) -> bool:
	var offset: Vector2 = place - guard.position
	if guard.type.vision.zone_at(offset.length(), angle_off(guard.facing, offset)) == -1:
		return false
	return level.arena.clear_line(guard.eye(level.arena, rules), level.arena.above(place, DOOR_MIDDLE))


static func _reach(type: GuardType) -> float:
	var furthest: float = 0.0
	for zone: Dictionary in type.vision.zones:
		furthest = maxf(furthest, float(zone["far"]))
	return furthest
