## The clock's two measures of a side's play: how long it takes to answer
## what it has just seen, and how many commands it gives in a burst.
##
## T25 measures human-likeness on a turn-based board, where a clock means
## nothing; here there is one. **Reaction**: from the tick an enemy unit
## first comes into a side's sight to the first command of that side
## *about* it -- one that targets it, or walks units to within
## `ABOUT_CELLS` of where it was seen -- inside `HORIZON_SECONDS`. That is
## a proxy: nothing here can read intent, and a walk to that place for
## another reason counts too. A sighting not answered in time is not
## counted, so the measure is of the answers given, not of attention.
## **Actions**: commands per minute, and the most in any window, the burst
## AlphaStar's cap is written against.
##
## A side's sight is sampled every `SAMPLE_TICKS`, not every tick: a tenth
## of a second, finer than a decision and cheaper than every tick. The same
## functions read a league match while it plays and a person's recording
## replayed, so a team and the owner are measured one way.
##
## When not to use it: to judge whether a command was a good answer. It
## times the answer; the league's strength score judges it.
class_name RtsClockMeasure
extends RefCounted

## Ticks between two looks at what each side can see.
const SAMPLE_TICKS: int = 6
## The window the burst is counted over: AlphaStar's, five seconds.
const BURST_WINDOW_SECONDS: float = 5.0
## How near where it was seen a walk must go to be about it, in cells.
const ABOUT_CELLS: float = 8.0
## How long after a sighting a command may still be its answer.
const HORIZON_SECONDS: float = 10.0
## What a recording of a person says it is.
const PERSON: String = "person"


## Where a person's recordings of the RTS live: `data/rts/` at the top of
## the repository, beside ADR 0017's other recordings.
static func directory() -> String:
	return ProjectSettings.globalize_path("res://").path_join("../data/rts").simplify_path()


## Note every enemy unit `side` sees now for the first time in `world`:
## `seen` (id -> true) remembers, `sightings` gets {tick, id, position}.
static func look(world: RtsWorld, side: int, seen: Dictionary, sightings: Array[Dictionary]) -> void:
	for unit: RtsUnit in world.units():
		if unit.side == side or unit.side == RtsWorld.NEUTRAL or seen.has(unit.id):
			continue
		if world.visible_to(side, unit.position):
			seen[unit.id] = true
			sightings.append({"tick": world.tick, "id": unit.id, "position": unit.position})


## Play `played` to its end, looking every `SAMPLE_TICKS`. Side -> {seen,
## sightings, timeline} for every side the match has a controller for. The
## timeline is one {tick, seen, earned, orders} a look, each a running
## total, so two matches can be read at the same moment.
static func play_watched(played: RtsMatch) -> Dictionary:
	var watched: Dictionary = {}
	for side: int in played.controllers:
		watched[side] = {"seen": {}, "sightings": [] as Array[Dictionary], "timeline": [] as Array[Dictionary]}
	var orders: Dictionary = {}
	var counted: int = 0
	while RtsVictory.winner(played.world) == RtsVictory.UNDECIDED:
		for entry: Dictionary in played.accepted.slice(counted):
			orders[entry["side"]] = orders.get(entry["side"], 0) + 1
		counted = played.accepted.size()
		for side: int in watched:
			_note(played, side, watched[side], orders.get(side, 0))
		played.play(SAMPLE_TICKS)
	return watched


# One look for `side`: its sightings and a point of its timeline.
static func _note(played: RtsMatch, side: int, notes: Dictionary, orders: int) -> void:
	look(played.world, side, notes["seen"], notes["sightings"])
	notes["timeline"].append({"tick": played.world.tick, "seen": notes["seen"].size(),
		"earned": played.world.delivered.get(side, 0), "orders": orders})


## The running totals of `timeline` at `tick`: the last look at or before it.
static func at(timeline: Array, tick: int) -> Dictionary:
	var found: Dictionary = {"tick": 0, "seen": 0, "earned": 0, "orders": 0}
	for point: Dictionary in timeline:
		if point["tick"] > tick:
			break
		found = point
	return found


## Each wait, in ticks, from a sighting to `side`'s first command about it
## in `accepted` (`RtsMatch.accepted`'s entries) within the horizon.
static func reactions(sightings: Array[Dictionary], accepted: Array[Dictionary], side: int) -> Array[int]:
	var horizon: int = roundi(HORIZON_SECONDS * RtsWorld.TICKS_PER_SECOND)
	var waits: Array[int] = []
	var first: int = 0
	for sighting: Dictionary in sightings:
		while first < accepted.size() and int(accepted[first]["tick"]) < int(sighting["tick"]):
			first += 1
		var answer: int = _first_about(accepted, first, side, sighting, horizon)
		if answer >= 0:
			waits.append(answer)
	return waits


# Ticks from `sighting` to the first of `side`'s commands about it, looking
# from the `first`th entry on; -1 when none comes within `horizon`.
static func _first_about(accepted: Array[Dictionary], first: int, side: int, sighting: Dictionary, horizon: int) -> int:
	for index: int in range(first, accepted.size()):
		var after: int = int(accepted[index]["tick"]) - int(sighting["tick"])
		if after > horizon:
			return -1
		if int(accepted[index]["side"]) == side and about(accepted[index]["command"], sighting):
			return after
	return -1


