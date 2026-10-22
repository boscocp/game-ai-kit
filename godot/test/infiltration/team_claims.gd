## The infiltration properties about the guards together: help is heard,
## not shared, and so is what it carries; a call cut short reaches no one;
## the search is divided among guards who know the same thing; and every
## decision is on the overlay, and done.
##
## Each is a watcher for `InfiltrationRuns.play`, run with the honest world
## and with a planted one (`infiltration_properties.gd` pairs them). The
## ones that count how often they were exercised take a `counts`
## dictionary, so a run that never tested the claim is not taken for a pass.
##
## When not to use it: as the guards' code. These only watch them.
class_name TeamClaims
extends RefCounted

## Actions whose guard stands still, and what each other one walks to.
const STANDING: Array[String] = ["glance", "engage", "report", "call for help", "raise the alarm"]


## Help is heard, not shared: every report made this step was heard by
## exactly the guards with a path to it within its radius, as PathHearing
## gives them -- worked out here, not read from the world -- and every guard
## that came to know a place from a report this step heard one.
static func help_is_heard(world: InfiltrationWorld) -> String:
	for sound: Dictionary in world.sounds.recent:
		var new_report: bool = float(sound["at"]) == world.time and LevelSounds.REPORTS.has(str(sound["kind"]))
		var wrong: String = _who_should_hear(world, sound) if new_report else ""
		if wrong != "":
			return wrong
	for guard: InfiltrationGuard in world.guards:
		if _told_unheard(world, guard):
			return "guard %d knows a place from a %s it never heard" % [guard.id, guard.mind.memory.source]
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


# A guard whose memory was written from a report this step, though no
# report of that kind reached it this step.
static func _told_unheard(world: InfiltrationWorld, guard: InfiltrationGuard) -> bool:
	var memory: TargetMemory = guard.mind.memory
	if memory.at != world.time or not LevelSounds.REPORTS.has(memory.source):
		return false
	return not world.sounds.recent.any(func(sound: Dictionary) -> bool:
		return float(sound["at"]) == world.time and str(sound["kind"]) == memory.source and (sound["heard_by"] as Array).has(guard.id))


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


## The search, watched at each decision: among guards who know the same
## place, no two hold one spot and none holds a spot one of them has
## searched; and every spot a guard holds was weighed from the belief of a
## guard who knows what it knows. `counts["shared"]` counts the decisions
## with two or more guards searching together.
static func search_is_divided(counts: Dictionary) -> Callable:
	return _search_watch.bind(counts)


static func _search_watch(world: InfiltrationWorld, counts: Dictionary) -> String:
	var holding: Array[InfiltrationGuard] = []
	for guard: InfiltrationGuard in world.guards:
		if guard.alive() and guard.spot != -1 and float(world.decisions.get(guard.id, {}).get("time", -1.0)) == world.time:
			holding.append(guard)
	for guard: InfiltrationGuard in holding:
		if world.guard(guard.spot_from).spot_for != guard.spot_for:
			return "guard %d was sent by guard %d's belief, which it never heard" % [guard.id, guard.spot_from]
	for group: Array in _by_knowledge_when_given(holding):
		var wrong: String = _one_group(world, group)
		if wrong != "":
			return wrong
		counts["shared"] = int(counts.get("shared", 0)) + (1 if group.size() >= 2 else 0)
	return ""


# The holders grouped by what they knew when their spots were given --
# a report heard later in the step changes a memory, not that.
static func _by_knowledge_when_given(holding: Array[InfiltrationGuard]) -> Array:
	var groups: Dictionary = {}
	for guard: InfiltrationGuard in holding:
		if not groups.has(guard.spot_for):
			groups[guard.spot_for] = []
		groups[guard.spot_for].append(guard)
	return groups.values()


static func _one_group(world: InfiltrationWorld, group: Array) -> String:
	var members: Array[InfiltrationGuard] = []
	members.assign(group)
	var searched: Dictionary = {}
	for guard: InfiltrationGuard in members:
		if guard.searched_for == guard.spot_for:
			searched.merge(guard.searched)
	var held: Dictionary[int, int] = {}
	for guard: InfiltrationGuard in members:
		if held.has(guard.spot):
			return "guards %d and %d both hold spot %d" % [held[guard.spot], guard.id, guard.spot]
		if searched.has(guard.spot):
			return "guard %d holds spot %d, which its group has searched" % [guard.id, guard.spot]
		held[guard.spot] = guard.id
	return ""


## Planted: every searcher in one group, whatever it knows -- the search
## shared, not heard.
static func one_group(searchers: Array[InfiltrationGuard]) -> Array:
	return [searchers]


## Every decision is on the overlay, and done: each living guard's record
## is the action it is doing, with every action's score as its choice gave
## them; and a guard deciding this step walks where its action says.
static func decisions_recorded(world: InfiltrationWorld) -> String:
	for guard: InfiltrationGuard in world.guards:
		if not guard.alive() or not world.decisions.has(guard.id):
			continue
		var record: Dictionary = world.decisions[guard.id]
		if str(record["action"]) != guard.action:
			return "guard %d does %s and the overlay says %s" % [guard.id, guard.action, record["action"]]
		if Array(record["scores"]) != Array(guard.choice.scores) or (record["scores"] as Array).size() != world.actions.size():
			return "guard %d's recorded scores are not its choice's" % guard.id
		if float(record["time"]) == world.time and not _walks_its_action(world, guard):
			return "guard %d chose %s and walks to %s" % [guard.id, guard.action, guard.goal]
	return ""


# What the guard walks to, against what its action says -- unless its
# memory changed this step, after it acted (a report heard later in the
# step), and it will walk there from the next.
static func _walks_its_action(world: InfiltrationWorld, guard: InfiltrationGuard) -> bool:
	if STANDING.has(guard.action):
		return guard.goal == Vector2.INF
	if guard.mind.memory.at == world.time:
		return true
	if guard.action == "investigate":
		return guard.goal == guard.mind.memory.place
	if guard.action == "search" and guard.spot != -1:
		return guard.goal == world.team.spots[guard.spot]["place"]
	return true


## Planted: a decision taken outside the selector, after the record.
static func decide_outside(guard: InfiltrationGuard, world: InfiltrationWorld) -> void:
	GuardChoice.decide(guard, world)
	guard.action = "glance" if guard.action != "glance" else "patrol"


## Planted: an act that ignores the action chosen, and patrols.
static func act_regardless(guard: InfiltrationGuard, world: InfiltrationWorld, seconds: float) -> void:
	var chosen: String = guard.action
	guard.action = "patrol"
	GuardActs.carry(guard, world, seconds)
	guard.action = chosen
