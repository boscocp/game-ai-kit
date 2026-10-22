## How an infiltration guard carries out the action it chose: where it
## walks, where it looks, and what it says or fires.
##
## Each action is a place to go and a way to look, and a few say something
## -- a radio report, a call for help, an alarm -- which `LevelSounds`
## carries to whoever is in earshot. A call takes `call_seconds` to say,
## and a guard downed before it finishes sends nothing [Wikipedia, MGS2:
## the radio can be cut]. The pace is the guard's awareness: a walk while
## calm, a run as it rises -- the cautious search and the aggressive one
## are this one line, not two code paths [Welsh 2015]. Turning is held to
## the difficulty's turn rate, and a shot waits the reaction time after the
## guard first saw the player.
##
## A walk is `ai_search`'s A* over the level's walk graph, searched again
## only when the goal moves to another cell.
##
## When not to use it: to decide. What to do is `GuardChoice`'s.
class_name GuardActs
extends RefCounted

const ARRIVED: float = 0.4


## One step of `seconds` of `guard` doing its chosen action in `world`.
static func carry(guard: InfiltrationGuard, world: InfiltrationWorld, seconds: float) -> void:
	var look: Vector2 = _act(guard, world)
	_walk(guard, world, seconds)
	_turn(guard, world, look, seconds)


# Set where the chosen action walks to, do what it does, and answer where
# it looks; INF, the way it walks.
static func _act(guard: InfiltrationGuard, world: InfiltrationWorld) -> Vector2:
	match guard.action:
		"patrol":
			return _patrol(guard)
		"glance":
			return _glance(guard)
		"investigate":
			guard.goal = guard.mind.memory.place
		"search":
			guard.goal = world.team.spots[guard.spot]["place"] if guard.spot != -1 else Vector2.INF
		"cover a way out":
			guard.goal = guard.way_out
			return guard.mind.memory.place
		"check on a partner":
			_check_on_partner(guard)
		"engage":
			return _engage(guard, world)
		"flank":
			guard.goal = flank_point(guard, world)
		"take cover":
			guard.goal = cover_from(guard, world)
		"return":
			guard.goal = _nearest_home(guard)
		_:
			return _speak(guard, world)
	return Vector2.INF


static func _glance(guard: InfiltrationGuard) -> Vector2:
	guard.goal = Vector2.INF
	return guard.percept.seen_place if guard.percept.sight.perceived() else guard.heard.get("place", Vector2.INF)


# Walk to where the partner was last heard; there, the worry is settled.
static func _check_on_partner(guard: InfiltrationGuard) -> void:
	guard.goal = guard.quiet_place
	if guard.quiet_place != Vector2.INF and guard.position.distance_to(guard.quiet_place) <= 1.5:
		guard.quiet_place = Vector2.INF


static func _engage(guard: InfiltrationGuard, world: InfiltrationWorld) -> Vector2:
	guard.goal = Vector2.INF
	_shoot(guard, world)
	return world.player.position if guard.percept.sight.perceived() else guard.mind.memory.place


## Where a flanker goes: beside the last known position, a flank distance
## off the line from the guard to it, on whichever side can be stood on.
static func flank_point(guard: InfiltrationGuard, world: InfiltrationWorld) -> Vector2:
	var target: Vector2 = guard.mind.memory.place
	var side: Vector2 = (target - guard.position).orthogonal().normalized() * world.rules.guard("flank_distance")
	for place: Vector2 in [target + side, target - side]:
		if world.level.walkable(world.level.cell_of(place)):
			return place
	return target


## The nearest cover spot whose box stands between it and the last known
## position; where the guard is, when none does.
static func cover_from(guard: InfiltrationGuard, world: InfiltrationWorld) -> Vector2:
	var best: Vector2 = guard.position
	var nearest: float = INF
	var threat: Vector3 = world.level.arena.above(guard.mind.memory.place, 1.2)
	for spot: BotArena.Spot in world.level.arena.spots:
		var away: float = spot.position.distance_to(guard.position)
		if away < nearest and not world.level.arena.clear_line(world.level.arena.above(spot.position, 1.0), threat):
			best = spot.position
			nearest = away
	return best


