# The part that makes T23's ladder mean anything: a harder level is faster
# because of its three knobs, or this script fails. Over one recorded race,
# the three levels together, `LAPS` laps, on every frame:
#
#   1. every car is a plain `RacingCar` driving the race's one physics
#      resource, whose fields are still what they were when the race began;
#   2. every car moved exactly as an honest car would: a fresh `RacingCar`
#      on the physics the race began with, put where the car was before the
#      step and given what its driver asked for, ends where the car ended.
#      Nothing the car or the driver reports about itself is trusted here --
#      a stronger engine, a nudge forward, a physics swapped mid-race all
#      land somewhere an honest car does not. And measured from where it
#      was to where it is, no car goes past the top speed or turns harder
#      than its grip holds (speed times turn rate);
#   3. the three knob values the driver *actually used* -- recorded from
#      inside the controller, in `RacingDriver.used`, not read back from the
#      level -- are the same on every frame, and are the level's. Game AI
#      Pro's slow "biorhythm" in skill, which T23 also refuses, fails here;
#   4. what the driver decided is what its level's knobs give, recomputed
#      from the line sample the race handed it and the car as it was: the
#      speed is the track's limit at the level's margin, the point it steers
#      at is within the level's wander of its lookahead point, and the turn
#      is pure pursuit of that point. A rubber band applied where a knob is
#      used, after the knob was read, slips past rule 3 and is caught here;
#   5. and every car finished its laps, so a race that stalled cannot go
#      green by checking fewer frames.
#
# Each rule first refuses planted races, each by the rule it breaks: a car
# given more grip, a car that turns past its grip, a car with a stronger
# engine, a driver that swaps its physics mid-race, one that nudges its car
# forward, one that launches it past its top speed, two rubber bands (in the
# knob, and where it is used), a driver that takes its speed from further
# down the line and says it is there, one that aims wider than its wander,
# one that steers at another point than the one it reports, and one that
# stalls.
#
#     ./scripts/godot --headless --path godot -s res://test/demo_racing/racing_does_not_cheat.gd
#
# Exit codes: 0 nobody cheated; 1 somebody did, or a planted cheat went unseen.
extends SceneTree

const LAPS: int = 2
const SEED: int = 23
## Seconds the recorded race may last; easy's two laps take about 78.
const TIME_LIMIT: float = 120.0
## Room for float rounding in a limit compared after it was applied.
const TOLERANCE: float = 1e-4
## A broken rule fails on every frame after; this many findings are printed.
const SHOWN: int = 20


## A driver that goes faster the further it is behind the leader: the
## rubber band, in the two places it can hide. Read into the knob
## (`in_knob`), it changes the margin the driver records; applied at the
## point of use, it leaves the record honest and changes the decision.
class RubberBandDriver extends RacingDriver:
	# Weak, because the race holds this driver: a strong reference both ways
	# is a cycle that is never freed.
	var leader_race: WeakRef
	var in_knob: bool

	func _init(driving_level: RacingLevel, seed_value: int, race: RacingRace, into_knob: bool) -> void:
		super(driving_level, seed_value)
		leader_race = weakref(race)
		in_knob = into_knob

	## The level's margin, or more when the band is in the knob.
	func grip_margin_now() -> float:
		return level.grip_margin * (_band() if in_knob else 1.0)

	## An honest decision, then the band on the speed it chose.
	func decide(car: RacingCar, track: RacingTrack, index: int, time: float) -> void:
		super(car, track, index, time)
		target_speed *= 1.0 if in_knob else _band()

	# 1, plus a hundredth for every 20 metres behind the leader, up to 1.05.
	func _band() -> float:
		var race: RacingRace = leader_race.get_ref()
		return 1.0 + clampf((race.covered[0] - race.covered[1]) / 2000.0, 0.0, 0.05)


