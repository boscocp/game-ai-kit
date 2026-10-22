## The infiltration properties about the guards together: help is heard,
## not shared; a call cut short reaches no one; the search is divided; and
## every decision is on the overlay.
##
## Each is a watcher for `InfiltrationRuns.play`, run with the honest world
## and with a planted one (`infiltration_properties.gd` pairs them).
##
## When not to use it: as the guards' code. These only watch them.
class_name TeamClaims
extends RefCounted


## Help is heard, not shared: every report made this step was heard by
## exactly the guards with a path to it within its radius, as PathHearing
## gives them -- worked out here, not read from the world.
static func help_is_heard(world: InfiltrationWorld) -> String:
	for sound: Dictionary in world.sounds.recent:
		var new_report: bool = float(sound["at"]) == world.time and LevelSounds.REPORTS.has(str(sound["kind"]))
		var wrong: String = _who_should_hear(world, sound) if new_report else ""
		if wrong != "":
			return wrong
	return ""


static func _who_should_hear(world: InfiltrationWorld, sound: Dictionary) -> String:
	var kind: String = str(sound["kind"])
	var radius: float = world.sounds.table.radius(kind)
	for guard: InfiltrationGuard in world.guards:
		if not guard.alive() or guard.id == int(sound["from"]):
			continue
		var length: float = float((sound["reached"] as Dictionary).get(world.level.cell_of(guard.position), -1))
		var should: bool = PathHearing.loudness(length, radius, world.sounds.factor_for(world, guard, kind)) > 0.0
		if should != (sound["heard_by"] as Array).has(guard.id):
			return "guard %d %s a %s with %s path to it" % [guard.id, "heard" if not should else "missed", kind, "no" if not should else "a"]
	return ""


## A watcher that cuts every call for help short -- the caller downed as it
## starts -- and finds any call from a downed caller that is sent all the
## same. `cut` counts the calls cut, so a run with none is not taken for a pass.
static func cut_calls_short(cut: Array[int]) -> Callable:
	return _cut_watch.bind(cut)


static func _cut_watch(world: InfiltrationWorld, cut: Array[int]) -> String:
	for guard: InfiltrationGuard in world.guards:
		if guard.alive() and guard.calling_until >= 0.0:
			PlayerActions.down(world, guard)
			cut.append(guard.id)
	for sound: Dictionary in world.sounds.recent:
		if str(sound["kind"]) == "call_for_help" and cut.has(int(sound["from"])):
			return "a call from guard %d was sent after it was downed" % int(sound["from"])
	return ""


## The search is divided: no two guards hold one spot, and every spot a
## guard would have seen a hidden body at is marked searched.
static func search_is_divided(world: InfiltrationWorld) -> String:
	var held: Dictionary[int, int] = {}
	for guard: InfiltrationGuard in world.guards:
		var holds: bool = guard.alive() and guard.spot != -1
		if holds and held.has(guard.spot):
			return "guards %d and %d both hold spot %d" % [held[guard.spot], guard.id, guard.spot]
		if holds:
			held[guard.spot] = guard.id
	for guard: InfiltrationGuard in world.guards:
		var unmarked: int = _seen_unmarked(world, guard)
		if unmarked != -1:
			return "spot %d was in guard %d's sight and is not marked" % [unmarked, guard.id]
	return ""


static func _seen_unmarked(world: InfiltrationWorld, guard: InfiltrationGuard) -> int:
	for index: int in range(world.team.spots.size()):
		var spot: Dictionary = world.team.spots[index]
		if guard.seen_cells.has(int(spot["cell"])) and not bool(spot["searched"]):
			return index
	return -1


## Every decision is on the overlay: each living guard's record is the
## action it is doing, with every action's score as its choice gave them.
static func decisions_recorded(world: InfiltrationWorld) -> String:
	for guard: InfiltrationGuard in world.guards:
		if not guard.alive() or not world.decisions.has(guard.id):
			continue
		var record: Dictionary = world.decisions[guard.id]
		if str(record["action"]) != guard.action:
			return "guard %d does %s and the overlay says %s" % [guard.id, guard.action, record["action"]]
		if Array(record["scores"]) != Array(guard.choice.scores) or (record["scores"] as Array).size() != world.actions.size():
			return "guard %d's recorded scores are not its choice's" % guard.id
	return ""


## Planted: a decision taken outside the selector, after the record.
static func decide_outside(guard: InfiltrationGuard, world: InfiltrationWorld) -> void:
	GuardChoice.decide(guard, world)
	guard.action = "glance" if guard.action != "glance" else "patrol"
