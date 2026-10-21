# What makes T54's ladder mean anything: a harder level is faster because it
# drives better, or this script fails. Over one recorded race of the three
# levels together, cars colliding, LAPS laps, on every physics frame:
#
#   1. every car is a plain `RaceCar3D` driving the race's one
#      `CarPhysics3D`, the same instance, whose fields are still what they
#      were when the race began;
#   2. no car goes past the top speed, by more than SPEED_TOLERANCE -- the
#      engine is cut at the top speed, and one frame of its push past it is
#      under three hundredths of a metre a second -- and no tyre gives more
#      than its grip, by its own car's report;
#   3. the three knob values each driver says it used -- recorded from
#      inside the controller, in `RaceDriver3D.used` -- are the numbers its
#      level was entered with, on every frame;
#   4. and the race is indistinguishable from an honest twin. This script
#      races again, from what it entered -- each level's three numbers and
#      seed, the physics as it began -- with plain drivers, and every car's
#      place and velocity and every decision (steering, throttle, brake)
#      must be the twin's on every frame. Jolt replays a run bit for bit on
#      one binary (T50), and measured here the twin matches to the last bit,
#      so TWIN_TOLERANCE is zero. Nothing the race under test holds is
#      trusted, because a driver can reach all of it; a driver that matches
#      the twin on every frame *is* the honest driver. It is also what makes
#      rule 2's report trustworthy: the twin's plain car must report the
#      same;
#   5. every car covered its laps, so a stalled race checks no fewer frames.
#
# What the twin cannot see is a rule both races run: the grid, the
# collisions, the measuring before the start, the traffic rule. Those are
# the same code for every level; `racing3d_portable_test.gd` holds that
# the decision reads nothing but its view.
#
# Each rule first refuses planted races, each by a finding that names the
# rule it breaks: a stronger engine written into the shared physics, a car
# given a stronger copy of it, a car launched past its top speed, a rubber
# band in the knob and one on the pedal, a nudge forward, a level changed
# mid-race and reported, a margin used whole and reported as the level's,
# and a stall. Planted races are
# PLANTED_SECONDS long and must cover PLANTED_DISTANCE.
#
#     ./scripts/godot --headless --fixed-fps 60 --path godot -s res://test/racing3d/racing3d_does_not_cheat.gd
#
# Exit codes: 0 nobody cheated; 1 somebody did, or a planted cheat went unseen.
extends SceneTree

const TRACK: String = "res://game3d/racing/tracks/the_loop.json"
const LAPS: int = 2
const SEED: int = 54
const TIME_LIMIT: float = 240.0
const PLANTED_SECONDS: float = 20.0
const PLANTED_DISTANCE: float = 200.0
const SPEED_TOLERANCE: float = 0.05
## Newtons a tyre's force may pass its grip by: float rounding in the scale.
const GRIP_TOLERANCE: float = 1e-3
const TWIN_TOLERANCE: float = 0.0
## A broken rule fails on every frame after; this many findings are kept.
const SHOWN: int = 12


## A driver that goes faster the further it is behind the leader: in the
## knob it reports (`in_knob`), or on the pedal after an honest decision.
class RubberBandDriver extends RaceDriver3D:
	var race_held: WeakRef
	var number: int
	var in_knob: bool

	func _init(driving_level: RaceLevel3D, known: Dictionary, race: Race3D, at: int, into_knob: bool) -> void:
		super(driving_level, known)
		race_held = weakref(race)
		number = at
		in_knob = into_knob

	## The level's margin, or more when the band is in the knob.
	func grip_margin_now() -> float:
		return level.grip_margin * (_band() if in_knob else 1.0)

	## An honest decision, then the band on the throttle.
	func decide(view: RaceView3D) -> void:
		super(view)
		if not in_knob:
			throttle = minf(1.0, throttle * _band())

	func _band() -> float:
		var race: Race3D = race_held.get_ref()
		var best: float = race.covered[0]
		for distance: float in race.covered:
			best = maxf(best, distance)
		return 1.0 + clampf((best - race.covered[number]) / 2000.0, 0.0, 0.05)


