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

## The numbers `guard`'s considerations read, each 0 to 1, by name.
static func numbers_of(guard: InfiltrationGuard, world: InfiltrationWorld) -> Dictionary:
	var reads: InfiltrationRules = world.rules
	var memory: TargetMemory = guard.mind.memory
	var knows: bool = memory.known and memory.age(world.time) <= reads.reading("known_for")
	return {
		"calm": 1.0 - clampf(guard.aware(), 0.0, 1.0),
		"suspicious": 1.0 if guard.mind.at_least(str(reads.decision["suspect_from"])) else 0.0,
		"searching": 1.0 if guard.mind.at_least(str(reads.decision["search_from"])) else 0.0,
		"alert": 1.0 if guard.alert() else 0.0,
		"noticed": 1.0 if world.time - guard.noticed_at <= reads.reading("noticed_for") else 0.0,
		"knows": 1.0 if knows else 0.0,
		"unreported": 1.0 if knows and memory.source == "sight" and memory.at - guard.reported_at >= world.rules.guard("report_every") else 0.0,  # not shown: an identifier
		"uncalled": 0.0 if guard.called else 1.0,
		"granted_last_known": 1.0 if guard.granted_last_known else 0.0,
		"near_last_known": 1.0 if knows and guard.position.distance_to(memory.place) <= reads.reading("near_last_known") else 0.0,
		"has_spot": 1.0 if guard.spot != -1 else 0.0,
		"has_way_out": 1.0 if guard.way_out != Vector2.INF else 0.0,
		"can_shoot": 1.0 if can_shoot(guard, world) else 0.0,
		"shooter": 1.0 if guard.role == RoleArbiter.SHOOTER else 0.0,
		"flanker": 1.0 if guard.role == RoleArbiter.FLANKER else 0.0,
		"under_fire": 1.0 if world.time - guard.hit_at <= reads.reading("under_fire_for") else 0.0,
		"hurt": 1.0 - guard.health / world.rules.guard("health"),
		"body_unraised": 1.0 if guard.body_unraised != Vector2.INF else 0.0,
		"partner_quiet": 1.0 if guard.quiet_place != Vector2.INF else 0.0,
		"away": clampf(_away(guard) / reads.reading("away_scale"), 0.0, 1.0),
	}


## True when the guard sees the player now surely enough to shoot -- at
## least `shoot_certainty` -- with the chest among the points its eye saw,
## and within range of where it saw it: all from its percept, nothing from
## where the player really is.
static func can_shoot(guard: InfiltrationGuard, world: InfiltrationWorld) -> bool:
	var sight: VisionPercept = guard.percept.sight
	if sight.certainty < world.rules.guard("shoot_certainty") or sight.points.size() < 2 or not sight.points[1]:
		return false
	return guard.percept.distance <= float(world.rules.player["shot_range"])


## Score every action from `guard`'s numbers, take the highest, and record
## the whole decision in `world.decisions`.
static func decide(guard: InfiltrationGuard, world: InfiltrationWorld) -> void:
	guard.numbers = numbers_of(guard, world)
	guard.choice = ActionChoice.choose(world.actions, guard.numbers)
	guard.action = world.actions[guard.choice.chosen].name if guard.choice.chosen != -1 else "patrol"  # not shown: an identifier
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
