# T20's acceptance: a whole AI-against-AI match of the RTS, headless, from
# a fixed seed, and the claims the task makes about it.
#
#   1. the map is the same turned half round, so neither seat starts nearer
#      anything -- a map nudged off its mirror is refused;
#   2. the match ends, and ends the same way twice: one winner, one digest,
#      and the recording replays to that digest with no controller;
#   3. T19's frame budget held for the simulation and the flow fields, and
#      each layer of the computer's thinking held its share per decision;
#   4. no single planning call exceeded the strategy share -- and a planted
#      call that does is caught by the same check;
#   5. the commander against the priority queues alone, over seeds and both
#      seats: the win rate printed, and the commander ahead, since ADR 0010
#      says a commander that does not beat the queues has not earned its cost.
#
#     ./scripts/godot --headless --path godot -s res://test/rts_match.gd
#
# Exit codes: 0 every claim held; 1 one did not. The slower measurements --
# STRIPS against the HTN, each level against the next, the seat's bias --
# are `make rts-measure`.
extends SceneTree

const SEED: int = 20
## Seeds of claim 5, each played from both seats.
const SWEEP_SEEDS: int = 4


func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(_symmetric())
	var played: RtsMatch = _play(SEED)
	failures.append_array(_ends_the_same_way(played))
	failures.append_array(_within_the_frame(played))
	failures.append_array(_plans_within_their_share(played))
	failures.append_array(_commander_beats_the_queues())
	for failure: String in failures:
		print(failure)
	print("rts match: %d failure(s)" % failures.size())
	quit(1 if not failures.is_empty() else 0)


# The demo's own match: the commander at normal as east, the queues as west.
func _play(seed_value: int) -> RtsMatch:
	var world: RtsWorld = RtsScenario.start(seed_value)
	var level: Difficulty = RtsLevels.named("normal")
	var sides: Dictionary = {RtsScenario.EAST: RtsCommander.new(RtsScenario.EAST, level, seed_value * 7),
		RtsScenario.WEST: QueueSide.new(RtsScenario.WEST, level, seed_value * 11)}
	var played := RtsMatch.new(world, seed_value, sides)
	while RtsVictory.winner(world) == RtsVictory.UNDECIDED:
		played.play(RtsWorld.TICKS_PER_SECOND * 10)
	return played


# Claim 1, with a planted map one cell off its mirror.
func _symmetric() -> Array[String]:
	var nudged: Array[String] = RtsScenario.MAP.duplicate()
	nudged[0] = "#" + nudged[0].substr(1)
	if _mirror_breaks(nudged).is_empty():
		return ["claim 1: a map one cell off its mirror passed the symmetry check"]
	var broken: Array[String] = _mirror_breaks(RtsScenario.MAP)
	print("symmetry: the map is its own half-turn%s" % ("" if broken.is_empty() else " except " + ", ".join(broken)))
	return [] if broken.is_empty() else ["claim 1: the map is not its own half-turn at " + ", ".join(broken)]


# The cells whose half-turn partner differs; the two bases swap letters.
static func _mirror_breaks(rows: Array[String]) -> Array[String]:
	var swapped: Dictionary = {"A": "B", "B": "A"}
	var broken: Array[String] = []
	var width: int = rows[0].length()
	for index: int in range(rows.size() * width):
		var column: int = index % width
		var row: int = index / width
		var here: String = rows[row][column]
		if swapped.get(here, here) != rows[rows.size() - 1 - row][width - 1 - column]:
			broken.append("(%d, %d)" % [column, row])
	return broken


# Claim 2: a second run agrees, and the recording replays to the digest.
func _ends_the_same_way(played: RtsMatch) -> Array[String]:
	var failures: Array[String] = []
	var again: RtsMatch = _play(SEED)
	var won: int = RtsVictory.winner(played.world)
	print("match: %s after %d s, %d commands, digest %s" % [RtsVictory.why(played.world),
		played.world.tick / RtsWorld.TICKS_PER_SECOND, played.accepted.size(), played.world.digest().left(16)])
	if RtsVictory.winner(again.world) != won or again.world.digest() != played.world.digest():
		failures.append("claim 2: the same seed ended differently the second time")
	var replayed: String = RtsMatch.replay(RtsScenario.start(SEED), played.recording())
	if replayed != "":
		failures.append("claim 2: the recording did not replay: " + replayed)
	if played.accepted.size() < 100:
		failures.append("claim 2: only %d commands were given; the match barely happened" % played.accepted.size())
	return failures