## A driver that cheats through what it can reach, as `how` says: "engine"
## strengthens the shared physics, "swap" gives its car a stronger copy,
## "launch" throws its car past the top speed, "nudge" pushes it forward,
## "level" changes its level mid-race and says so, "forged" brakes for the
## whole grip while reporting its level's margin, "stall" stops.
class CrookedDriver extends RaceDriver3D:
	var race_held: WeakRef
	var number: int
	var how: String

	func _init(driving_level: RaceLevel3D, known: Dictionary, race: Race3D, at: int, cheat: String) -> void:
		super(driving_level, known)
		race_held = weakref(race)
		number = at
		how = cheat

	## The speed limits -- forged, at the whole grip whatever margin is
	## reported.
	func speed_limits(view: RaceView3D, margin: float) -> PackedFloat64Array:
		return super(view, 1.0 if how == "forged" and view.time > 5.0 else margin)

	## Decides honestly, then cheats as `how` says.
	func decide(view: RaceView3D) -> void:
		if how == "level" and view.time > 5.0:
			level.grip_margin = 1.0
		super(view)
		var car: RaceCar3D = (race_held.get_ref() as Race3D).cars[number]
		var forward: Vector3 = -car.global_transform.basis.z
		var launching: bool = how == "launch" and view.time > 3.0 and view.time < 3.1
		match how:
			"engine":
				car.physics.engine_force = 6600.0
			"swap":
				_swap(car)
			"nudge":
				car.apply_central_force(forward * 1500.0)
			"stall":
				throttle = 0.0
				brake = 1.0
		if launching:
			car.linear_velocity = forward * (car.physics.top_speed + 5.0)

	func _swap(car: RaceCar3D) -> void:
		if car.physics == (race_held.get_ref() as Race3D).physics:
			var stronger: CarPhysics3D = car.physics.duplicate()
			stronger.tyre_grip = 1.2
			car.physics = stronger


var _errors := Racing3DErrors.new()
## The counter's own planted case, run first: "" when it counted it.
var _counter_works: String = ""
var _track: RaceTrack3D


func _initialize() -> void:
	OS.add_logger(_errors)
	_counter_works = _errors.self_check()
	_track = RaceTrack3D.from_file(TRACK)
	_run()


func _run() -> void:
	var failures: Array[String] = await _planted()
	var honest: Array[String] = await findings_for("", 0.0, LAPS * _track.length)
	for finding: String in honest:
		print(finding)
	failures.append_array(honest)
	if _counter_works != "":
		failures.append(_counter_works)
	var engine: String = _errors.finding("the races")
	if engine != "":
		failures.append(engine)
	for failure: String in failures:
		print(failure)
	print("racing3d does not cheat: %d failure(s)" % failures.size())
	quit(1 if not failures.is_empty() else 0)


## Every rule a race of the three levels breaks, with the hard car driven by
## `cheat` ("" for none, "band in knob", "band on pedal", or a CrookedDriver
## way), raced for `seconds` (0: until every car has covered `distance`).
func findings_for(cheat: String, seconds: float, distance: float) -> Array[String]:
	var entered: Array[Array] = _entries()
	var physics := CarPhysics3D.new()
	var start: Dictionary = physics.fields()
	var tested: Dictionary = await _record(entered, physics, cheat, seconds, distance, start)
	var twin_physics := CarPhysics3D.new()
	for field: String in start:
		twin_physics.set(field, start[field])
	var twin: Dictionary = await _record(entered, twin_physics, "", 0.0, 0.0, start, tested["frames"].size())
	var found: Array[String] = tested["findings"]
	found.append_array(_twin_findings(tested["frames"], twin["frames"]))
	if cheat == "":
		print("the race: %d physics frames of three cars, each checked, and the twin's as many" % tested["frames"].size())
	return found.slice(0, SHOWN)


# Each level's title and three numbers, and its seed, as this script enters
# them: what the race is checked against, read before anybody drives.
func _entries() -> Array[Array]:
	var entered: Array[Array] = []
	var index: int = 0
	for level: RaceLevel3D in RaceLevel3D.ladder():
		entered.append([level.title, level.lookahead, level.grip_margin, level.wander, SEED + index])
		index += 1
	return entered


# One race of `entered`, the last driven by `cheat`, recorded every frame
# and checked against rules 1, 2, 3 and 5. A twin is raced for exactly
# `frames` frames instead.
func _record(entered: Array[Array], physics: CarPhysics3D, cheat: String, seconds: float,
		distance: float, start: Dictionary, frames: int = -1) -> Dictionary:
	var race := Race3D.new(_track, physics, false)
	root.add_child(race)
	for index: int in range(entered.size()):
		race.enter(_driver(race, entered[index], index, cheat if index == entered.size() - 1 else ""))
	var findings: Array[String] = []
	var recorded: Array[PackedFloat64Array] = []
	while _going(race, seconds, distance, frames, recorded.size()):
		await physics_frame
		if race.racing and race.frames > 0:
			recorded.append(_frame_of(race))
			findings.append_array(_frame_findings(race, entered, start) if findings.size() < SHOWN else [])
	if frames < 0:
		findings.append_array(_unfinished(race, entered, distance))
	race.queue_free()
	await process_frame
	return {"frames": recorded, "findings": findings}


# Rule 5: every car that did not cover `distance`.
func _unfinished(race: Race3D, entered: Array[Array], distance: float) -> Array[String]:
	var found: Array[String] = []
	for number: int in range(race.cars.size()):
		if race.covered[number] < distance:
			found.append("rule 5, finishing: %s covered %.0f m of %.0f" % [entered[number][0], race.covered[number], distance])
	return found


func _going(race: Race3D, seconds: float, distance: float, frames: int, done: int) -> bool:
	if frames >= 0:
		return done < frames
	if not race.racing:
		return true
	if seconds > 0.0:
		return race.time < seconds
	return race.time < TIME_LIMIT and _least(race) < distance


