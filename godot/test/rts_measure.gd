# T20's measurements, the ones the ADRs quote: the commander against the
# priority queues alone, STRIPS against the HTN as the commander's planner,
# each difficulty level against the one below it, and the queues against
# themselves for the seat's own bias. Every pairing is played over
# `SEEDS` with sides swapped, so neither seat decides it.
#
#     ./scripts/godot --headless --path godot -s res://test/rts_measure.gd
#
# Slow -- a few minutes -- so it is `make rts-measure`, not part of `check`;
# `test/rts_match.gd` holds the claims a check needs.
extends SceneTree

const SEEDS: int = 10


func _init() -> void:
	var normal: Difficulty = RtsLevels.named("normal")
	_pairing("commander (normal, STRIPS) vs the queues alone",
		func(side: int, seed_value: int) -> RtsSide: return RtsCommander.new(side, normal, seed_value),
		func(side: int, seed_value: int) -> RtsSide: return QueueSide.new(side, normal, seed_value))
	_pairing("commander STRIPS vs commander HTN (normal)",
		func(side: int, seed_value: int) -> RtsSide: return RtsCommander.new(side, normal, seed_value),
		func(side: int, seed_value: int) -> RtsSide: return RtsCommander.new(side, normal, seed_value, BuildOrder.Planner.HTN))
	var levels: Array[Difficulty] = RtsLevels.presets()
	for index: int in range(1, levels.size()):
		var upper: Difficulty = levels[index]
		var lower: Difficulty = levels[index - 1]
		_pairing("%s vs %s" % [upper.name, lower.name],
			func(side: int, seed_value: int) -> RtsSide: return RtsCommander.new(side, upper, seed_value),
			func(side: int, seed_value: int) -> RtsSide: return RtsCommander.new(side, lower, seed_value))
	_pairing("the queues vs the queues: the seat's bias, west first",
		func(side: int, seed_value: int) -> RtsSide: return QueueSide.new(side, normal, seed_value),
		func(side: int, seed_value: int) -> RtsSide: return QueueSide.new(side, normal, seed_value), true)
	_planners_on_the_same_questions()
	quit(0)


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
	for game: int in range(SEEDS * 2):
		var first_side: int = RtsScenario.WEST if game % 2 == 0 else RtsScenario.EAST
		var ended: Dictionary = _play_one(first, second, game / 2 + 1, first_side)
		lengths.append(ended["seconds"])
		plan_micros.append_array(ended["plans"])
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
	print("%s: %d - %d, %d drawn; match length median %d s (%d to %d)%s" % [label, record["first"],
		record["second"], record["draw"], lengths[lengths.size() / 2], lengths[0], lengths[-1], plans])


# One match to its end: {winner, seconds, plans (every planning call's us)}.
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
	return {"winner": RtsVictory.winner(world), "seconds": world.tick / RtsWorld.TICKS_PER_SECOND, "plans": plans}
