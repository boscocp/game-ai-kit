# T20's measurements, the ones the ADRs quote: the commander against the
# priority queues alone, STRIPS against the HTN as the commander's planner,
# each difficulty level against the one below it, and the queues against
# themselves for the seat's own bias; and in every pairing, how often each
# side armed a tower (T56), and the arm's ablation: a commander that may
# arm against one that never does. Every pairing is played over
# `SEEDS` with sides swapped, so neither seat decides it.
#
#     ./scripts/godot --headless --path godot -s res://test/rts/rts_measure.gd
#
# Slow -- a few minutes -- so it is `make rts-measure`, not part of `check`;
# `test/rts/rts_match.gd` holds the claims a check needs.
extends SceneTree

const SEEDS: int = 10


func _init() -> void:
	if "levels" in OS.get_cmdline_user_args():
		_levels()
		quit(0)
		return
	if "arm" in OS.get_cmdline_user_args():
		_arming_ablated()
		quit(0)
		return
	var normal: Difficulty = RtsLevels.named("normal")
	_pairing("commander (normal, STRIPS) vs the queues alone",
		func(side: int, seed_value: int) -> RtsSide: return RtsCommander.new(side, normal, seed_value),
		func(side: int, seed_value: int) -> RtsSide: return QueueSide.new(side, normal, seed_value))
	_pairing("commander STRIPS vs commander HTN (normal)",
		func(side: int, seed_value: int) -> RtsSide: return RtsCommander.new(side, normal, seed_value),
		func(side: int, seed_value: int) -> RtsSide: return RtsCommander.new(side, normal, seed_value, BuildOrder.Planner.HTN))
	_levels()
	_arming_ablated()
	_pairing("the queues vs the queues: the seat's bias, west first",
		func(side: int, seed_value: int) -> RtsSide: return QueueSide.new(side, normal, seed_value),
		func(side: int, seed_value: int) -> RtsSide: return QueueSide.new(side, normal, seed_value), true)
	_planners_on_the_same_questions()
	quit(0)


# The arm's ablation (T56): a normal commander that may arm against the same
# commander told never to. Both raid -- each goes for the other's home --
# so the record is what arming is worth against a side that raids.
# `-- arm` runs only this.
func _arming_ablated() -> void:
	var normal: Difficulty = RtsLevels.named("normal")
	_pairing("commander that may arm vs one that never does (normal)",
		func(side: int, seed_value: int) -> RtsSide: return RtsCommander.new(side, normal, seed_value),
		func(side: int, seed_value: int) -> RtsSide:
			var unarmed := RtsCommander.new(side, normal, seed_value)
			unarmed.may_arm = false
			return unarmed)
	for may_arm: bool in [true, false]:
		_raided_with_the_army_away(may_arm)


# The situation the arm is for, played on purpose, since whole matches seldom
# reach it: west mid-match with a tower up and funds to spare, its four
# shields in the far east corner, and four east runners held at its home for
# 90 s. Over SEEDS, how many arms west bought, and the worth west kept less
# the worth east kept (`RtsVictory.worth`, which prices an arm as it does a
# unit, so buying one moves nothing by itself).
func _raided_with_the_army_away(may_arm: bool) -> void:
	var margin: int = 0
	var arms: int = 0
	var raiders_left: int = 0
	for seed_value: int in range(1, SEEDS + 1):
		var world: RtsWorld = _a_raided_home(seed_value)
		var commander := RtsCommander.new(RtsScenario.WEST, RtsLevels.named("normal"), seed_value)
		commander.may_arm = may_arm
		var played := RtsMatch.new(world, seed_value, {RtsScenario.WEST: commander})
		var before: int = RtsVictory.worth(world, RtsScenario.WEST) - RtsVictory.worth(world, RtsScenario.EAST)
		for _second: int in range(90):
			played.play(RtsWorld.TICKS_PER_SECOND)
			_hold_the_raid(world)
		margin += RtsVictory.worth(world, RtsScenario.WEST) - RtsVictory.worth(world, RtsScenario.EAST) - before
		arms += _arms_bought(played, RtsScenario.WEST)
		raiders_left += world.units().filter(func(unit: RtsUnit) -> bool: return unit.side == RtsScenario.EAST \
			and RtsKinds.fights(unit.kind)).size()
	print("raided with the army away, %s: %d arms over %d seeds; worth margin moved %+.0f a match; raiders left %d" % [
		"may arm" if may_arm else "never arms", arms, SEEDS, float(margin) / SEEDS, raiders_left])


