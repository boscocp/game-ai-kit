## A match: a world, a controller per side, a clock, and a record of it all.
##
## Every `decide_every` ticks each side is shown its snapshot and its
## controller answers; every command anybody gives -- a controller or a
## person, through `give` -- goes through the world's one door and is
## written down with the tick it was given on. That list, with the seed, is
## the whole recording: `replay` plays it back on a fresh world with no
## controller attached and must reach the same digest, which is how a change
## made to the world outside the door shows up.
##
## It also keeps the counters T25's league reads: for every side, how many
## decisions, how long they took and how much work they did, beside a log of
## each decision, so the totals can be checked against their parts. The clock
## is read to measure a decision, never to cut one short: a match decided by
## the clock would not replay.
##
## Headless and faster than real time: nothing here draws or waits.
##
## When not to use it: a match that needs its sides to decide at different
## rates. Then each controller wants its own cadence.
class_name RtsMatch
extends RefCounted

const FORMAT: String = "rts-commands"
const VERSION: int = 1

var world: RtsWorld
## The seed the world was built from: with `accepted`, the whole match.
var match_seed: int
## Side -> RtsController.
var controllers: Dictionary = {}
## Ticks between two decisions of each side: half a second by default.
var decide_every: int = RtsWorld.TICKS_PER_SECOND / 2
var budget := FrameBudget.new()
## Every command the world accepted: tick, side, command (as `to_dict`).
var accepted: Array[Dictionary] = []
## Every command it refused, with the reason.
var refused: Array[Dictionary] = []
## Every decision: tick, side, microseconds, the microseconds its view took
## to build, work and how many commands.
var decisions: Array[Dictionary] = []
## Side -> {decisions, microseconds, work}: the totals of `decisions`.
var counters: Dictionary = {}


## A match on `new_world`, which was built from the seed `built_from`, between
## `sides` (side -> RtsController).
func _init(new_world: RtsWorld, built_from: int, sides: Dictionary = {}) -> void:
	world = new_world
	match_seed = built_from
	controllers = sides
	for side: int in sides:
		counters[side] = {"decisions": 0, "microseconds": 0, "work": 0}


## Play `ticks` more ticks.
func play(ticks: int) -> void:
	for _tick: int in range(ticks):
		if world.tick % decide_every == 0:
			_decide_all()
		world.step(budget)


## Give `side`'s `command` now, as a person's click does; "" when the world
## took it, else why not. Either way it is written down.
func give(side: int, command: RtsCommand) -> String:
	var refusal: String = world.command(side, command)
	var entry: Dictionary = {"tick": world.tick, "side": side, "command": command.to_dict()}
	if refusal == "":
		accepted.append(entry)
	else:
		entry["reason"] = refusal
		refused.append(entry)
	return refusal


## The match as something to keep: its seed, how long it ran, and every
## command the world accepted.
func recording() -> Dictionary:
	return {"format": FORMAT, "version": VERSION, "seed": match_seed, "ticks": world.tick,
		"commands": accepted.duplicate(true)}


## Play `kept` back on `fresh`, a world built from the same seed the same way,
## with no controller: each command given on its tick, then the ticks run to
## the recording's end. "" on success, else what was wrong with the recording
## or which command the world refused -- a replay that diverges is refused.
static func replay(fresh: RtsWorld, kept: Dictionary) -> String:
	if kept.get("format") != FORMAT or kept.get("version") != VERSION:
		return "not a %s recording, version %d" % [FORMAT, VERSION]
	var commands: Array = kept.get("commands", [])
	var next: int = 0
	# Every command due on this tick is given before the tick is stepped.
	while fresh.tick < int(kept.get("ticks", 0)):
		var due: bool = next < commands.size() and int(commands[next]["tick"]) == fresh.tick
		var refusal: String = _give_recorded(fresh, commands[next], next) if due else ""
		if refusal != "":
			return refusal
		if due:
			next += 1
		else:
			fresh.step()
	return "" if next == commands.size() else "%d command(s) were never reached" % (commands.size() - next)


# Give the recorded command `entry`, the `index`th, to `fresh`: "" when the
# world took it, else what went wrong.
static func _give_recorded(fresh: RtsWorld, entry: Dictionary, index: int) -> String:
	var command: RtsCommand = RtsCommand.from_dict(entry["command"])
	if command == null:
		return "command %d is not a command" % index
	var refusal: String = fresh.command(int(entry["side"]), command)
	if refusal != "":
		return "command %d, on tick %d, was refused: %s" % [index, fresh.tick, refusal]
	return ""


# Every side decides, lowest side first, so two runs agree on the order.
func _decide_all() -> void:
	var sides: Array = controllers.keys()
	sides.sort()
	for side: int in sides:
		_decide(side)


func _decide(side: int) -> void:
	var controller: RtsController = controllers[side]
	# The view is the match's cost, the same for every controller, so it is
	# logged beside the decision and not charged to it.
	var viewing: int = Time.get_ticks_usec()
	var view: RtsSnapshot = RtsSnapshot.of(world, side)
	controller.work = 0
	var started: int = Time.get_ticks_usec()
	var commands: Array[RtsCommand] = controller.decide(view)
	var spent: int = Time.get_ticks_usec() - started
	decisions.append({"tick": world.tick, "side": side, "microseconds": spent,
		"view_microseconds": started - viewing, "work": controller.work, "commands": commands.size()})
	counters[side]["decisions"] += 1
	counters[side]["microseconds"] += spent
	counters[side]["work"] += controller.work
	for command: RtsCommand in commands:
		give(side, command)
