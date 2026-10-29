# T86's frame claim: a step of MCTS that a game would call once a frame fits
# in its share of that frame. Measured here, not in a gdUnit suite, because
# a clock is shared with whatever else the machine is doing -- like
# `test-rts-budget`, this is a measurement with a pass mark, run on its own.
#
# The search is the dice race from the start, ITERATIONS_PER_FRAME
# iterations a frame for FRAMES frames, one tree growing throughout. Its
# mean step and its 95th-percentile step must each stay under SHARE_USEC:
# half a frame at 60 frames a second, about the 8 ms `FrameBudget` gives all
# of an RTS's AI together. An idle search would fit any budget, so the run
# must also show its work -- every iteration counted -- and the check is
# first shown a time it must refuse.
#
#     ./scripts/godot --headless --path godot -s res://test/ai_adversarial/mcts_budget.gd
#
# Exit codes: 0 the share is held; 1 it is not, or the check failed its
# planted case.
extends SceneTree

const DICE_RACE: Script = preload("res://test/ai_adversarial/dice_race.gd")
const ITERATIONS_PER_FRAME: int = 100
const FRAMES: int = 20
## Half of a 60-frames-a-second frame, in microseconds.
const SHARE_USEC: int = 8333


func _init() -> void:
	var failures: Array[String] = _planted()
	var squares: Array[int] = [0, 0]
	var search := MonteCarloSearch.new(DICE_RACE.new(), DICE_RACE.Race.new(squares, 0), 1)
	var times: Array[int] = []
	for _frame: int in range(FRAMES):
		var started: int = Time.get_ticks_usec()
		search.step(ITERATIONS_PER_FRAME)
		times.append(Time.get_ticks_usec() - started)
	var done: int = search.result().iterations
	if done != ITERATIONS_PER_FRAME * FRAMES:
		failures.append("the search ran %d iterations, not %d" % [done, ITERATIONS_PER_FRAME * FRAMES])
	var why: String = why_over(times)
	if why != "":
		failures.append(why)
	for failure: String in failures:
		print(failure)
	print("mcts budget: %d iterations a frame, mean %d us, 95th percentile %d us, share %d us; %d failure(s)" % [
			ITERATIONS_PER_FRAME, _mean(times), _percentile_95(times), SHARE_USEC, failures.size()])
	quit(1 if not failures.is_empty() else 0)


## Why these step times break the share, or "" when the mean and the 95th
## percentile both fit.
static func why_over(times: Array[int]) -> String:
	if times.is_empty():
		return "nothing was measured"
	var mean: int = _mean(times)
	var slow: int = _percentile_95(times)
	if mean <= SHARE_USEC and slow <= SHARE_USEC:
		return ""
	return "a step of %d iterations: mean %d us, 95th percentile %d us, share %d us" % [
			ITERATIONS_PER_FRAME, mean, slow, SHARE_USEC]


# The check must refuse a run over the share, and nothing measured, and pass
# one under it -- or a green below means nothing.
static func _planted() -> Array[String]:
	var failures: Array[String] = []
	var over: Array[int] = [SHARE_USEC + 1, SHARE_USEC + 1]
	var under: Array[int] = [SHARE_USEC - 1, SHARE_USEC - 1]
	if why_over(over) == "":
		failures.append("planted: a step over the share was accepted")
	if why_over([] as Array[int]) == "":
		failures.append("planted: nothing measured was accepted")
	if why_over(under) != "":
		failures.append("planted: a step under the share was refused")
	return failures


static func _mean(times: Array[int]) -> int:
	var total: int = 0
	for time: int in times:
		total += time
	return total / maxi(times.size(), 1)


static func _percentile_95(times: Array[int]) -> int:
	var sorted: Array[int] = times.duplicate()
	sorted.sort()
	return sorted[mini(int(sorted.size() * 0.95), sorted.size() - 1)] if not sorted.is_empty() else 0
