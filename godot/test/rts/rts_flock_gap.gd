# T151's planted case: T19's wall-gap jam, and the flock through the same gap.
#
# The scene is `make test-rts-budget`'s: two armies of a hundred shields
# either side of a wall with three gaps, each army dealt into four groups
# and sent through the gaps at the other, for the budget's twenty seconds.
# It is walked three ways, by the world's crowd (`GakRtsCrowd`):
#
#   1. the core's own column -- the base crowd -- as a reference, printed;
#   2. planted: T19's jam put back. Every unit on a move order is nudged off
#      everybody too near, enemies included, a stride a tick -- what the
#      core did before `RtsWorld._keep_apart` was kept off move orders. It
#      must be refused: the check below has to see a jam;
#   3. the flock (`RtsFlock`), which must not jam.
#
# Jammed: a unit on its move order standing in a gap -- within two cells of
# the wall's column -- for more than twice the time walking across takes.
# One such unit is a jam. And the flock's
# twenty seconds are timed: the simulation's share of the frame must hold
# with it, since its cost is counted there (judged on a desk, reported on
# a shared CI runner, as `test-rts-budget` does).
#
#     python3 scripts/godot_checked.py res://test/rts/rts_flock_gap.gd
#
# Exit codes: 0 the jam was seen and the flock had none; 1 otherwise.
extends SceneTree

const SEED: int = 19
const PER_SIDE: int = 100
const TICKS: int = 1200
## The budget's goals for the left army; the right's are mirrored.
const GOALS: Array[Vector2i] = [Vector2i(36, 12), Vector2i(36, 30), Vector2i(36, 34), Vector2i(36, 52)]
## How near the wall's column counts as standing in a gap, in cells.
const IN_THE_GAP: float = 2.0
## Ticks in a gap, on a move order, that make a jam: twice the time a
## shield takes to walk across those four cells (2.2 s at 1.8 cells a
## second). Measured: every unit of the column and of the flock is through
## in under three seconds; the planted nudge holds 19 there for five to ten.
const JAMMED_AFTER: int = int(2.0 * 2.0 * IN_THE_GAP / 1.8 * RtsWorld.TICKS_PER_SECOND)


## T19's jam, planted: the core's straight step, then a push off everybody
## within the core's personal space -- both sides -- of up to a stride.
class JammingCrowd extends GakRtsCrowd:
	# A weak reference: the world holds its crowd, and a crowd holding the
	# world back would be a cycle never freed.
	var _world: WeakRef

	## Keeps the world, to ask who is near.
	func before_moves(world: RtsWorld) -> void:
		_world = weakref(world)

	## The straight step, then pushed off whoever stands too near it.
	func step_to(unit: RtsUnit, waypoint: Vector2, stride: float) -> Vector2:
		var world: RtsWorld = _world.get_ref()
		var to: Vector2 = unit.position.move_toward(waypoint, stride)
		var push := Vector2.ZERO
		for id: int in world.spatial.near(to, RtsWorld.PERSONAL_SPACE):
			var apart: Vector2 = to - world.unit(id).position
			if id != unit.id and apart.length() > 0.0:
				push += apart.normalized() * (RtsWorld.PERSONAL_SPACE - apart.length())
		var pushed: Vector2 = to + push.limit_length(stride)
		return to if world.graph.is_blocked(Vector2i(pushed.floor())) else pushed


func _init() -> void:
	var failures: Array[String] = []
	var column: Dictionary = _walk("the core's column", GakRtsCrowd.new())
	var planted: Dictionary = _walk("planted, T19's nudge on a move", JammingCrowd.new())
	if planted["jammed"] == 0:
		failures.append("the planted jam was not seen: the check cannot tell a jam")
	var flock := RtsFlock.new()
	flock.on = true
	var flocked: Dictionary = _walk("the flock", flock)
	if flocked["jammed"] > 0:
		failures.append("the flock jammed %d unit(s) in the gaps for twenty seconds" % flocked["jammed"])
	if flocked["arrived"] < column["arrived"] / 2:
		failures.append("the flock got %d unit(s) to their goals, the column %d" % [flocked["arrived"], column["arrived"]])
	failures.append_array(_within_the_frame(flocked["budget"]))
	for failure: String in failures:
		print(failure)
	print("rts flock gap: %d failure(s)" % failures.size())
	quit(1 if not failures.is_empty() else 0)


