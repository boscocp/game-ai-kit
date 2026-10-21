# T54's ladder, measured rather than felt, on two tracks. Every level drives
# LAPS laps alone from a standing start, once for each seed of SEEDS -- the
# seed sets which way its wander drifts -- and on each track three things
# must hold:
#
#   1. every level finishes every lap inside TIME_LIMIT, because a
#      difficulty that cannot complete the track is not a difficulty;
#   2. the levels are in order: each one's mean lap is shorter than the
#      mean lap of the level below it;
#   3. by at least GAP_SECONDS a lap, so that two rungs a person could not
#      tell apart do not count as two.
#
# **The second track is the portability check** (the owner's rule for every
# example, 2026-10-21: the driver perceives the world and decides, and put
# on another track it must cope). The kidney is narrower, runs the other
# way, has a hairpin and a chicane the loop has not, and nothing was tuned
# on it: the knobs, the gains and the line-finding are the loop's.
# This race is the real defence; `racing3d_portable_test.gd` adds what a
# reading can hold -- that the decision's code names only an allow-list of
# classes and no track -- and cannot see a number tuned to one track.
#
# "Alone" is a ghost race: every level and seed is a car in one race, all on
# the same spot of the grid, driving through each other and seeing nobody.
# Jolt replays a run bit for bit on one binary (T50), and a ghost touches
# nothing but the ground: measured (2026-10-21), each level on seed 1 raced
# alone in a race of its own drove the same laps to the frame.
#
# Measured before the gap was set (2026-10-21), the standing start's lap
# included: on the loop easy 50.61 s, normal 48.43 s, hard 47.20 s (2.18
# and 1.23 apart); on the kidney easy 43.90 s, normal 41.86 s, hard 40.41 s
# (2.05 and 1.44). A second leaves the smaller gaps room without letting
# two drivers a person could not tell apart through.
#
# Each rule is first shown a ladder it must refuse, built from made-up lap
# times, so a check that only goes green cannot pass.
#
#     ./scripts/godot --headless --fixed-fps 60 --path godot -s res://test/racing3d/racing3d_ladder.gd
#
# Exit codes: 0 the ladder held on both tracks; 1 it did not.
extends SceneTree

const TRACKS: Array[String] = [
	"res://game3d/racing/tracks/the_loop.json",
	"res://game3d/racing/tracks/the_kidney.json",
]
const SEEDS: Array[int] = [1, 2, 3]
const LAPS: int = 3
## Seconds every car may take for all its laps, after measuring; a lap takes
## under a minute.
const TIME_LIMIT: float = 300.0
const GAP_SECONDS: float = 1.0

var _errors := Racing3DErrors.new()
## The counter's own planted case, run first: "" when it counted it.
var _counter_works: String = ""


func _initialize() -> void:
	OS.add_logger(_errors)
	_counter_works = _errors.self_check()
	_run()


func _run() -> void:
	var failures: Array[String] = _planted()
	for path: String in TRACKS:
		failures.append_array(await _ladder_on(RaceTrack3D.from_file(path)))
	if _counter_works != "":
		failures.append(_counter_works)
	var engine: String = _errors.finding("the races")
	if engine != "":
		failures.append(engine)
	for failure: String in failures:
		print(failure)
	print("racing3d ladder: %d track(s), %d failure(s)" % [TRACKS.size(), failures.size()])
	quit(1 if not failures.is_empty() else 0)


# Every level on every seed round `track`, and what is wrong with the ladder.
func _ladder_on(track: RaceTrack3D) -> Array[String]:
	var levels: Array[RaceLevel3D] = RaceLevel3D.ladder()
	var race: Race3D = await _raced(track, levels)
	var titles: Array[String] = []
	var finished: Array[bool] = []
	var means := PackedFloat64Array()
	for level_index: int in range(levels.size()):
		var laps: PackedFloat64Array = _laps_of(race, level_index)
		titles.append("%s on %s" % [levels[level_index].title, track.title])
		finished.append(laps.size() == SEEDS.size() * LAPS)
		means.append(_mean(laps))
		print("%s: mean lap %.2f s over %d laps" % [titles[-1], _mean(laps), laps.size()])
	race.queue_free()
	await process_frame
	return ladder_findings(titles, finished, means)


# Every lap the cars of level `level_index` drove, one car a seed.
func _laps_of(race: Race3D, level_index: int) -> PackedFloat64Array:
	var laps := PackedFloat64Array()
	for number: int in range(level_index * SEEDS.size(), (level_index + 1) * SEEDS.size()):
		for lap: int in range(race.laps(number)):
			laps.append(race.lap_time(number, lap))
	return laps


# One ghost race of every level and seed, run until each car has its laps.
func _raced(track: RaceTrack3D, levels: Array[RaceLevel3D]) -> Race3D:
	var race := Race3D.new(track, CarPhysics3D.new(), true)
	root.add_child(race)
	for level: RaceLevel3D in levels:
		for seed_value: int in SEEDS:
			var driver := RaceDriver3D.new(level, Race3D.sheet_of(race.physics))
			driver.drift_from(seed_value)
			race.enter(driver)
	while (not race.racing or not _all_done(race)) and race.time < TIME_LIMIT:
		await physics_frame
	return race


func _all_done(race: Race3D) -> bool:
	for number: int in range(race.cars.size()):
		if race.laps(number) < LAPS:
			return false
	return true


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


func _mean(values: PackedFloat64Array) -> float:
	if values.is_empty():
		return INF
	var total: float = 0.0
	for value: float in values:
		total += value
	return total / values.size()


# The three refusals, on made-up ladders, each by its own rule -- an
# out-of-order rung is also "too close", and must still be named for what
# it is; and one ladder that must pass, so a check that refuses everything
# is caught too.
func _planted() -> Array[String]:
	var failures: Array[String] = []
	var titles: Array[String] = ["easy", "normal", "hard"]
	var all_finished: Array[bool] = [true, true, true]
	var cases: Array[Array] = [
		["a level that did not finish", [true, false, true], PackedFloat64Array([52.0, 49.0, 47.0]), "did not finish"],
		["a rung out of order", all_finished, PackedFloat64Array([52.0, 47.0, 49.0]), "is not faster"],
		["two rungs too close", all_finished, PackedFloat64Array([52.0, 49.0, 48.5]), "is only"],
		["a ladder that holds", all_finished, PackedFloat64Array([52.0, 49.0, 47.0]), ""],
	]
	for planted: Array in cases:
		var finished: Array[bool] = []
		finished.assign(planted[1])
		var said: String = "\n".join(ladder_findings(titles, finished, planted[2]))
		var right: bool = said == "" if planted[3] == "" else planted[3] in said
		if not right:
			failures.append("planted, %s: %s" % [planted[0], said if said != "" else "passed"])
	return failures
