# T91's measurement, `make test-infiltration-tracking`: the grid belief
# against the particles, on the infiltration level's own guards and
# scripted player, over the two hand-made levels and twenty generated ones
# (`TrackingClaims`, which says what a run is and what is held).
#
# It prints two tables, written into docs/godot/infiltration.md as measured:
#
#   1. a lost player found again -- a reported player that creeps off and
#      hides, from lying hidden to found, per mode, the hand-made levels and the
#      generated ones apart;
#   2. T70's staged search (`HidingStage`) with the particles on, beside the
#      grid's, over `InfiltrationRuns.levels()` and its three seeds.
#
# Held, with a planted case (invariant 4): enough runs measured in each
# mode, and the particles change what the guards do -- planted, the search
# wired to the grid while the particles run.
#
# Engine errors are counted (`PerceptionErrors`); read the output for
# SCRIPT ERROR too (CLAUDE.md's trap).
#
#     ./scripts/godot --headless --path godot -s res://test/infiltration/infiltration_tracking.gd
#
# Exit codes: 0 the claims held and the planted case was caught; 1 not.
extends SceneTree

## Levels the planted case is run on: the hand-made ones and two generated.
const PLANTED_ON: int = 4
const STAGED_SEEDS: Array[int] = [1, 2, 3]

var _errors := PerceptionErrors.new()


func _initialize() -> void:
	OS.add_logger(_errors)
	var failures: Array[String] = []
	var counter: String = _errors.self_check()
	if counter != "":
		failures.append(counter)
	var levels: Array[InfiltrationLevel] = TrackingClaims.levels()
	var times: Dictionary = {}
	var modes: Dictionary = TrackingClaims.modes()
	for mode: String in modes:
		times[mode] = TrackingClaims.runs(levels, modes[mode])
	var planted: Array[float] = TrackingClaims.runs(levels.slice(0, PLANTED_ON), modes["particles"], TrackingClaims.wired_to_nothing)
	_print_lost(times, levels.size())
	_print_staged()
	failures.append_array(TrackingClaims.findings(times["grid"], times["particles"], planted))
	if _errors.count > 0:
		failures.append("%d engine error(s) during the measurement" % _errors.count)
	for failure: String in failures:
		print(failure)
	print("infiltration tracking: %d failure(s)" % failures.size())
	quit(1 if not failures.is_empty() else 0)


func _print_lost(times: Dictionary, level_count: int) -> void:
	var hand_made: int = InfiltrationLevel.HAND_MADE.size()
	print("a lost player found again (s from lying hidden, unfound; never = %.0f s):" % TrackingClaims.LOST_FOR)
	print("| levels | belief | runs | mean | median | found within %.0f s |" % TrackingClaims.LOST_FOR)
	print("|---|---|---|---|---|---|")
	for group: Array in [["hand-made", 0, hand_made], ["generated", hand_made, level_count], ["all", 0, level_count]]:
		for mode: String in times:
			var row: Array = TrackingClaims.summary(times[mode], group[1], group[2])
			print("| %s | %s | %d | %.1f | %.1f | %d |" % [group[0], mode, row[0], row[1], row[2], row[3]])
	var pairs: Array = _paired(times["grid"], times["particles"])
	print("runs measured in both: %d; particles sooner in %d, the grid sooner in %d, the same in %d" % pairs)


# Over the runs both modes measured: how many, and which found the player sooner.
static func _paired(grid: Array[float], particles: Array[float]) -> Array:
	var counts: Array = [0, 0, 0, 0]
	for index: int in range(grid.size()):
		if is_nan(grid[index]) or is_nan(particles[index]):
			continue
		counts[0] += 1
		if is_equal_approx(grid[index], particles[index]):
			counts[3] += 1
		elif particles[index] < grid[index]:
			counts[1] += 1
		else:
			counts[2] += 1
	return counts


# The mean of `LevelClaims.found_after` over `levels` and STAGED_SEEDS
# under `change`, the runs that could not be staged left out.
static func _mean_staged(levels: Array[InfiltrationLevel], change: Callable) -> float:
	var found: Array[float] = []
	for level: InfiltrationLevel in levels:
		for seed_value: int in STAGED_SEEDS:
			found.append(LevelClaims.found_after(level, seed_value, change))
	var staged: Array = found.filter(func(seconds: float) -> bool: return not is_nan(seconds))
	var total: float = staged.reduce(func(sum: float, seconds: float) -> float: return sum + seconds, 0.0)
	return total / maxf(staged.size(), 1.0)


func _print_staged() -> void:
	var levels: Array[InfiltrationLevel] = InfiltrationRuns.levels()
	var line: PackedStringArray = []
	var modes: Dictionary = TrackingClaims.modes()
	for mode: String in modes:
		line.append("%s %.1f s" % [mode, _mean_staged(levels, modes[mode])])
	print("T70's staged search, found after on average: %s (%d levels x %d seeds)" % [", ".join(line), levels.size(), STAGED_SEEDS.size()])