# Claim 3: the world's two layers by T19's budget, and the computer's two
# by their shares, mean and 95th percentile per decision.
func _within_the_frame(played: RtsMatch) -> Array[String]:
	var failures: Array[String] = []
	for layer: String in [FrameBudget.SIMULATION, FrameBudget.FLOW_FIELDS]:
		var over: String = played.budget.why_over(layer)
		print("budget: %s mean %.3f ms, 95th %.3f ms" % [layer, played.budget.mean_ms(layer), played.budget.percentile_ms(layer, 0.95)])
		if over != "":
			failures.append("claim 3: " + over)
	for side: int in played.controllers:
		failures.append_array(_thinking_within_its_shares(side, played.controllers[side]))
	return failures


# One side's strategy and tactics, every decision, against their shares.
func _thinking_within_its_shares(side: int, thinking: RtsSide) -> Array[String]:
	var failures: Array[String] = []
	var measured := FrameBudget.new()
	for layer: String in [FrameBudget.STRATEGY, FrameBudget.TACTICS]:
		for microseconds: int in thinking.timings[layer]:
			measured.record(layer, microseconds)
		print("budget: side %d %s per decision, mean %.3f ms, 95th %.3f ms" % [side, layer,
			measured.mean_ms(layer), measured.percentile_ms(layer, 0.95)])
		if measured.why_over(layer) != "":
			failures.append("claim 3: side %d's %s" % [side, measured.why_over(layer)])
	return failures


# Claim 4, the planted call first: a list with one call over the share
# must be caught by the check that then reads the real ones.
func _plans_within_their_share(played: RtsMatch) -> Array[String]:
	var share_us: int = int(FrameBudget.SHARES[FrameBudget.STRATEGY] * 1000.0)
	if _slowest_over([{"microseconds": 10}, {"microseconds": share_us + 1}], share_us).is_empty():
		return ["claim 4: a planted plan over the strategy share was not caught"]
	var commander: RtsCommander = played.controllers[RtsScenario.EAST]
	if commander.plans.is_empty():
		return ["claim 4: the commander never planned"]
	var slowest: int = 0
	for plan: Dictionary in commander.plans:
		slowest = maxi(slowest, plan["microseconds"])
	print("plans: %d calls, the slowest %d us against a share of %d us" % [commander.plans.size(), slowest, share_us])
	return _slowest_over(commander.plans, share_us)


static func _slowest_over(plans: Array, share_us: int) -> Array[String]:
	for plan: Dictionary in plans:
		if plan["microseconds"] > share_us:
			return ["claim 4: a plan took %d us, over the strategy share of %d us" % [plan["microseconds"], share_us]]
	return []


# Claim 5: SWEEP_SEEDS seeds from each seat, the commander and the queues
# at the same level, so the top layer is the only difference.
func _commander_beats_the_queues() -> Array[String]:
	var level: Difficulty = RtsLevels.named("normal")
	var record: Dictionary = {"commander": 0, "queues": 0, "draw": 0}
	for game: int in range(SWEEP_SEEDS * 2):
		var seed_value: int = game / 2 + 1
		var seat: int = RtsScenario.WEST if game % 2 == 0 else RtsScenario.EAST
		var world: RtsWorld = RtsScenario.start(seed_value)
		var sides: Dictionary = {seat: RtsCommander.new(seat, level, seed_value * 7),
			RtsScenario.enemy_of(seat): QueueSide.new(RtsScenario.enemy_of(seat), level, seed_value * 11)}
		var played := RtsMatch.new(world, seed_value, sides)
		while RtsVictory.winner(world) == RtsVictory.UNDECIDED:
			played.play(RtsWorld.TICKS_PER_SECOND * 10)
		var won: int = RtsVictory.winner(world)
		record["draw" if won == RtsVictory.DRAW else ("commander" if won == seat else "queues")] += 1
	print("commander against the queues alone: %d - %d, %d drawn, over %d seeds from both seats" % [
		record["commander"], record["queues"], record["draw"], SWEEP_SEEDS])
	if record["commander"] <= record["queues"]:
		return ["claim 5: the commander did not beat the queues alone (%d - %d)" % [record["commander"], record["queues"]]]
	return []
