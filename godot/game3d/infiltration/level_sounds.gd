## Every sound on the infiltration level, and who hears it: the player's
## steps and shots, a thrown distraction, a takedown, and the guards' own
## radio reports, calls for help, alarms, shots and check-ins.
##
## **Help is heard, not shared.** A call or a report is a T69 event like a
## footstep: its row in `guard_types.json` gives its radius, it floods the
## level's walk graph (`CostFlood`) from where it was made, and each guard
## hears it at the loudness `PathHearing` gives its path length -- so who
## learns it is who heard it [Miles 2013; Walsh 2015]. A report carries a
## place and how sure its sender was; a guard who hears it remembers that
## place, puts its belief there, and becomes as aware as the sender was --
## the content of the message, not a rule about guards.
##
## The off-screen halving is T69's factor, tied to the camera: a guard off
## screen and far from the player hears minor events at half the radius
## [Walsh 2015]. Which guard is on screen is the demo's to say.
##
## Each sound is a flood over the cells within its radius.
##
## When not to use it: radios that reach any distance. Give the radio row a
## radius as large as the level, or bypass the hearing -- and then help is
## shared, and the claim that it is heard no longer holds.
class_name LevelSounds
extends RefCounted

## The kinds that carry a place and an urgency: what a guard says.
const REPORTS: Array[String] = ["radio_report", "call_for_help", "alarm", "guard_shot"]
## How long a sound stays drawn, for the overlay's rings.
const DRAWN_FOR: float = 1.5

var table: StimulusTable
## Recent sounds, newest last, for the overlay: {kind, place, at, from,
## reached (cell -> metres), heard_by (guard ids)}.
var recent: Array[Dictionary] = []
## How a guard hears: (path length, radius, factor) -> loudness. The
## properties plant another; the game uses `PathHearing`'s.
var hearing: Callable = PathHearing.loudness
## Which guards are on screen: (guard) -> bool. The demo sets the camera's.
var on_screen: Callable = func(_guard: InfiltrationGuard) -> bool: return true


func _init(events: StimulusTable) -> void:
	table = events


## Make a sound of `kind` at `place`, from guard `from` (-1, the player),
## carrying `carries` (a reported place, or INF) at `urgency` (0 to 1).
## Every living guard but the sender hears it, or not, by its path.
func emit(world: InfiltrationWorld, kind: String, place: Vector2, from: int, carries: Vector2 = Vector2.INF,
		urgency: float = 0.0) -> void:
	var radius: float = table.radius(kind)
	var reached: Dictionary[Vector2i, int] = CostFlood.within(world.level.arena.walk_graph, world.level.cell_of(place), floori(radius))
	var record: Dictionary = {"kind": kind, "place": place, "at": world.time, "from": from, "reached": reached, "heard_by": []}
	for guard: InfiltrationGuard in world.guards:
		var listens: bool = guard.alive() and guard.id != from
		var loudness: float = loudness_at(world, guard, kind, reached, radius) if listens else 0.0
		if loudness > 0.0:
			_deliver(world, guard, kind, place, from, carries, urgency, loudness)
			record["heard_by"].append(guard.id)
	recent.append(record)
	recent = recent.filter(func(sound: Dictionary) -> bool: return world.time - float(sound["at"]) <= DRAWN_FOR)


## How loud a sound of `kind` and `radius`, whose flood is `reached`, is
## where `guard` stands.
func loudness_at(world: InfiltrationWorld, guard: InfiltrationGuard, kind: String, reached: Dictionary, radius: float) -> float:
	var length: float = float(reached.get(world.level.cell_of(guard.position), -1))
	return hearing.call(length, radius, factor_for(world, guard, kind))


## The factor a guard's radius is scaled by for `kind`: T69's off-screen
## halving when the knob is on, and 1 otherwise. It reads the guard's true
## distance from the player, on the engine's side: the halving is a rule
## about the camera, not something the guard perceives -- as T69's
## technique is.
func factor_for(world: InfiltrationWorld, guard: InfiltrationGuard, kind: String) -> float:
	if not world.rules.off_screen_halving:
		return 1.0
	return SoundPaths.listener_factor(guard.type.hearing, table.priority(kind), bool(on_screen.call(guard)),
		guard.position.distance_to(world.player.position))


func _deliver(world: InfiltrationWorld, guard: InfiltrationGuard, kind: String, place: Vector2, from: int,
		carries: Vector2, urgency: float, loudness: float) -> void:
	if kind == "check_in":
		var known: Array = guard.partners.get(from, [0, 0.0, place])
		guard.partners[from] = [int(known[0]) + 1, world.time, place]
		return
	if REPORTS.has(kind):
		_hear_report(world, guard, kind, place, carries, urgency)
		return
	if loudness > float(guard.heard.get("loudness", 0.0)):
		guard.heard = {"loudness": loudness, "place": place, "kind": kind}


# A report: the place it carries is remembered and believed, and the
# hearer is as aware as its sender was.
func _hear_report(world: InfiltrationWorld, guard: InfiltrationGuard, kind: String, place: Vector2,
		carries: Vector2, urgency: float) -> void:
	guard.help_heard_at = world.time
	var told: Vector2 = carries if carries != Vector2.INF else place
	guard.mind.memory.remember(told, world.time, kind)
	if world.rules.use_belief and world.level.walkable(world.level.cell_of(told)):
		guard.belief.collapse(world.level.index_of[world.level.cell_of(told)])
	var sound: Awareness = guard.mind.awareness["sound"]
	sound.value = maxf(sound.value, clampf(urgency, 0.0, 1.0) * float(guard.type.awareness["peak"]))
