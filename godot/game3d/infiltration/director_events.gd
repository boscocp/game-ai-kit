## What happened to the player this step, as the events `Director` reads
## (T90): the infiltration level's translation of Booth's list.
##
## Booth raises a survivor's intensity by damage taken and by an infected
## dying nearby, and stops its decay while infected engage them [Booth
## 2009]. Here, after each step of the world:
##
## - `seen` or `heard`: a guard's awareness rose a phase, by sight or by
##   sound, whichever of its awarenesses is higher;
## - `hurt`: the player lost health, with the points lost;
## - `search_near`: a guard searching, not yet alert, this many metres away;
## - `chase`: whether any guard is chasing -- alert and seeing the player,
##   Booth's "engaging" -- when that changes;
## - `exit`: the player's walk to the exit, in whole metres, when it changes.
##
## It reads the world as the game does, never a guard's belief, and writes
## nothing into it. Linear in the guards each step.
##
## When not to use it: to decide anything. It only reports.
class_name DirectorEvents
extends RefCounted

## Each guard's phase after the last step, by id.
var _phases: Dictionary[int, int] = {}
var _health: float = INF
var _chased: bool = false
var _exit_metres: int = -1
## Walk steps from the exit to every cell, row by row, read once.
var _to_exit: PackedInt32Array


func _init(world: InfiltrationWorld) -> void:
	_to_exit = world.level.arena.steps_from([world.level.cell_of(world.level.exit_place)])
	_health = world.player.health


## The events of the step `world` just took.
func of(world: InfiltrationWorld) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	_guard_events(world, events)
	if world.player.health < _health:
		events.append({"kind": "hurt", "points": _health - world.player.health})  # not shown: an identifier
	_health = world.player.health
	var chased: bool = world.guards.any(chasing)
	if chased != _chased:
		_chased = chased
		events.append({"kind": "chase", "on": chased})  # not shown: an identifier
	var metres: int = exit_metres(world)
	if metres != _exit_metres and metres >= 0:
		_exit_metres = metres
		events.append({"kind": "exit", "metres": metres})  # not shown: an identifier
	return events


## The player's walk to the exit, in metres (a walk cell is one); -1 where
## the exit cannot be walked to.
func exit_metres(world: InfiltrationWorld) -> int:
	var cell: Vector2i = world.level.cell_of(world.player.position)
	return _to_exit[cell.y * int(world.level.arena.width) + cell.x]


func _guard_events(world: InfiltrationWorld, events: Array[Dictionary]) -> void:
	var searching_from: String = str(world.rules.decision["search_from"])
	for guard: InfiltrationGuard in world.guards:
		if not guard.alive():
			continue
		var phase: int = guard.mind.phase()
		if phase > _phases.get(guard.id, 0):
			events.append({"kind": risen_by(guard)})
		_phases[guard.id] = phase
		if guard.mind.at_least(searching_from) and not guard.alert():
			events.append({"kind": "search_near", "distance": guard.position.distance_to(world.player.position)})  # not shown: an identifier


## True for a guard chasing the player: alive, alert, and seeing it. An
## alert guard searching where it last saw the player is not engaging it,
## and the intensity may fall meanwhile.
static func chasing(guard: InfiltrationGuard) -> bool:
	return guard.alive() and guard.alert() and guard.percept.sight.perceived()


## What raised `guard`'s phase: "seen" when its sight is the higher
## awareness, else "heard".
static func risen_by(guard: InfiltrationGuard) -> String:
	var sight: float = guard.mind.awareness["sight"].value
	return "seen" if sight >= guard.mind.awareness["sound"].value else "heard"  # not shown: identifiers
