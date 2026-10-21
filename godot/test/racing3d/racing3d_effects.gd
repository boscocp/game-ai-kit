# What each of T54's three switches does to the race, measured.
#
# Each is switched off alone, against the same race with it on, and the
# numbers are printed whatever they are. Two claims are held:
#
#   1. **PID**: the hard driver, alone for LAPS laps, keeps closer to where
#      it wants to be with the full PID than with the proportional term
#      only -- its mean distance off is lower. Melder & Tomlinson's chapter
#      says a proportional term alone leaves an offset (a small gain) or
#      swings (a large one); which one this car shows is printed;
#   2. **the measured grip**: the hard driver racing on its car's sheet --
#      the tyres' grip times gravity, the brakes over the mass -- spends
#      more frames with a wheel on the grass than the one racing on what it
#      measured, because the sheet promises a car it is not driving.
#
# **The heat line is printed, not claimed.** The claim first written for it
# -- that in a race of four the cars change the side they pass on less
# often with it than reacting to one rival at a time -- did not hold when
# measured (2026-10-21): 74 changes of side with it, 40 without. What it
# does is held where it can be stated exactly, in the conformance vectors
# (`heat-goes-round-two-cars-at-once`, `one-rival-at-a-time`), and what it
# does to a race is printed here: the changes of side, the frames two cars
# touched, the hard car's laps. The owner's rule for T51's effects
# (2026-10-21): say what was measured rather than tune until the expected
# result appears.
#
# Each claim is first shown planted numbers it must refuse, and numbers it
# must pass, so a claim that only goes green cannot.
#
#     ./scripts/godot --headless --fixed-fps 60 --path godot -s res://test/racing3d/racing3d_effects.gd
#
# Exit codes: 0 every claim held; 1 one did not, or a planted case passed.
extends SceneTree

const TRACK: String = "res://game3d/racing/tracks/the_loop.json"
const LAPS: int = 3
const SEEDS: Array[int] = [1, 2, 3]
## Seconds a run may take before it is stopped and reported unfinished.
const TIME_LIMIT: float = 400.0
## The hard level's knobs, the field's, and the grid: slower cars ahead.
const HARD: Array = ["hard", 0.9, 0.97, 0.3]
const FIELD: Array[Array] = [["easy", 0.5, 0.75, 2.0], ["easy", 0.5, 0.75, 2.0], ["normal", 0.7, 0.86, 1.0], HARD]

var _errors := Racing3DErrors.new()


func _initialize() -> void:
	OS.add_logger(_errors)
	_run()


func _run() -> void:
	var failures: Array[String] = _planted()
	var track: RaceTrack3D = RaceTrack3D.from_file(TRACK)
	var pid: Dictionary = await _alone(track, true, true)
	var proportional: Dictionary = await _alone(track, false, true)
	var sheet: Dictionary = await _alone(track, true, false)
	_print_alone("full PID, measured grip", pid)
	_print_alone("proportional only", proportional)
	_print_alone("the car's sheet", sheet)
	var heat: Dictionary = await _field(track, true)
	var one: Dictionary = await _field(track, false)
	_print_field("heat line", heat)
	_print_field("one rival at a time", one)
	failures.append_array(claims(pid, proportional, sheet))
	var engine: String = _errors.finding("the races")
	if engine != "":
		failures.append(engine)
	for failure: String in failures:
		print(failure)
	print("racing3d effects: %d failure(s)" % failures.size())
	quit(1 if not failures.is_empty() else 0)


## What is wrong with the measured numbers: one line a claim that failed.
func claims(pid: Dictionary, proportional: Dictionary, sheet: Dictionary) -> Array[String]:
	var found: Array[String] = []
	if not (pid["off_line"] < proportional["off_line"]):
		found.append("PID: %.2f m off the line with it, %.2f m proportional only" % [pid["off_line"], proportional["off_line"]])
	if not (pid["grass"] < sheet["grass"]):
		found.append("grip: %d frames on the grass measured, %d on the sheet" % [pid["grass"], sheet["grass"]])
	return found


# The hard driver alone, LAPS laps, with the PID full or not and the grip
# measured or off the sheet.
func _alone(track: RaceTrack3D, full_pid: bool, measured: bool) -> Dictionary:
	var race := Race3D.new(track, CarPhysics3D.new(), true)
	race.measured_grip = measured
	root.add_child(race)
	var driver: RaceDriver3D = _driver(race, HARD, 1)
	driver.full_pid = full_pid
	race.enter(driver)
	var off_line: float = 0.0
	var grass: int = 0
	while (not race.racing or race.laps(0) < LAPS) and race.time < TIME_LIMIT:
		await physics_frame
		if race.racing and race.frames > 0:
			off_line += absf(driver.line_error)
			grass += 1 if race.cars[0].wheel_surface.has(RaceGround3D.GRASS_GRIP) else 0
	var result: Dictionary = {"off_line": off_line / maxf(race.frames, 1), "grass": grass, "laps": _laps(race, 0)}
	await _take_down(race)
	return result


