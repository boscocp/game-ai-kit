## What an infiltration guard decides: every action it could take scored
## by T67's selector from what it perceives, knows and was given -- and the
## whole decision kept for the overlay.
##
## The owner's rule: the guard is an agent that weighs what it perceives,
## with as few fixed if/else as possible. So the phases, the search, the
## report, the call for help and the fight are each an action in
## `guard_actions.json`, and this file has no branch that picks one: it
## only turns the guard's state into the numbers the considerations read
## (`numbers_of`), asks `ActionChoice`, and writes down what it answered.
## Change the data and the guard weighs differently; no line here says
## which action comes first.
##
## Every decision is recorded -- the action taken, every action's score and
## the numbers behind them -- so the overlay draws what the guard weighed,
## not a guess at it (invariant 13).
##
## O(actions x considerations) a decision.
##
## When not to use it: a guard that must finish what it started -- a call
## for help half said. That is the action's own commitment (`GuardActs`),
## not a weighing.
class_name GuardChoice
extends RefCounted

## How long a heard sound or a glimpse counts as "noticed".
const NOTICED_FOR: float = 3.0
## How long a remembered place counts as known.
const KNOWN_FOR: float = 60.0
const UNDER_FIRE_FOR: float = 2.0


## The numbers `guard`'s considerations read, each 0 to 1, by name.
static func numbers_of(guard: InfiltrationGuard, world: InfiltrationWorld) -> Dictionary:
	var phase: int = guard.mind.phase()
	var memory: TargetMemory = guard.mind.memory
	var knows: bool = memory.known and memory.age(world.time) <= KNOWN_FOR
	return {
		"calm": 1.0 - clampf(guard.aware(), 0.0, 1.0),
		"suspicious": 1.0 if phase >= 1 else 0.0, "searching": 1.0 if phase >= 2 else 0.0,
		"alert": 1.0 if guard.alert() else 0.0,
		"noticed": 1.0 if world.time - guard.noticed_at <= NOTICED_FOR else 0.0,
		"knows": 1.0 if knows else 0.0,
		"unreported": 1.0 if knows and memory.source == "sight" and memory.at - guard.reported_at >= world.rules.guard("report_every") else 0.0,
		"uncalled": 0.0 if guard.called else 1.0,
		"granted_last_known": 1.0 if guard.granted_last_known else 0.0,
		"near_last_known": 1.0 if knows and guard.position.distance_to(memory.place) <= 2.0 else 0.0,
		"has_spot": 1.0 if guard.spot != -1 else 0.0,
		"has_way_out": 1.0 if guard.way_out != Vector2.INF else 0.0,
		"can_shoot": 1.0 if can_shoot(guard, world) else 0.0,
		"shooter": 1.0 if guard.role == RoleArbiter.SHOOTER else 0.0,
		"flanker": 1.0 if guard.role == RoleArbiter.FLANKER else 0.0,
		"under_fire": 1.0 if world.time - guard.hit_at <= UNDER_FIRE_FOR else 0.0,
		"hurt": 1.0 - guard.health / world.rules.guard("health"),
		"body_unraised": 1.0 if guard.body_unraised != Vector2.INF else 0.0,
		"partner_quiet": 1.0 if guard.quiet_place != Vector2.INF else 0.0,
		"away": clampf(_away(guard) / 5.0, 0.0, 1.0),
	}


## True when the guard sees the player now, in range, with a clear line to
## the chest.
static func can_shoot(guard: InfiltrationGuard, world: InfiltrationWorld) -> bool:
	if not guard.percept.sight.perceived():
		return false
	var chest: float = world.rules.points_of(world.player.stance)[1]
	var clear: bool = world.level.arena.clear_line(guard.eye(world.level.arena, world.rules), world.level.arena.above(world.player.position, chest))
	return clear and guard.position.distance_to(world.player.position) <= float(world.rules.player["shot_range"])


## Score every action from `guard`'s numbers, take the highest, and record
## the whole decision in `world.decisions`.
static func decide(guard: InfiltrationGuard, world: InfiltrationWorld) -> void:
	guard.numbers = numbers_of(guard, world)
	guard.choice = ActionChoice.choose(world.actions, guard.numbers)
	guard.action = world.actions[guard.choice.chosen].name if guard.choice.chosen != -1 else "patrol"
	world.decisions[guard.id] = record_of(guard, world)


## The decision as the overlay keeps it: when, the action taken, and every
## action's name and score.
static func record_of(guard: InfiltrationGuard, world: InfiltrationWorld) -> Dictionary:
	var names: Array = []
	for action: ActionChoice.Action in world.actions:
		names.append(action.name)
	return {"time": world.time, "action": guard.action, "names": names, "scores": Array(guard.choice.scores),
		"numbers": guard.numbers.duplicate()}


# Metres from its route -- the nearest point on any leg of the loop -- or
# from its post when it has no route.
static func _away(guard: InfiltrationGuard) -> float:
	if guard.route.size() < 2:
		return guard.position.distance_to(guard.post)
	var nearest: float = INF
	for index: int in range(guard.route.size()):
		var leg_end: Vector2 = guard.route[(index + 1) % guard.route.size()]
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(guard.position, guard.route[index], leg_end)
		nearest = minf(nearest, guard.position.distance_to(closest))
	return nearest