## A driver that cheats in one of these ways: "swap" its car's physics for a
## stronger copy, "nudge" the car forward, "launch" it past the top speed,
## take its speed from further down the line and say it is there ("ahead"),
## aim "wide" of what its wander allows, or steer at a point it does not
## report ("elsewhere"). And "stall", which only stops, for rule 5.
class CrookedDriver extends RacingDriver:
	var how: String

	func _init(driving_level: RacingLevel, seed_value: int, cheat: String) -> void:
		super(driving_level, seed_value)
		how = cheat

	## Decides honestly or not, as `how` says.
	func decide(car: RacingCar, track: RacingTrack, index: int, time: float) -> void:
		super(car, track, index, time)
		match how:
			"swap":
				_swap(car, time)
			"nudge":
				car.position += Vector2.from_angle(car.heading) * 0.05
			"ahead":
				decided_at = track.wrapped(index + 3)
				target_speed = RacingDriver.speed_limit(track, decided_at, car.physics, level.grip_margin)
			"wide":
				aim = track.point_ahead(index, level.lookahead, 3.0 * level.wander + 1.0)
				wanted_turn = RacingDriver.pursuit_turn(car, aim)
			"elsewhere":
				wanted_turn = RacingDriver.pursuit_turn(car, track.point_ahead(index, 2.0 * level.lookahead, 0.0))
			"launch":
				car.speed = maxf(car.speed, car.physics.top_speed + 5.0)
			"stall":
				target_speed = 0.0

	# A second into the race, a copy of the physics with a stronger engine.
	func _swap(car: RacingCar, time: float) -> void:
		if time > 1.0 and car.physics.acceleration < 10.0:
			car.physics = car.physics.duplicate()
			car.physics.acceleration *= 1.5


## A car that forgets the grip: it turns as tight as its turn rate allows,
## at any speed.
class GriplessCar extends RacingCar:
	## Only the turn rate, never the grip.
	func turn_limit() -> float:
		return physics.turn_rate


## A car with half as much engine again as anybody else's.
class StrongerEngineCar extends RacingCar:
	## Speeds up at one and a half times the physics' acceleration.
	func step(wanted_speed: float, wanted_turn: float, on_track: bool, dt: float) -> void:
		var honest: float = speed
		super(wanted_speed, wanted_turn, on_track, dt)
		if speed > honest:
			speed = minf(wanted_speed, honest + 1.5 * physics.acceleration * dt)


func _init() -> void:
	var failures: Array[String] = _planted()
	var race := RacingRace.new(RacingPhysics.new())
	for level: RacingLevel in RacingLevel.ladder():
		race.enter(RacingDriver.new(level, SEED))
	failures.append_array(cheat_findings(race))
	for failure: String in failures.slice(0, SHOWN):
		print(failure)
	if failures.size() > SHOWN:
		print("... and %d more" % (failures.size() - SHOWN))
	print("racing does not cheat: %d cars, %d frames, %d failure(s)" % [race.cars.size(), race.steps, failures.size()])
	quit(1 if not failures.is_empty() else 0)


## Run `race` until every car has finished `LAPS` laps, and say every way
## it was not a fair one. Empty when nobody was given anything.
func cheat_findings(race: RacingRace) -> Array[String]:
	var began: RacingPhysics = race.physics.duplicate()
	var findings: Array[String] = []
	var first_used: Array[Dictionary] = []
	while not _all_finished(race) and race.time < TIME_LIMIT:
		var before: Array[Dictionary] = _before(race)
		race.step()
		if first_used.is_empty():
			first_used = _used(race)
		for number: int in range(race.cars.size()):
			findings.append_array(_frame_findings(race, number, before[number], began, first_used[number]))
	for number: int in range(race.cars.size()):
		findings.append_array(_level_findings(race.drivers[number], first_used[number]))
		if race.laps(number) < LAPS:
			findings.append("car %d did not finish %d laps in %.0f s" % [number, LAPS, TIME_LIMIT])
	return findings


# The knobs each driver used on the step just taken.
func _used(race: RacingRace) -> Array[Dictionary]:
	var used: Array[Dictionary] = []
	for driver: RacingDriver in race.drivers:
		used.append(driver.used.duplicate())
	return used


# Each car as it is now, before the step: where the replay starts from.
func _before(race: RacingRace) -> Array[Dictionary]:
	var cars: Array[Dictionary] = []
	for number: int in range(race.cars.size()):
		var car: RacingCar = race.cars[number]
		cars.append({"position": car.position, "heading": car.heading, "speed": car.speed,
			"line": race.line_index[number], "centre": race.centre_index[number]})
	return cars


