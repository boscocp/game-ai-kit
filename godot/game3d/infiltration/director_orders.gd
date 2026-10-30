## What the director does in the infiltration level (T90): after each step
## it hands what happened to `Director`, and by the phase it reads back
## sends a reserve guard on patrol or calls one back to its post.
##
## Booth's director spawns "full threat population" while the tension
## builds and keeps it "minimal" while it fades and relaxes [Booth 2009].
## Here the threats are the level's reserve guards: in build up and the
## sustained peak it wants every one on patrol, in the fade and the relax
## none, and it acts at most once every `act_every` seconds. It sends a
## guard that stands where the player cannot see it -- a new patrol never
## appears in view -- and calls back only a calm guard that sees nothing.
##
## The director is the game, not a guard: it knows where the player is, and
## no guard learns it through the director. Sending a guard gives it a
## route, its beat, and nothing else: not the player's place, not a belief,
## not a memory. It never moves a guard otherwise, and never teleports one;
## a guard sent or called back walks.
##
## The seams `pick` and `send` are Callables so a test can plant a director
## that cheats and see the properties catch it. The game sets neither.
##
## When not to use it: on a level with no reserve. It would read the
## intensity and have nothing to send.
class_name DirectorOrders
extends RefCounted

## How much of the past the strip shows, in seconds.
const REMEMBERED: float = 60.0

var pacing: Director
var watcher: DirectorEvents
var next_act: float = 0.0
## The intensity after each step, the last REMEMBERED seconds of it.
var history: PackedFloat64Array = PackedFloat64Array()
## Every order: {time, order ("send" or "recall"), guard, from (the
## player's place), to (where the patrol starts: the guard's post)}.
var orders: Array[Dictionary] = []
## Every phase entered: {time, phase}.
var changes: Array[Dictionary] = []
## (world) -> InfiltrationGuard or null: the reserve guard to send.
var pick: Callable = DirectorOrders.unseen_reserve
## (world, guard) -> void: what sending a guard does.
var send: Callable = DirectorOrders.give_beat


func _init(world: InfiltrationWorld) -> void:
	pacing = Director.new()
	watcher = DirectorEvents.new(world)


## One step of `world` seen and paced; then, when one is due, an order.
func step(world: InfiltrationWorld) -> void:
	var entered: String = pacing.step(watcher.of(world))
	history.append(pacing.intensity)
	var kept: int = roundi(REMEMBERED / world.rules.step_seconds)
	if history.size() > kept:
		history = history.slice(history.size() - kept)
	if entered != "":
		changes.append({"time": world.time, "phase": entered})
	if world.time >= next_act:
		_order(world)


## The reserve guards on patrol now, and in all.
func on_patrol(world: InfiltrationWorld) -> Vector2i:
	var counted := Vector2i.ZERO
	for guard: InfiltrationGuard in world.guards:
		if guard.reserve():
			counted.y += 1
			counted.x += 1 if not guard.route.is_empty() else 0
	return counted


func _order(world: InfiltrationWorld) -> void:
	var counted: Vector2i = on_patrol(world)
	var wanted: int = counted.y if pacing.wants_threats() else 0
	var guard: InfiltrationGuard = null
	if counted.x < wanted:
		guard = pick.call(world)
		if guard != null:
			send.call(world, guard)
	elif counted.x > wanted:
		guard = _recallable(world)
		if guard != null:
			guard.route.clear()
			guard.route_index = 0
	if guard != null:
		var order: String = "send" if counted.x < wanted else "recall"  # not shown: identifiers
		orders.append({"time": world.time, "order": order, "guard": guard.id, "from": world.player.position, "to": guard.post})
		next_act = world.time + float(pacing.spec["act_every"])


## The reserve guard to send: one standing at its post, calm, seeing
## nothing, that the player cannot see -- the farthest from the player of
## those; null when there is none.
static func unseen_reserve(world: InfiltrationWorld) -> InfiltrationGuard:
	var best: InfiltrationGuard = null
	for guard: InfiltrationGuard in world.guards:
		var waiting: bool = guard.reserve() and guard.route.is_empty() and calm(guard)
		if waiting and not player_sees(world, guard.position):
			var farther: bool = best == null or guard.position.distance_to(world.player.position) > best.position.distance_to(world.player.position)
			best = guard if farther else best
	return best


## Sending: the guard's route becomes its beat, from the first point. The
## only thing the director writes into a guard.
static func give_beat(_world: InfiltrationWorld, guard: InfiltrationGuard) -> void:
	guard.route = guard.beat.duplicate()
	guard.route_index = 0


## True for a guard the director may move: alive, calm, and not seeing the
## player now.
static func calm(guard: InfiltrationGuard) -> bool:
	return guard.alive() and guard.mind.phase() == 0 and not guard.percept.sight.perceived()


## True when the player, standing as it stands, has a clear line from its
## eyes to a guard's head at `place`.
static func player_sees(world: InfiltrationWorld, place: Vector2) -> bool:
	var eyes: Vector3 = world.level.arena.above(world.player.position, world.rules.points_of(world.player.stance)[0])
	var head: Vector3 = world.level.arena.above(place, world.rules.guard("eye_height"))
	return world.level.arena.first_block(eyes, head) >= 1.0


# A reserve guard on patrol that the director may call back: calm.
func _recallable(world: InfiltrationWorld) -> InfiltrationGuard:
	for guard: InfiltrationGuard in world.guards:
		if guard.reserve() and not guard.route.is_empty() and calm(guard):
			return guard
	return null