## Whether `command` (as `RtsCommand.to_dict` writes it) is about
## `sighting`: it targets that unit, or walks units near where it was seen.
static func about(command: Dictionary, sighting: Dictionary) -> bool:
	if int(command.get("target", -1)) == int(sighting["id"]):
		return true
	if command.get("kind") != RtsCommand.MOVE:
		return false
	var cell: Array = command.get("cell", [-1, -1])
	return Vector2(cell[0], cell[1]).distance_to(sighting["position"]) <= ABOUT_CELLS


## The ticks `side`'s commands were given on, in order.
static func ticks_of(accepted: Array[Dictionary], side: int) -> Array[int]:
	var ticks: Array[int] = []
	for entry: Dictionary in accepted:
		if int(entry["side"]) == side:
			ticks.append(int(entry["tick"]))
	return ticks


## The most commands `side` gave in any window of `seconds`.
static func busiest(accepted: Array[Dictionary], side: int, seconds: float = BURST_WINDOW_SECONDS) -> int:
	var ticks: Array[int] = ticks_of(accepted, side)
	var window: int = roundi(seconds * RtsWorld.TICKS_PER_SECOND)
	var most: int = 0
	var first: int = 0
	for last: int in range(ticks.size()):
		while ticks[last] - ticks[first] >= window:
			first += 1
		most = maxi(most, last - first + 1)
	return most


## The middle value of `values`, or 0.0 for none.
static func median(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array = values.duplicate()
	sorted.sort()
	var middle: int = sorted.size() / 2
	return float(sorted[middle]) if sorted.size() % 2 == 1 else (sorted[middle - 1] + sorted[middle]) / 2.0


## A person's recording measured: {reactions (ticks), busiest, minutes,
## commands}, or {} when it is not a person's or does not replay.
static func of_recording(kept: Dictionary) -> Dictionary:
	if kept.get("who") != PERSON:
		return {}
	var side: int = int(kept.get("side", RtsScenario.WEST))
	var world: RtsWorld = RtsScenario.start(int(kept.get("seed", 0)))
	var seen: Dictionary = {}
	var sightings: Array[Dictionary] = []
	var commands: Array = kept.get("commands", [])
	var next: int = 0
	while world.tick < int(kept.get("ticks", 0)):
		if world.tick % SAMPLE_TICKS == 0:
			look(world, side, seen, sightings)
		var given: int = _give_due(world, commands, next)
		if given < 0:
			return {}
		next = given
		world.step()
	var accepted: Array[Dictionary] = []
	accepted.assign(commands)
	return {"reactions": reactions(sightings, accepted, side), "busiest": busiest(accepted, side),
		"minutes": world.tick / 60.0 / RtsWorld.TICKS_PER_SECOND, "commands": ticks_of(accepted, side).size()}


# Give `world` every recorded command due on its tick, from the `next`th:
# the index after the last one given, or -1 when the world refused one.
static func _give_due(world: RtsWorld, commands: Array, next: int) -> int:
	while next < commands.size() and int(commands[next]["tick"]) == world.tick:
		var command: RtsCommand = RtsCommand.from_dict(commands[next]["command"])
		if command == null or world.command(int(commands[next]["side"]), command) != "":
			return -1
		next += 1
	return next


## The clock's knobs measured from every person's recording in `folder`:
## {reaction_ms: the median wait, most_actions: the busiest window of any
## of them, window_seconds, source}; {} when there is none.
static func measured_from(folder: String) -> Dictionary:
	var waits: Array = []
	var busiest_seen: int = 0
	var counted: int = 0
	var names: PackedStringArray = DirAccess.get_files_at(folder) if DirAccess.dir_exists_absolute(folder) else PackedStringArray()
	for name: String in names:
		if not name.ends_with(".json"):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join(name)))
		var measured: Dictionary = of_recording(parsed) if parsed is Dictionary else {}
		if measured.is_empty():
			continue
		counted += 1
		waits.append_array(measured["reactions"])
		busiest_seen = maxi(busiest_seen, measured["busiest"])
	if counted == 0 or waits.is_empty():
		return {}
	return {"reaction_ms": median(waits) * 1000.0 / RtsWorld.TICKS_PER_SECOND, "most_actions": busiest_seen,
		"window_seconds": BURST_WINDOW_SECONDS, "source": "the owner's play, %d recording(s) in data/rts/" % counted}  # not shown: the league runner prints it


## Write `kept` to `folder`, named for the moment; its path, or "" when the
## file could not be written.
static func save(kept: Dictionary, folder: String) -> String:
	DirAccess.make_dir_recursive_absolute(folder)
	var name: String = "%s-%s" % [Time.get_datetime_string_from_system().replace(":", "-"), Time.get_ticks_msec()]
	var path: String = folder.path_join(name + ".json")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(JSON.stringify(kept) + "\n")
	return path
