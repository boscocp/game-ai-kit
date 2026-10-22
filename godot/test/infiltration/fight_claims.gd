## The infiltration properties about a fight and about what is heard: the
## arbiter keeps one flanker and someone shooting, and a glimpse starts no
## shooting; the off-screen halving only lowers what a guard grows aware of.
##
## Each is a watcher for `InfiltrationRuns.play` or a comparison of runs,
## held with the honest world and with a planted one.
##
## When not to use it: as the guards' code. These only watch them.
class_name FightClaims
extends RefCounted

## Seconds from an alert guard able to shoot to a shot: its reaction, a
## decision's wait, a shot's interval, and two steps of slack.
const SLACK: float = 0.2


## The arbiter, watched: at most one flanker; every shot fired on a
## decision taken in the alert phase -- the phase is the exact peak, and a
## guard's sight blinking mid-fight dips it, so it is the decision that is
## held, not the step; and a guard alert and able to shoot for the window has been
## shot by someone. `since` keeps, per guard, when it last became able.
static func arbiter_holds(since: Dictionary) -> Callable:
	return _arbiter_watch.bind(since)


static func _arbiter_watch(world: InfiltrationWorld, since: Dictionary) -> String:
	var flankers: int = world.guards.filter(_flanking).size()
	if flankers > 1:
		return "%d guards flank at once" % flankers
	for shot: Dictionary in world.shots:
		if float(shot["at"]) == world.time and not _decided_alert(world, int(shot["from"])):
			return "guard %d shot on a decision taken below alert" % int(shot["from"])
	return _shot_in_time(world, since)


static func _flanking(guard: InfiltrationGuard) -> bool:
	return guard.alive() and guard.role == RoleArbiter.FLANKER


# The guard's last decision was taken in the alert phase, by its record.
static func _decided_alert(world: InfiltrationWorld, guard: int) -> bool:
	var record: Dictionary = world.decisions.get(guard, {})
	return not record.is_empty() and float(record["numbers"]["alert"]) == 1.0


static func _shot_in_time(world: InfiltrationWorld, since: Dictionary) -> String:
	var window: float = world.rules.reaction + world.rules.decision_seconds + world.rules.guard("shot_interval") + SLACK
	for guard: InfiltrationGuard in world.guards:
		var able: bool = guard.alive() and guard.alert() and GuardChoice.can_shoot(guard, world)
		since[guard.id] = minf(float(since.get(guard.id, INF)), world.time) if able else INF
		var waited: float = world.time - float(since[guard.id])
		if able and waited >= window and not _shot_since(world, float(since[guard.id])):
			return "guard %d was alert and able to shoot for %.1f s and no one shot" % [guard.id, waited]
	return ""


static func _shot_since(world: InfiltrationWorld, time: float) -> bool:
	return world.shots.any(func(shot: Dictionary) -> bool: return float(shot["at"]) >= time)


## Planted: a guard that never shoots -- whatever it chose, it glances.
static func never_shoots(guard: InfiltrationGuard, world: InfiltrationWorld) -> void:
	GuardChoice.decide(guard, world)
	if guard.action == "engage":
		guard.action = "glance"


## Planted: a guard that opens fire on a glimpse, below alert.
static func shoots_on_a_glimpse(guard: InfiltrationGuard, world: InfiltrationWorld) -> void:
	GuardChoice.decide(guard, world)
	if not guard.alert() and guard.percept.sight.perceived():
		guard.action = "engage"


## Planted: an arbiter that grants two flanks.
static func two_flankers(requests: Array[Dictionary], use: bool) -> PackedStringArray:
	return RoleArbiter.grant(requests, use, 2)


## The highest sound awareness each guard reaches as `trail` -- the quiet
## route -- is walked loudly on `level`, halving on or off, guards within 10
## m of the player on screen, until any guard first sees the player: the
## halving changes what is heard, and up to a sighting the two runs are the
## same run. `hearing` replaces the world's when valid.
static func awareness_reached(level: InfiltrationLevel, trail: Array[Vector2i], halving: bool,
		hearing: Callable = Callable()) -> PackedFloat64Array:
	var rules: InfiltrationRules = InfiltrationRules.read()
	rules.off_screen_halving = halving
	var world: InfiltrationWorld = InfiltrationWorld.make(level, rules, 1)
	world.sounds.on_screen = func(guard: InfiltrationGuard) -> bool: return guard.position.distance_to(world.player.position) <= 10.0
	if hearing.is_valid():
		world.sounds.hearing = hearing.bind(world)
	# An Array, not a packed one: a lambda captures a packed array by value.
	var highest: Array = []
	highest.resize(world.guards.size())
	highest.fill(0.0)
	var watch: Callable = func(seen: InfiltrationWorld) -> String:
		for guard: InfiltrationGuard in seen.guards:
			highest[guard.id] = maxf(float(highest[guard.id]), guard.mind.awareness["sound"].value)
		return ""
	var stop: Callable = func(seen: InfiltrationWorld) -> bool:
		return seen.guards.any(func(guard: InfiltrationGuard) -> bool: return guard.percept.sight.perceived())
	InfiltrationRuns.play(world, ScriptedPlayer.new("replay", trail), watch, stop)
	# The world's Callables hold the world: let them go, or it never frees.
	world.sounds.on_screen = Callable()
	world.sounds.hearing = PathHearing.loudness
	return PackedFloat64Array(highest)


## Planted: the halving's factor applied as a gain -- every radius doubled
## whenever the halving is on.
static func halving_as_gain(length: float, radius: float, factor: float, world: InfiltrationWorld) -> float:
	return PathHearing.loudness(length, radius * (2.0 if world.rules.off_screen_halving else 1.0), factor)


## The halving only lowers: no guard more aware with it on than off.
static func only_lowers(with_it: PackedFloat64Array, without_it: PackedFloat64Array) -> String:
	for index: int in range(with_it.size()):
		if with_it[index] > without_it[index] + 1e-9:
			return "guard %d reached %.2f with the halving on and %.2f off" % [index, with_it[index], without_it[index]]
	return ""
