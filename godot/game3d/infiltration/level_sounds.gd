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
## **A sound that goes on is heard while it goes on** (T81). The player's
## steps are one footstep every `noise_every` seconds, and a step of the
## world is shorter; a guard that heard a footstep only in the step it
## arrived heard a walking player a quarter of the time, and its awareness
## fell in between. So a sound is delivered with how long it holds -- the
## steps, their own cadence; a one-off event, a throw or a shot, none -- and
## the guard hears it in every step until it ends or another is made --
## any sound made in a later step replaces it, and within a step the louder
## wins, so a held footstep never hides a throw or a takedown.
## Not T69's event lifetime: that is how long an event is remembered and
## claimed, 4 s for a footstep, and one footstep heard for 4 s would raise
## a guard to alert.
##
## When not to use it: radios that reach any distance. Give the radio row a
## radius as large as the level, or bypass the hearing -- and then help is
## shared, and the claim that it is heard no longer holds.
class_name LevelSounds
extends RefCounted

## The kinds that carry a place and an urgency: what a guard says.
const REPORTS: Array[String] = ["radio_report", "call_for_help", "alarm", "guard_shot"]  # not shown: an identifier
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
## Whether a sound that goes on is heard for as long as it goes on. False is
## the planted case of T81: each sound heard for the one step it arrives in.
var holding: bool = true


func _init(events: StimulusTable) -> void:
	table = events


## Make a sound of `kind` at `place`, from guard `from` (-1, the player),
## carrying `carries` (a reported place, or INF) at `urgency` (0 to 1),
## going on for `hold` seconds after it is made (0, a one-off). Every
## living guard but the sender hears it, or not, by its path.
func emit(world: InfiltrationWorld, kind: String, place: Vector2, from: int, carries: Vector2 = Vector2.INF,
		urgency: float = 0.0, hold: float = 0.0) -> void:
	var radius: float = table.radius(kind)
	var reached: Dictionary[Vector2i, int] = CostFlood.within(world.level.arena.walk_graph, world.level.cell_of(place), floori(radius))
	var record: Dictionary = {"kind": kind, "place": place, "at": world.time, "from": from, "reached": reached, "heard_by": []}
	var sound: Dictionary = {"kind": kind, "place": place, "from": from, "carries": carries, "urgency": urgency, "hold": hold}
	for guard: InfiltrationGuard in world.guards:
		var listens: bool = guard.alive() and guard.id != from
		sound["loudness"] = loudness_at(world, guard, kind, reached, radius) if listens else 0.0
		if sound["loudness"] > 0.0:
			_deliver(world, guard, sound)
			record["heard_by"].append(guard.id)
	recent.append(record)
	recent = recent.filter(func(made: Dictionary) -> bool: return world.time - float(made["at"]) <= DRAWN_FOR)


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


# `sound` holds kind, place, from, carries, urgency, loudness and hold.
func _deliver(world: InfiltrationWorld, guard: InfiltrationGuard, sound: Dictionary) -> void:
	var kind: String = sound["kind"]
	if kind == "check_in":
		var known: Array = guard.partners.get(sound["from"], [0, 0.0, sound["place"]])
		guard.partners[sound["from"]] = [int(known[0]) + 1, world.time, sound["place"]]
		return
	if REPORTS.has(kind):
		_hear_report(world, guard, kind, sound["place"], sound["carries"], sound["urgency"])
		return
	var loudness: float = sound["loudness"]
	# A sound made in a later step replaces the held one, however quiet: a
	# hold keeps a walking player heard, it must not deafen the guard to a
	# throw or a takedown while the player walks (the review of wave 82).
	# Within one step, the louder wins.
	if guard.heard.is_empty() or world.time > float(guard.heard["at"]) or loudness > float(guard.heard["loudness"]):
		var hold: float = float(sound["hold"]) if holding else 0.0
		guard.heard = {"loudness": loudness, "place": sound["place"], "kind": kind, "at": world.time, "until": world.time + hold}


## What `guard` hears this step at `now`: the sound it holds, or {} -- and
## it lets go of a sound whose hold is over. A sound is heard in the step it
## arrives and in every step before its hold ends.
static func heard_now(guard: InfiltrationGuard, now: float) -> Dictionary:
	if guard.heard.is_empty():
		return {}
	var heard: Dictionary = guard.heard
	var arrived_now: bool = float(heard["at"]) == now
	if now >= float(heard["until"]):
		guard.heard = {}
	return heard if arrived_now or now < float(heard["until"]) else {}


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