# The route's next point, or the post; it looks the post's way there.
static func _patrol(guard: InfiltrationGuard) -> Vector2:
	if guard.route.size() > 1:
		if guard.position.distance_to(guard.route[guard.route_index]) <= ARRIVED:
			guard.route_index = (guard.route_index + 1) % guard.route.size()
		guard.goal = guard.route[guard.route_index]
		return Vector2.INF
	guard.goal = guard.post if guard.position.distance_to(guard.post) > ARRIVED else Vector2.INF
	return guard.position + Vector2.from_angle(guard.post_facing) if guard.goal == Vector2.INF else Vector2.INF


static func _nearest_home(guard: InfiltrationGuard) -> Vector2:
	var best: Vector2 = guard.post
	for point: Vector2 in guard.route:
		if guard.position.distance_to(point) < guard.position.distance_to(best):
			best = point
	return best


# The actions that say something: a report, a call for help, an alarm.
# Each stands still and looks where the news is.
static func _speak(guard: InfiltrationGuard, world: InfiltrationWorld) -> Vector2:
	guard.goal = Vector2.INF
	var memory: TargetMemory = guard.mind.memory
	match guard.action:
		"report":
			world.sounds.emit(world, "radio_report", guard.position, guard.id, memory.place, guard.aware())
			guard.reported_at = world.time
		"call for help":
			_start_call(guard, world)
		"raise the alarm":
			world.sounds.emit(world, "alarm", guard.position, guard.id, guard.body_unraised, 1.0)
			guard.bodies_known.append(guard.body_unraised)
			guard.body_unraised = Vector2.INF
	return memory.place if memory.known else Vector2.INF


# A call takes its time to say; `InfiltrationWorld` sends it when said.
static func _start_call(guard: InfiltrationGuard, world: InfiltrationWorld) -> void:
	if guard.calling_until < 0.0 and not guard.called:
		guard.calling_until = world.time + world.rules.guard("call_seconds")


static func _shoot(guard: InfiltrationGuard, world: InfiltrationWorld) -> void:
	var ready: bool = world.time >= guard.next_shot_at and world.time - guard.sees_since >= world.rules.reaction
	if not ready or not GuardChoice.can_shoot(guard, world):
		return
	guard.next_shot_at = world.time + world.rules.guard("shot_interval")
	var distance: float = guard.position.distance_to(world.player.position)
	var hit: bool = world.rng.randf() < clampf(1.0 - world.rules.aim_error * distance, 0.05, 0.95)
	if hit:
		world.player.health -= world.rules.guard("shot_damage")
	world.shots.append({"from": guard.id, "at": world.time, "hit": hit})
	world.sounds.emit(world, "guard_shot", guard.position, guard.id, world.player.position, 1.0)


static func _walk(guard: InfiltrationGuard, world: InfiltrationWorld, seconds: float) -> void:
	if guard.goal == Vector2.INF or not is_finite(guard.goal.x):
		return
	var level: InfiltrationLevel = world.level
	var goal_cell: Vector2i = level.cell_of(guard.goal)
	if goal_cell != guard.path_goal:
		guard.path_goal = goal_cell
		var found: SearchResult = AStarSearch.new().search(level.arena.walk_graph, level.cell_of(guard.position), goal_cell)
		guard.path = found.path if found.reached else ([] as Array[Vector2i])
	var speed: float = lerpf(world.rules.guard("walk_speed"), world.rules.guard("run_speed"), clampf(guard.aware(), 0.0, 1.0))
	var left: float = speed * seconds
	while left > 0.0 and not guard.path.is_empty():
		var next: Vector2 = BotArena.centre_of(guard.path[0])
		var step: float = minf(left, guard.position.distance_to(next))
		guard.position = guard.position.move_toward(next, step)
		left -= step
		if guard.position.distance_to(next) < 0.01:
			guard.path.pop_front()


# Face `look`, or the way it walks, no faster than the turn rate.
static func _turn(guard: InfiltrationGuard, world: InfiltrationWorld, look: Vector2, seconds: float) -> void:
	var toward: Vector2 = look
	if toward == Vector2.INF and not guard.path.is_empty():
		toward = BotArena.centre_of(guard.path[0])
	if toward == Vector2.INF or not is_finite(toward.x) or toward.distance_to(guard.position) < 0.05:
		return
	var wanted: float = (toward - guard.position).angle()
	guard.facing = rotate_toward(guard.facing, wanted, deg_to_rad(world.rules.turn_rate) * seconds)