# West's home as `_raided_with_the_army_away` describes it.
static func _a_raided_home(seed_value: int) -> RtsWorld:
	var world: RtsWorld = RtsScenario.start(seed_value)
	var home: Vector2i = RtsScenario.home(RtsScenario.WEST)
	world.add_unit(RtsKinds.BARRACKS, RtsScenario.WEST, home + Vector2i(0, -3))
	world.add_unit(RtsKinds.TOWER, RtsScenario.WEST, home + Vector2i(3, -3))
	world.set_funds(RtsScenario.WEST, 2000, 2000)
	var vent: RtsUnit = world.nearest(Vector2(home), RtsWorld.NEUTRAL, RtsKinds.VENT)
	var workers: Array[int] = []
	for unit: RtsUnit in world.units():
		if unit.side == RtsScenario.WEST and unit.kind == RtsKinds.WORKER:
			workers.append(unit.id)
	world.command(RtsScenario.WEST, RtsCommand.gather(workers, vent.id))
	for index: int in range(4):
		world.add_unit(RtsKinds.SHIELD, RtsScenario.WEST, world.free_cell_near(Vector2i(44, 3)))
		world.add_unit(RtsKinds.RUNNER, RtsScenario.EAST, world.free_cell_near(home + Vector2i(4, 0)))
	return world


# Every east fighter still standing that wandered off is put back by west's home.
static func _hold_the_raid(world: RtsWorld) -> void:
	var home := Vector2(RtsScenario.home(RtsScenario.WEST))
	var wandered: Array = world.units().filter(func(unit: RtsUnit) -> bool:
		return unit.side == RtsScenario.EAST and RtsKinds.fights(unit.kind) \
			and unit.position.distance_to(home) > TowerWorth.RAID_REACH - 2.0)
	for unit: RtsUnit in wandered:
		world.place(unit, home + Vector2(3.5, 0.5))


# Each level against the one below it. `-- levels` runs only this.
func _levels() -> void:
	var levels: Array[Difficulty] = RtsLevels.presets()
	for index: int in range(1, levels.size()):
		var upper: Difficulty = levels[index]
		var lower: Difficulty = levels[index - 1]
		_pairing("%s vs %s" % [upper.name, lower.name],
			func(side: int, seed_value: int) -> RtsSide: return RtsCommander.new(side, upper, seed_value),
			func(side: int, seed_value: int) -> RtsSide: return RtsCommander.new(side, lower, seed_value))


# Every (facts, goal) the commander asked in one match, planned again by
# both planners: worlds or tasks visited, microseconds, steps. The same
# questions, so the two are compared on the work and not on the games.
func _planners_on_the_same_questions() -> void:
	var questions: Array[Array] = _questions_asked(1)
	for planner: BuildOrder.Planner in [BuildOrder.Planner.STRIPS, BuildOrder.Planner.HTN]:
		var visited: int = 0
		var micros: int = 0
		var steps: int = 0
		for question: Array in questions:
			var started: int = Time.get_ticks_usec()
			var found: Dictionary = BuildOrder.plan(question[0], question[1], planner)
			micros += Time.get_ticks_usec() - started
			visited += found["visited"]
			steps += (found["steps"] as PackedStringArray).size()
		print("%s over %d questions: %.1f visited, %.0f us, %.2f steps a plan" % [
			"STRIPS" if planner == BuildOrder.Planner.STRIPS else "HTN", questions.size(),
			float(visited) / questions.size(), float(micros) / questions.size(), float(steps) / questions.size()])


