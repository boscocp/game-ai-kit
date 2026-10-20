# T23's ladder, measured rather than felt. Every level drives `LAPS` laps
# alone, from a standing start, once for each seed of `SEEDS` -- the seed
# sets which way its wander drifts -- and three things must hold:
#
#   1. every level finishes every lap inside `TIME_LIMIT`, because a
#      difficulty that cannot complete the track is not a difficulty;
#   2. the levels are in order: each one's mean lap is shorter than the mean
#      lap of the level below it, since a ladder with a rung out of order is
#      not a ladder;
#   3. by at least `GAP_SECONDS` a lap, so that two rungs a person could not
#      tell apart do not count as two.
#
# Measured before the gap was set (2026-10-20): easy 39.6 s, normal 36.6 s,
# hard 35.1 s a lap over these seeds, the standing start's lap included --
# 3.0 and 1.5 seconds apart. One second leaves the smaller gap room without
# letting two drivers a person could not tell apart through. T59 widened the
# track to 24 metres and gave every car more grip and brakes, and moved
# normal's margin to 0.84: 33.0, 31.7 and 30.2 s, 1.3 and 1.5 apart.
#
# Each rule is first shown a ladder it must refuse, built from made-up lap
# times, so a check that only goes green cannot pass.
#
#     ./scripts/godot --headless --path godot -s res://test/demo_racing/racing_ladder.gd
#
# Exit codes: 0 the ladder held; 1 it did not.
extends SceneTree

const SEEDS: Array[int] = [1, 2, 3, 4, 5]
const LAPS: int = 2
## Seconds a car may take for all its laps; a lap takes under forty.
const TIME_LIMIT: float = 240.0
const GAP_SECONDS: float = 1.0


func _init() -> void:
	var failures: Array[String] = _planted()
	var titles: Array[String] = []
	var finished: Array[bool] = []
	var means := PackedFloat64Array()
	for level: RacingLevel in RacingLevel.ladder():
		var laps: PackedFloat64Array = _drive(level)
		titles.append(level.title)
		finished.append(laps.size() == SEEDS.size() * LAPS)
		means.append(_mean(laps))
		print("%s: mean lap %.2f s over %d laps" % [level.title, _mean(laps), laps.size()])
	failures.append_array(ladder_findings(titles, finished, means))
	for failure: String in failures:
		print(failure)
	print("racing ladder: %d levels, %d failure(s)" % [titles.size(), failures.size()])
	quit(1 if not failures.is_empty() else 0)


## What is wrong with a ladder of levels, easiest first: one that did not
## finish, one out of order, one too close to the one below it. Empty when
## the ladder holds.
func ladder_findings(titles: Array[String], finished: Array[bool], means: PackedFloat64Array) -> Array[String]:
	var findings: Array[String] = []
	for index: int in range(titles.size()):
		if not finished[index]:
			findings.append("%s did not finish its laps inside %.0f s" % [titles[index], TIME_LIMIT])
	for index: int in range(1, titles.size()):
		findings.append_array(_rung_findings(titles[index - 1], means[index - 1], titles[index], means[index]))
	return findings


# One rung against the one below it: faster, and by at least the gap.
func _rung_findings(easier: String, easier_mean: float, harder: String, harder_mean: float) -> Array[String]:
	var gap: float = easier_mean - harder_mean
	if gap <= 0.0:
		return ["%s is not faster than %s: %.2f s against %.2f s" % [harder, easier, harder_mean, easier_mean]]
	if gap < GAP_SECONDS:
		return ["%s is only %.2f s a lap faster than %s, under %.1f s" % [harder, gap, easier, GAP_SECONDS]]
	return []


# Every lap time `level` drove, alone, once for each seed.
func _drive(level: RacingLevel) -> PackedFloat64Array:
	var laps := PackedFloat64Array()
	for seed_value: int in SEEDS:
		var race := RacingRace.new(RacingPhysics.new())
		race.enter(RacingDriver.new(level, seed_value))
		while race.laps(0) < LAPS and race.time < TIME_LIMIT:
			race.step()
		for lap: int in range(race.laps(0)):
			laps.append(race.lap_time(0, lap))
	return laps


func _mean(values: PackedFloat64Array) -> float:
	if values.is_empty():
		return INF
	var total: float = 0.0
	for value: float in values:
		total += value
	return total / values.size()


# The three refusals, on made-up ladders, each by its own rule -- an
# out-of-order rung is also "too close", and must still be named for what it
# is; and one ladder that must pass, so a check that refuses everything is
# caught too.
func _planted() -> Array[String]:
	var failures: Array[String] = []
	var titles: Array[String] = ["easy", "normal", "hard"]
	var all_finished: Array[bool] = [true, true, true]
	var cases: Array[Array] = [
		["a level that did not finish", [true, false, true], PackedFloat64Array([40.0, 36.0, 33.0]), "did not finish"],
		["a rung out of order", all_finished, PackedFloat64Array([40.0, 33.0, 36.0]), "is not faster"],
		["two rungs too close", all_finished, PackedFloat64Array([40.0, 36.0, 35.5]), "is only"],
		["a ladder that holds", all_finished, PackedFloat64Array([40.0, 36.0, 33.0]), ""],
	]
	for planted: Array in cases:
		var finished: Array[bool] = []
		finished.assign(planted[1])
		var said: String = "\n".join(ladder_findings(titles, finished, planted[2]))
		var right: bool = said == "" if planted[3] == "" else planted[3] in said
		if not right:
			failures.append("planted, %s: %s" % [planted[0], said if said != "" else "passed"])
	return failures