# The budget's scene walked by `crowd`: how many units jammed, how many
# reached their goal, and the frame budget it was timed with.
func _walk(label: String, crowd: GakRtsCrowd) -> Dictionary:
	var world: RtsWorld = RtsTestWorld.armies(SEED, PER_SIDE)
	world.crowd = crowd
	_send_the_armies(world)
	var budget := FrameBudget.new()
	# Id -> the tick it last stepped into a gap, while it stays there.
	var since: Dictionary = {}
	var jammed: Dictionary = {}
	for tick: int in range(TICKS):
		world.step(budget)
		_count_the_stay(_in_the_gap(world), since, jammed, tick)
	var arrived: int = world.units().filter(func(unit: RtsUnit) -> bool:
		return unit.order != RtsCommand.MOVE).size()
	print("  %s: %d jammed in a gap; %d no longer on the move; simulation mean %.3f ms" % [
		label, jammed.size(), arrived, budget.mean_ms(FrameBudget.SIMULATION)])
	return {"jammed": jammed.size(), "arrived": arrived, "budget": budget}


# Forget in `since` whoever has left a gap, start the clock for whoever
# has just come in, and mark in `jammed` whoever has stayed too long.
static func _count_the_stay(now: Dictionary, since: Dictionary, jammed: Dictionary, tick: int) -> void:
	for id: int in since.keys():
		if not now.has(id):
			since.erase(id)
	for id: int in now:
		since[id] = since.get(id, tick)
		if tick - since[id] > JAMMED_AFTER:
			jammed[id] = true


# The ids of the units on a move order standing in a gap now.
func _in_the_gap(world: RtsWorld) -> Dictionary:
	var found: Dictionary = {}
	var wall: float = RtsTestWorld.WALL_COLUMN + 0.5
	for unit: RtsUnit in world.units():
		if unit.order == RtsCommand.MOVE and absf(unit.position.x - wall) <= IN_THE_GAP:
			found[unit.id] = true
	return found


# Each army dealt into four groups and sent, as the budget's are: the left
# to `GOALS`, the right to their mirror images.
func _send_the_armies(world: RtsWorld) -> void:
	for side: int in [RtsTestWorld.LEFT, RtsTestWorld.RIGHT]:
		var groups: Array[Array] = _groups_of(world, side)
		for group: int in range(GOALS.size()):
			var mirrored := Vector2i(RtsTestWorld.SIZE - 1 - GOALS[group].x, GOALS[group].y)
			var goal: Vector2i = mirrored if side == RtsTestWorld.RIGHT else GOALS[group]
			var ids: Array[int] = []
			ids.assign(groups[group])
			world.command(side, RtsCommand.move(ids, goal))


# `side`'s units dealt into one group per goal, by place in its own list.
func _groups_of(world: RtsWorld, side: int) -> Array[Array]:
	var groups: Array[Array] = [[], [], [], []]
	var placed: int = 0
	for unit: RtsUnit in world.units().filter(func(unit: RtsUnit) -> bool: return unit.side == side):
		groups[placed % GOALS.size()].append(unit.id)
		placed += 1
	return groups


func _within_the_frame(budget: FrameBudget) -> Array[String]:
	var over: String = budget.why_over(FrameBudget.SIMULATION)
	if over == "":
		return []
	if OS.get_environment("GITHUB_ACTIONS") == "true":
		print("  note: %s -- not judged on a shared CI runner, judged on a desk" % over)
		return []
	return ["with the flock, " + over]
