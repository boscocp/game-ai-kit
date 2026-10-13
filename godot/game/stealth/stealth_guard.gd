## One guard: what it perceives, how suspicious that makes it, and what it does.
##
## Three states, chosen by the suspicion level with a gap between going up and
## coming down, so a level hovering at a threshold does not flicker the guard
## between two minds. PATROL walks the round; INVESTIGATE walks to where the
## player was last seen or heard, and looks round when it gets there; ALERT
## chases. Every walk is an A* route over the same board the player is on.
class_name StealthGuard
extends RefCounted

const PATROL: String = "patrol"
const INVESTIGATE: String = "investigate"
const ALERT: String = "alert"

## Suspicion at which a patrolling guard goes to look.
const INVESTIGATE_AT: float = 40.0

## Suspicion at which it gives chase.
const ALERT_AT: float = 75.0

## Below this, an investigating guard gives up and goes back to its round.
const CALM_BELOW: float = 25.0

## Where `last_known` points before the player has been seen or heard.
const NOWHERE := Vector2i(-1, -1)

var unit: Unit
var facing: Vector2i = Vector2i.RIGHT
var state: String = PATROL
var suspicion := Suspicion.new()

## Where the player was last seen or heard; `NOWHERE` before either.
var last_known: Vector2i = NOWHERE

## The route the guard means to walk, next cell first. The overlay draws it.
var route: Array[Vector2i] = []

## One line saying what the guard is doing and why, for the overlay.
var reason: String = ""

var _round: Array[Vector2i] = []
var _next_waypoint: int = 0
var _search := AStarSearch.new()


func _init(guard_unit: Unit, waypoints: Array) -> void:
	unit = guard_unit
	_round.assign(waypoints)


## One turn: perceive, update suspicion, choose a state, take one step.
##
## `noise_radius` is how far the player's last action carried; 0 for none.
func take_turn(room: StealthRoom, cone: VisionCone, player: Unit, noise_radius: float,
		occupied: Array[Vector2i]) -> void:
	var seen: bool = cone.sees(room.graph, unit.cell, facing, player.cell)
	var noise: float = Hearing.loudness_at(unit.cell, player.cell, noise_radius)
	var distance: float = Vector2(player.cell - unit.cell).length()
	suspicion.observe(seen, distance, room.light_at(player.cell), noise)
	if seen or noise > 0.0:
		last_known = player.cell
	state = next_state(state, suspicion.level)
	_walk_towards(room.graph, _goal(), occupied)
	reason = _explain(seen, noise)


## The state a guard in `current` moves to at suspicion `level`.
##
## Static and pure, so the thresholds can be tested without a board. Going up
## is decided by the level alone; coming down from ALERT passes through
## INVESTIGATE, so a guard that loses sight of you goes to look first.
static func next_state(current: String, level: float) -> String:
	if level >= ALERT_AT:
		return ALERT
	if level >= INVESTIGATE_AT:
		return INVESTIGATE
	if current == PATROL or level < CALM_BELOW:
		return PATROL
	return INVESTIGATE


## The cells the guard means to walk through next, as many as `count`.
func upcoming(count: int) -> Array[Vector2i]:
	return route.slice(0, count)


func _goal() -> Vector2i:
	if state != PATROL and last_known != NOWHERE:
		return last_known
	if _round.is_empty():
		return unit.cell
	if unit.cell == _round[_next_waypoint]:
		_next_waypoint = (_next_waypoint + 1) % _round.size()
	return _round[_next_waypoint]


# One step along an A* route to `goal`, unless somebody is standing on it.
# Arrived, or blocked, the guard turns a quarter instead: looking round is
# what a guard at the spot it heard something does.
func _walk_towards(graph: GridGraph, goal: Vector2i, occupied: Array[Vector2i]) -> void:
	route = _search.find_path(graph, unit.cell, goal)
	if route.is_empty() or route[0] in occupied:
		facing = Vector2i(-facing.y, facing.x)
		return
	facing = route[0] - unit.cell
	unit.cell = route.pop_front()


func _explain(seen: bool, noise: float) -> String:
	var why: String = "sees you" if seen else ("heard %.0f%%" % (noise * 100.0) if noise > 0.0 else "nothing")
	return "%s · suspicion %.0f → %.0f · %s" % [state, suspicion.level, suspicion.alarm, why]