# Every rule on one car, on the frame just stepped.
func _frame_findings(race: RacingRace, number: int, before: Dictionary, began: RacingPhysics,
		first_used: Dictionary) -> Array[String]:
	var where: String = "car %d, frame %d" % [number, race.steps]
	var findings: Array[String] = _car_findings(race, number, began, where)
	findings.append_array(_movement_findings(race, number, before, began, where))
	if race.drivers[number].used != first_used:
		findings.append("%s: used %s, but %s on its first frame" % [where, race.drivers[number].used, first_used])
	findings.append_array(_decision_findings(race, number, before, began, where))
	return findings


# Rule 1: a plain car, on the race's physics, unchanged since the start.
func _car_findings(race: RacingRace, number: int, began: RacingPhysics, where: String) -> Array[String]:
	var findings: Array[String] = []
	var car: RacingCar = race.cars[number]
	if car.get_script() != RacingCar:
		findings.append("%s: is a %s, not a plain RacingCar" % [where, car.get_script().resource_path])
	if car.physics != race.physics:
		findings.append("%s: does not drive the race's physics" % where)
	for property: Dictionary in car.physics.get_property_list():
		var field: String = property["name"]
		if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE != 0 and car.physics.get(field) != began.get(field):
			findings.append("%s: its %s is %s, the race began with %s" % [where, field, car.physics.get(field), began.get(field)])
	return findings


# Rule 2: the step replayed on an honest car, and the limits measured from
# where the car was to where it is.
func _movement_findings(race: RacingRace, number: int, before: Dictionary, began: RacingPhysics,
		where: String) -> Array[String]:
	var findings: Array[String] = []
	var car: RacingCar = race.cars[number]
	var driver: RacingDriver = race.drivers[number]
	var honest: RacingCar = _car_as_it_was(before, began)
	honest.step(driver.target_speed, driver.wanted_turn, race.track.on_track(before["position"], before["centre"]),
		RacingRace.DT)
	var apart: float = maxf(car.position.distance_to(honest.position), absf(car.speed - honest.speed))
	if apart > TOLERANCE or absf(car.heading - honest.heading) > TOLERANCE:
		findings.append("%s: ended at %s going %.3f, an honest car at %s going %.3f" % [
			where, car.position, car.speed, honest.position, honest.speed])
	var sideways: float = car.speed * absf(car.heading - before["heading"]) / RacingRace.DT
	if car.speed > began.top_speed + TOLERANCE:
		findings.append("%s: speed %.3f over the top speed" % [where, car.speed])
	if sideways > began.grip + TOLERANCE:
		findings.append("%s: turned at %.3f sideways, over the grip" % [where, sideways])
	return findings


# Rule 4: the decision, recomputed from the level's own knobs, at the line
# sample the race handed the driver, for the car as it was.
func _decision_findings(race: RacingRace, number: int, before: Dictionary, began: RacingPhysics,
		where: String) -> Array[String]:
	var findings: Array[String] = []
	var driver: RacingDriver = race.drivers[number]
	var honest: float = RacingDriver.speed_limit(race.track, before["line"], began, driver.level.grip_margin)
	if absf(driver.target_speed - honest) > TOLERANCE:
		findings.append("%s: chose %.3f m/s, its level's margin gives %.3f" % [where, driver.target_speed, honest])
	var off: float = driver.aim.distance_to(race.track.point_ahead(before["line"], driver.level.lookahead, 0.0))
	if off > driver.level.wander + TOLERANCE:
		findings.append("%s: aimed %.2f m from its level's lookahead point, wander allows %.2f" % [
			where, off, driver.level.wander])
	var pursuit: float = RacingDriver.pursuit_turn(_car_as_it_was(before, began), driver.aim)
	if absf(driver.wanted_turn - pursuit) > TOLERANCE:
		findings.append("%s: steered at %.4f, pursuit of the point it reports gives %.4f" % [
			where, driver.wanted_turn, pursuit])
	return findings


