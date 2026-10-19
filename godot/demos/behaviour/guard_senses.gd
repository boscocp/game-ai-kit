## What the guard knows, the same for all four of its brains: how suspicious
## it is, where it thinks the intruder is, what it has looked at, and where
## its round goes next.
##
## The four brains differ in how they decide, never in what they know, so
## the facts they decide on are made here, once, and handed to whichever
## brain is playing. Perception is T14's: `VisionCone` and `Hearing` from
## `ai_perception`, and the fuzzy `Suspicion` -- a level that rises with what
## the guard sees and hears and falls without it.
##
## When not to use it: as the guard's memory of a plan or a state. That
## belongs to the brain that keeps it -- the state machine's state, the HTN's
## plan -- and keeping it here would make the four brains one.
class_name GuardSenses
extends RefCounted

## Suspicion at which a calm guard turns to look, gives chase, slows from a
## chase, and gives up: T14's thresholds, so this is T14's guard.
const SUSPICIOUS_AT: float = StealthGuard.INVESTIGATE_AT
const ALERT_AT: float = StealthGuard.ALERT_AT
const LEAVE_ALERT_BELOW: float = StealthGuard.LEAVE_ALERT_BELOW
const CALM_BELOW: float = StealthGuard.CALM_BELOW
## Turns spent looking round where it last knew the intruder to be before
## that place counts as checked.
const LOOK_TURNS: int = 2
const NOWHERE := StealthGuard.NOWHERE

var suspicion := Suspicion.new()
## Where the intruder was last seen or heard; `NOWHERE` before either.
var last_known: Vector2i = NOWHERE
## Whether the guard saw the intruder this turn.
var sees_player: bool = false
## Where the intruder stands while the guard sees it -- what a chase walks
## at -- and `NOWHERE` while it does not: a guard that tracked an unseen
## intruder would know more than it perceives.
var player_cell: Vector2i = NOWHERE
## Turns spent looking round at `last_known`.
var looked_around: int = 0

var _round: Array[Vector2i] = []
var _next_waypoint: int = 0


## A guard that walks `waypoints` in order, forever.
func _init(waypoints: Array[Vector2i]) -> void:
	_round = waypoints


## What every brain decides on, for a guard standing on `guard_cell`.
func facts(guard_cell: Vector2i) -> Dictionary:
	var gap: Vector2i = (player_cell - guard_cell).abs()
	return {
		"suspicion": suspicion.level,
		"suspicious": suspicion.level >= SUSPICIOUS_AT,
		"alerted": suspicion.level >= ALERT_AT,
		"cooling": suspicion.level < LEAVE_ALERT_BELOW,
		"calm": suspicion.level < CALM_BELOW,
		"sees_player": sees_player,
		"knows_where": last_known != NOWHERE,
		# On it, or beside it: an intruder standing still is on the very cell,
		# and a guard cannot walk onto somebody -- it walked up and stopped.
		"at_last_known": last_known != NOWHERE and absi(guard_cell.x - last_known.x) + absi(guard_cell.y - last_known.y) <= 1,
		"area_checked": looked_around >= LOOK_TURNS,
		"next_to_player": sees_player and gap.x + gap.y == 1,
		# Goals no state of the world ever already meets: a round is never
		# finished, and a caught intruder ends the game.
		"round_walked": false,
		"player_caught": false,
	}


## Look and listen from `guard_cell`, facing `facing`, with the intruder on
## `intruder` having made a noise that carries `noise_radius` cells.
func perceive(room: StealthRoom, cone: VisionCone, guard_cell: Vector2i, facing: Vector2i,
		intruder: Vector2i, noise_radius: float) -> void:
	sees_player = cone.sees(room.graph, guard_cell, facing, intruder)
	player_cell = intruder if sees_player else NOWHERE
	var noise: float = Hearing.loudness_at(guard_cell, intruder, noise_radius)
	var distance: float = Vector2(intruder - guard_cell).length()
	suspicion.observe(sees_player, distance, room.light_at(intruder), noise)
	if sees_player or noise > 0.0:
		last_known = intruder
		looked_around = 0
	elif suspicion.level < CALM_BELOW:
		last_known = NOWHERE
		looked_around = 0


## Count a turn spent looking round at the place it last knew of -- on it or
## beside it, as `facts` counts arriving.
func looked(guard_cell: Vector2i) -> void:
	if facts(guard_cell)["at_last_known"]:
		looked_around += 1


## The waypoint the round walks at next, moving on once `guard_cell` is on it.
func waypoint(guard_cell: Vector2i) -> Vector2i:
	if _round.is_empty():
		return guard_cell
	if guard_cell == _round[_next_waypoint]:
		_next_waypoint = (_next_waypoint + 1) % _round.size()
	return _round[_next_waypoint]