# The distinct (facts, goal) pairs a normal commander planned for in one
# match against the queues.
func _questions_asked(seed_value: int) -> Array[Array]:
	var world: RtsWorld = RtsScenario.start(seed_value)
	var commander := RtsCommander.new(RtsScenario.WEST, RtsLevels.named("normal"), seed_value)
	var played := RtsMatch.new(world, seed_value, {RtsScenario.WEST: commander,
		RtsScenario.EAST: QueueSide.new(RtsScenario.EAST, RtsLevels.named("normal"), seed_value + 1)})
	var asked: Dictionary = {}
	while RtsVictory.winner(world) == RtsVictory.UNDECIDED:
		played.play(played.decide_every)
		var view: RtsSnapshot = RtsSnapshot.of(world, RtsScenario.WEST)
		asked[[BuildOrder.facts(view), commander.goal(view)]] = true
	var questions: Array[Array] = []
	questions.assign(asked.keys())
	return questions


# `first` against `second`, both seats each, over SEEDS; prints the record
# and how the matches ended. With `by_seat`, counts wins by seat instead.
func _pairing(label: String, first: Callable, second: Callable, by_seat: bool = false) -> void:
	var record: Dictionary = {"first": 0, "second": 0, "draw": 0}
	var lengths: Array[int] = []
	var plan_micros: Array[int] = []
	var armed: Array[int] = [0, 0]
	for game: int in range(SEEDS * 2):
		var first_side: int = RtsScenario.WEST if game % 2 == 0 else RtsScenario.EAST
		var ended: Dictionary = _play_one(first, second, game / 2 + 1, first_side)
		lengths.append(ended["seconds"])
		plan_micros.append_array(ended["plans"])
		armed[0] += ended["armed"][0]
		armed[1] += ended["armed"][1]
		var won: int = ended["winner"]
		if won == RtsVictory.DRAW:
			record["draw"] += 1
		elif by_seat:
			record["first" if won == RtsScenario.WEST else "second"] += 1
		else:
			record["first" if won == first_side else "second"] += 1
	lengths.sort()
	plan_micros.sort()
	var plans: String = "" if plan_micros.is_empty() else "; plans %d, median %d us, worst %d us" % [
		plan_micros.size(), plan_micros[plan_micros.size() / 2], plan_micros[-1]]
	print("%s: %d - %d, %d drawn; match length median %d s (%d to %d)%s; towers armed %d - %d" % [label,
		record["first"], record["second"], record["draw"], lengths[lengths.size() / 2], lengths[0], lengths[-1],
		plans, armed[0], armed[1]])


# One match to its end: {winner, seconds, plans (every planning call's us),
# armed: [towers the first side armed, towers the second did]}.
func _play_one(first: Callable, second: Callable, seed_value: int, first_side: int) -> Dictionary:
	var world: RtsWorld = RtsScenario.start(seed_value)
	var one: RtsSide = first.call(first_side, seed_value * 7 + 1)
	var other: RtsSide = second.call(RtsScenario.enemy_of(first_side), seed_value * 7 + 2)
	var played := RtsMatch.new(world, seed_value, {first_side: one, RtsScenario.enemy_of(first_side): other})
	while RtsVictory.winner(world) == RtsVictory.UNDECIDED:
		played.play(RtsWorld.TICKS_PER_SECOND * 10)
	var plans: Array[int] = []
	for side: RtsSide in [one, other]:
		var commander := side as RtsCommander
		for plan: Dictionary in (commander.plans if commander != null else []):
			plans.append(plan["microseconds"])
	return {"winner": RtsVictory.winner(world), "seconds": world.tick / RtsWorld.TICKS_PER_SECOND, "plans": plans,
		"armed": [_arms_bought(played, first_side), _arms_bought(played, RtsScenario.enemy_of(first_side))]}


# How many times `side` bought a tower's arm in `played`: accepted orders
# only, so one the rules refused is not counted.
static func _arms_bought(played: RtsMatch, side: int) -> int:
	var bought: int = 0
	for entry: Dictionary in played.accepted:
		if entry["side"] == side and entry["command"]["what"] == RtsKinds.ARM:
			bought += 1
	return bought