# A fresh, plain car where `before` says one was, on the physics `began`.
func _car_as_it_was(before: Dictionary, began: RacingPhysics) -> RacingCar:
	var car := RacingCar.new(began, before["position"], before["heading"])
	car.speed = before["speed"]
	return car


# Rule 3's other half: what the driver used is what its level says.
func _level_findings(driver: RacingDriver, used: Dictionary) -> Array[String]:
	var level: Dictionary = {"lookahead": driver.level.lookahead, "grip_margin": driver.level.grip_margin,
		"wander": driver.level.wander}
	if used != level:
		return ["%s used %s, not its level's %s" % [driver.level.title, used, level]]
	return []


func _all_finished(race: RacingRace) -> bool:
	for number: int in range(race.cars.size()):
		if race.laps(number) < LAPS:
			return false
	return true


# The planted races. Each must be refused, and by the rule it breaks: the
# finding has to name that rule, not merely exist. The gripless car is driven
# by a level that dares half as much again as its grip, so that it asks for
# turns no honest car could take.
func _planted() -> Array[String]:
	var failures: Array[String] = []
	var hard: RacingLevel = RacingLevel.ladder()[2]
	var stronger: RacingRace = _race_of([RacingDriver.new(hard, SEED), RacingDriver.new(hard, SEED)])
	stronger.cars[1].physics = stronger.physics.duplicate()
	stronger.cars[1].physics.grip *= 1.2
	failures.append_array(_refused("a car given more grip", stronger, "its grip is"))
	var gripless: RacingRace = _race_of([RacingDriver.new(RacingLevel.new("reckless", 8.0, 1.5, 0.0), SEED)])
	gripless.cars[0] = GriplessCar.new(gripless.physics, gripless.cars[0].position, gripless.cars[0].heading)
	failures.append_array(_refused("a car that turns past its grip", gripless, "over the grip"))
	var engine: RacingRace = _race_of([RacingDriver.new(hard, SEED)])
	engine.cars[0] = StrongerEngineCar.new(engine.physics, engine.cars[0].position, engine.cars[0].heading)
	failures.append_array(_refused("a stronger engine", engine, "not a plain RacingCar"))
	failures.append_array(_refused("a physics swapped mid-race", _crooked(hard, "swap"), "the race's physics"))
	failures.append_array(_refused("a car nudged forward", _crooked(hard, "nudge"), "an honest car"))
	failures.append_array(_refused("speed from further down the line", _crooked(hard, "ahead"), "margin gives"))
	failures.append_array(_refused("aiming wider than its wander", _crooked(hard, "wide"), "aimed"))
	failures.append_array(_refused("steering at another point", _crooked(hard, "elsewhere"), "steered at"))
	failures.append_array(_refused("a car launched past its top speed", _crooked(hard, "launch"), "over the top speed"))
	failures.append_array(_refused("a car that stalls", _crooked(hard, "stall"), "did not finish"))
	failures.append_array(_rubber_bands())
	return failures


# The two rubber bands, each behind an honest leader.
func _rubber_bands() -> Array[String]:
	var levels: Array[RacingLevel] = RacingLevel.ladder()
	var failures: Array[String] = []
	for in_knob: bool in [true, false]:
		var race: RacingRace = _race_of([RacingDriver.new(levels[2], SEED)])
		race.enter(RubberBandDriver.new(levels[0], SEED, race, in_knob))
		var because: String = "on its first frame" if in_knob else "level's margin gives"
		failures.append_array(_refused("a rubber band %s" % ("in the knob" if in_knob else "where it is used"),
			race, because))
	return failures


func _race_of(drivers: Array[RacingDriver]) -> RacingRace:
	var race := RacingRace.new(RacingPhysics.new())
	for driver: RacingDriver in drivers:
		race.enter(driver)
	return race


func _crooked(level: RacingLevel, how: String) -> RacingRace:
	return _race_of([CrookedDriver.new(level, SEED, how)])


# Empty when `race` is refused with a finding containing `because`.
func _refused(what: String, race: RacingRace, because: String) -> Array[String]:
	for finding: String in cheat_findings(race):
		if because in finding:
			return []
	return ["planted, %s: not refused" % what]