func _least(race: Race3D) -> float:
	var least: float = INF
	for covered: float in race.covered:
		least = minf(least, covered)
	return least


func _driver(race: Race3D, entry: Array, index: int, cheat: String) -> RaceDriver3D:
	var level := RaceLevel3D.new(entry[0], entry[1], entry[2], entry[3])
	var known: Dictionary = Race3D.sheet_of(race.physics)
	var driver: RaceDriver3D
	if cheat == "band in knob" or cheat == "band on pedal":
		driver = RubberBandDriver.new(level, known, race, index, cheat == "band in knob")
	elif cheat != "":
		driver = CrookedDriver.new(level, known, race, index, cheat)
	else:
		driver = RaceDriver3D.new(level, known)
	driver.drift_from(entry[4])
	return driver


# Every car's place and velocity, and every driver's last decision.
func _frame_of(race: Race3D) -> PackedFloat64Array:
	var frame := PackedFloat64Array()
	for number: int in range(race.cars.size()):
		var car: RaceCar3D = race.cars[number]
		var driver: RaceDriver3D = race.drivers[number]
		var at: Vector3 = car.global_position
		var moving: Vector3 = car.linear_velocity
		frame.append_array([at.x, at.y, at.z, moving.x, moving.y, moving.z, driver.steer, driver.throttle, driver.brake])
	return frame


# Rules 1, 2 and 3 on this frame.
func _frame_findings(race: Race3D, entered: Array[Array], start: Dictionary) -> Array[String]:
	var found: Array[String] = []
	for number: int in range(race.cars.size()):
		var car: RaceCar3D = race.cars[number]
		var title: String = entered[number][0]
		if car.get_script() != RaceCar3D or car.physics != race.physics or race.physics.fields() != start:
			found.append("rule 1, one physics: %s at %.2f s does not drive the race's physics as it began" % [title, race.time])
		var speed: float = (car.linear_velocity * Vector3(1, 0, 1)).length()
		if not (speed <= race.physics.top_speed + SPEED_TOLERANCE):
			found.append("rule 2, top speed: %s at %.2f m/s at %.2f s" % [title, speed, race.time])
		found.append_array(_past_grip(car, title))
		var used: Dictionary = race.drivers[number].used
		var knobs: Array = [used.get("lookahead"), used.get("grip_margin"), used.get("wander")]
		if knobs != entered[number].slice(1, 4):
			found.append("rule 3, knobs: %s used %s at %.2f s, entered %s" % [title, knobs, race.time, entered[number].slice(1, 4)])
	return found


func _past_grip(car: RaceCar3D, title: String) -> Array[String]:
	var found: Array[String] = []
	for wheel: int in range(4):
		if not (car.wheel_force[wheel] <= car.wheel_limit[wheel] + GRIP_TOLERANCE):
			found.append("rule 2, grip: %s's %s tyre at %.0f N past %.0f" % [title, RaceCar3D.WHEEL_NAMES[wheel], car.wheel_force[wheel], car.wheel_limit[wheel]])
	return found


# Rule 4: the race and its honest twin, frame by frame. Every comparison
# in this script is written `not (x <= limit)`, so a NaN breaks the rule.
func _twin_findings(tested: Array[PackedFloat64Array], twin: Array[PackedFloat64Array]) -> Array[String]:
	if tested.size() != twin.size():
		return ["rule 4, twin: %d frames raced, the twin %d" % [tested.size(), twin.size()]]
	for frame: int in range(tested.size()):
		var apart: int = _first_apart(tested[frame], twin[frame])
		if apart >= 0:
			var values: Array = [frame, apart / 9, apart % 9, tested[frame][apart], twin[frame][apart]]
			return ["rule 4, twin: frame %d, car %d, value %d is %.9f, the honest twin's %.9f" % values]
	return []


# The first value two frames' records differ in by more than the tolerance.
func _first_apart(tested: PackedFloat64Array, twin: PackedFloat64Array) -> int:
	for value: int in range(tested.size()):
		if not (absf(tested[value] - twin[value]) <= TWIN_TOLERANCE):
			return value
	return -1


# Each planted race, refused by the rule it breaks.
func _planted() -> Array[String]:
	var failures: Array[String] = []
	var cases: Array[Array] = [
		["engine", "rule 1"], ["swap", "rule 1"], ["launch", "rule 2, top speed"],
		["band in knob", "rule 3"], ["band on pedal", "rule 4"], ["nudge", "rule 4"],
		["level", "rule 3"], ["forged", "rule 4"], ["stall", "rule 5"],
	]
	for planted: Array in cases:
		var said: String = "\n".join(await findings_for(planted[0], PLANTED_SECONDS, PLANTED_DISTANCE))
		if not (planted[1] in said):
			failures.append("planted, %s: %s" % [planted[0], said if said != "" else "passed"])
	return failures
