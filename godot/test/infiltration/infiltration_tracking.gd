# T91's measurement, `make test-infiltration-tracking`: the grid belief
# against the particles, on the infiltration level's own guards and
# scripted player (`TrackingClaims`, which says what a run is and what is
# held). A measurement, not one of `make check`'s gates: the wiring it
# depends on is held cheaply by `belief_switch_test.gd` (the spot and the
# way out read the belief that is on; a silent guard's "would have heard"),
# and this costs about a minute.
#
# It prints, each written into docs/godot/infiltration.md as measured:
#
#   1. a reported player that creeps off and hides, from lying hidden to
#      found, over the two hand-made levels and twenty generated ones:
#      every run paired, both modes' means and medians, the runs at the cap
#      named, and how many runs ended within one belief step;
#   2. T70's staged search (`HidingStage`, the player never moves), the same
#      way, over `InfiltrationRuns.levels()` and its three seeds;
#   3. what a belief step of the particles costs on the largest level.
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
## Belief steps timed for the cost, and a guard's sight in cells for them.
const TIMED_STEPS: int = 200
const TIMED_SEEN: int = 60

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
	print("1. a reported player that creeps off and hides (s from lying hidden to found; cap %.0f s)" % TrackingClaims.LOST_FOR)
	_print_paired(_labels(levels, TrackingClaims.SEEDS), times["grid"], times["particles"])
	print("2. T70's staged search, the player never moving (s from the report to found; cap %.0f s)" % LevelClaims.SEARCH_FOR)
	_print_staged()
	_print_cost(levels)
	failures.append_array(TrackingClaims.findings(times["grid"], times["particles"], planted))
	if _errors.count > 0:
		failures.append("%d engine error(s) during the measurement" % _errors.count)
	for failure: String in failures:
		print(failure)
	print("infiltration tracking: %d failure(s)" % failures.size())
	quit(1 if not failures.is_empty() else 0)


# One label a run, "level seed", in the order the runs are made.
static func _labels(levels: Array[InfiltrationLevel], seeds: Array[int]) -> PackedStringArray:
	var found := PackedStringArray()
	for level: InfiltrationLevel in levels:
		for seed_value: int in seeds:
			found.append("%s/%d" % [level.name, seed_value])
	return found


# Every run both modes measured, side by side; then means, medians, how
# many ended within one belief step, who was sooner, and the capped runs.
static func _print_paired(labels: PackedStringArray, grid: Array[float], particles: Array[float]) -> void:
	var paired_grid: Array[float] = []
	var paired_particles: Array[float] = []
	var counts: Dictionary = {"particles sooner": 0, "grid sooner": 0, "same": 0, "within a belief step": 0}
	var capped := PackedStringArray()
	for index: int in range(grid.size()):
		if is_nan(grid[index]) or is_nan(particles[index]):
			continue
		paired_grid.append(grid[index])
		paired_particles.append(particles[index])
		print("  %-16s grid %5.1f  particles %5.1f" % [labels[index], grid[index], particles[index]])
		_count_pair(counts, grid[index], particles[index])
		if maxf(grid[index], particles[index]) >= TrackingClaims.LOST_FOR:
			capped.append(labels[index])
	print("  paired runs %d: grid mean %.1f median %.1f; particles mean %.1f median %.1f" % [paired_grid.size(),
		_mean(paired_grid), _median(paired_grid), _mean(paired_particles), _median(paired_particles)])
	print("  %s; at the cap: %s" % [counts, ", ".join(capped) if not capped.is_empty() else "none"])


static func _count_pair(counts: Dictionary, grid: float, particles: float) -> void:
	var key: String = "same"
	if not is_equal_approx(grid, particles):
		key = "particles sooner" if particles < grid else "grid sooner"
	counts[key] += 1
	if maxf(grid, particles) <= 1.0 / InfiltrationRules.read().belief_steps:
		counts["within a belief step"] += 1


static func _mean(values: Array[float]) -> float:
	var total: float = 0.0
	for value: float in values:
		total += value
	return total / maxf(values.size(), 1.0)


static func _median(values: Array[float]) -> float:
	if values.is_empty():
		return NAN
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	return sorted[floori(sorted.size() / 2.0)]


func _print_staged() -> void:
	var levels: Array[InfiltrationLevel] = InfiltrationRuns.levels()
	var modes: Dictionary = TrackingClaims.modes()
	_print_paired(_labels(levels, STAGED_SEEDS), _staged(levels, modes["grid"]), _staged(levels, modes["particles"]))


# `LevelClaims.found_after` for every level and STAGED_SEEDS under `change`.
static func _staged(levels: Array[InfiltrationLevel], change: Callable) -> Array[float]:
	var found: Array[float] = []
	for level: InfiltrationLevel in levels:
		for seed_value: int in STAGED_SEEDS:
			found.append(LevelClaims.found_after(level, seed_value, change))
	return found


# What one guard's particles cost a belief step on the largest level, with
# a sight of TIMED_SEEN cells and a silent creep's ring.
func _print_cost(levels: Array[InfiltrationLevel]) -> void:
	var largest: InfiltrationLevel = levels[0]
	for level: InfiltrationLevel in levels:
		if level.cells.size() > largest.cells.size():
			largest = level
	var rules: InfiltrationRules = InfiltrationRules.read()
	var cloud := ParticleBelief.new(largest.neighbours, rules.particles_per_cell * largest.cells.size(), 1)
	var seen := PackedInt32Array(range(TIMED_SEEN))
	var heard_from := PackedInt32Array(range(TIMED_SEEN, TIMED_SEEN + 13))
	var started: int = Time.get_ticks_usec()
	for step: int in range(TIMED_STEPS):
		cloud.step_unseen(seen, heard_from)
	var each: float = float(Time.get_ticks_usec() - started) / TIMED_STEPS
	print("3. a belief step of one guard's particles on %s (%d cells, %d particles): %.0f us; %.1f steps a second per guard" % [
		largest.name, largest.cells.size(), rules.particles_per_cell * largest.cells.size(), each, rules.belief_steps])