# The field of four on every seed, everybody's heat line on or off: the
# changes of passing side, the frames two cars touched, and the laps.
func _field(track: RaceTrack3D, heat_vision: bool) -> Dictionary:
	var totals: Dictionary = {"swaps": 0, "touching": 0, "hard_laps": PackedFloat64Array(), "hard_first": 0}
	for seed_value: int in SEEDS:
		var race: Race3D = _field_race(track, heat_vision, seed_value)
		await _race_counting(race, totals)
		totals["hard_laps"].append_array(_laps(race, FIELD.size() - 1))
		totals["hard_first"] += 1 if _leader(race) == FIELD.size() - 1 else 0
		await _take_down(race)
	return totals


# The four on the grid, slowest first, their wander drawn from `seed_value`.
func _field_race(track: RaceTrack3D, heat_vision: bool, seed_value: int) -> Race3D:
	var race := Race3D.new(track, CarPhysics3D.new(), false)
	root.add_child(race)
	for index: int in range(FIELD.size()):
		var driver: RaceDriver3D = _driver(race, FIELD[index], seed_value * 10 + index)
		driver.traffic.heat_vision = heat_vision
		race.enter(driver)
	return race


# Until the hard car has done its laps, every frame counted.
func _race_counting(race: Race3D, totals: Dictionary) -> void:
	var sides := PackedInt64Array([0, 0, 0, 0])
	while (not race.racing or race.laps(FIELD.size() - 1) < LAPS) and race.time < TIME_LIMIT:
		await physics_frame
		if race.racing and race.frames > 0:
			_count_frame(race, sides, totals)


# One frame of a field race: a car whose wanted side flips, and cars touching.
func _count_frame(race: Race3D, sides: PackedInt64Array, totals: Dictionary) -> void:
	for number: int in range(race.cars.size()):
		var offset: float = race.drivers[number].traffic.offset
		var side: int = 0 if absf(offset) < 1.0 else (1 if offset > 0.0 else -1)
		if side != 0 and sides[number] != 0 and side != sides[number]:
			totals["swaps"] += 1
		if side != 0:
			sides[number] = side
		if race.cars[number].get_colliding_bodies().any(func(body: Node) -> bool: return body is RaceCar3D):
			totals["touching"] += 1


func _driver(race: Race3D, knobs: Array, seed_value: int) -> RaceDriver3D:
	var driver := RaceDriver3D.new(RaceLevel3D.new(knobs[0], knobs[1], knobs[2], knobs[3]), Race3D.sheet_of(race.physics))
	driver.drift_from(seed_value)
	return driver


func _laps(race: Race3D, number: int) -> PackedFloat64Array:
	var times := PackedFloat64Array()
	for lap: int in range(race.laps(number)):
		times.append(race.lap_time(number, lap))
	return times


func _leader(race: Race3D) -> int:
	var best: int = 0
	for number: int in range(race.cars.size()):
		if race.covered[number] > race.covered[best]:
			best = number
	return best


func _take_down(race: Race3D) -> void:
	race.queue_free()
	await process_frame


func _print_alone(label: String, run: Dictionary) -> void:
	print("%s: %.2f m off where it wanted to be on average, %d frames on the grass, laps %s"
		% [label, run["off_line"], run["grass"], _rounded(run["laps"])])


func _print_field(label: String, run: Dictionary) -> void:
	print("%s: %d changes of side, %d car-frames touching another car, hard led at the end of %d of %d, its laps %s"
		% [label, run["swaps"], run["touching"], run["hard_first"], SEEDS.size(), _rounded(run["hard_laps"])])


func _rounded(times: PackedFloat64Array) -> String:
	var shown: Array[String] = []
	for time: float in times:
		shown.append("%.1f" % time)
	return "[%s]" % ", ".join(shown)


# Each claim shown numbers it must refuse, and numbers it must pass.
func _planted() -> Array[String]:
	var failures: Array[String] = []
	var good: Array[Dictionary] = [{"off_line": 1.0, "grass": 0}, {"off_line": 2.0, "grass": 0}, {"off_line": 1.0, "grass": 50}]
	var cases: Array[Array] = [
		["a PID no closer than P alone", 0, "off_line", 2.0, "PID:"],
		["a measured grip as often on the grass", 0, "grass", 50, "grip:"],
	]
	if not claims(good[0], good[1], good[2]).is_empty():
		failures.append("planted, numbers that hold were refused: %s" % claims(good[0], good[1], good[2]))
	for planted: Array in cases:
		var bent: Array[Dictionary] = []
		for run: Dictionary in good:
			bent.append(run.duplicate())
		bent[planted[1]][planted[2]] = planted[3]
		var said: String = "\n".join(claims(bent[0], bent[1], bent[2]))
		if not (planted[4] in said):
			failures.append("planted, %s: %s" % [planted[0], said if said != "" else "passed"])
	return failures
