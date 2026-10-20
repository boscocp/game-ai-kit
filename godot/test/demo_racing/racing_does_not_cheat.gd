# The part that makes T23's ladder mean anything: a harder level is faster
# because of its three knobs, or this script fails. Over one recorded race,
# the three levels together, `LAPS` laps, on every frame:
#
#   1. every car is a plain `RacingCar` driving the race's one physics
#      resource, whose fields are still what they were when the race began;
#   2. no car goes past the top speed, or turns harder than its grip holds:
#      speed times turn rate, as the car took it on its own step. A
#      collision turns and speeds a car too, and that is a blow, not grip;
#      the twin holds the blow. What the car reports is trusted here only
#      because the twin's plain car must report the same;
#   3. the three knob values each driver says it used -- recorded from
#      inside the controller, in `RacingDriver.used` -- are its level's on
#      every frame. That is the driver's own report: it makes a knob that
#      moves visible by name, and Game AI Pro's slow "biorhythm" in skill,
#      which T23 refuses, fails here;
#   4. and the race is indistinguishable from an honest twin. This script
#      builds its own race from what it entered -- each level's three
#      numbers and seed, the physics as the race began -- with a plain
#      `RacingDriver` for each, and steps it alongside. Every car's place,
#      heading and speed, every decision (aim, speed, turn) and the race's
#      record of it (line sample, distance covered, laps) must be the
#      twin's. Nothing the race under test holds is trusted -- not its cars,
#      its drivers, their levels, its track or its books -- because a driver
#      can reach all of them. A driver that matches the twin on every frame
#      *is* the honest driver, whatever its code says;
#   5. every car finished its laps, so a stalled race checks no fewer frames.
#
# What the twin cannot see is a rule both races run: the grid and the
# collision in `RacingRace`, and following and passing in `RacingDriver`.
# A rule there that favoured a level would be in the twin too. What holds
# those is weaker, and said so: `racing_test.gd` refuses a
# `racing_race.gd` whose code names a level, a knob, or the human's driver
# -- an honest slip, not a determined cheat -- and the passing rule is
# measured in traffic (T59's record), not proven.
#
# Each rule first refuses planted races, each by a finding that names the
# rule it breaks: more grip, a car that turns past its grip, a stronger
# engine, a physics swapped mid-race, a car launched past its top speed, a
# rubber band in the knob and one where the knob is used, a nudge forward,
# a speed taken from further down the line, an aim wider than the wander
# and one that never wanders, a turn at another point than the one
# reported, a faster limit written into the track, distance credited that
# was not driven, a level changed mid-race -- reported, and forged -- and a
# stall.
#
#     ./scripts/godot --headless --path godot -s res://test/demo_racing/racing_does_not_cheat.gd
#
# Exit codes: 0 nobody cheated; 1 somebody did, or a planted cheat went unseen.
extends SceneTree

const LAPS: int = 2
const SEED: int = 23
## Seconds the recorded race may last; easy's two laps take about 78.
const TIME_LIMIT: float = 120.0
## Room for float rounding in a limit measured after it was applied. The
## twin needs none: the same steps in the same order give the same floats.
const TOLERANCE: float = 1e-4
## A broken rule fails on every frame after; this many findings are printed.
const SHOWN: int = 20


## A driver that goes faster the further it is behind the leader: the
## rubber band, in the two places it can hide. Read into the knob
## (`in_knob`), it changes the margin the driver reports; applied at the
## point of use, it leaves the report honest and changes the decision.
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


## A driver that cheats through what it was handed, as `how` says: "swap"
## its car's physics for a stronger copy, "nudge" the car forward, "launch"
## it past the top speed, take its speed from further down the line
## ("ahead"), aim "wide" of its wander or never wander ("narrow"), steer at
## a point it does not report ("elsewhere"), raise the track's speed limit
## ("track"), or change its own level mid-race -- saying so ("knob"), or
## forging its report ("level"). And "stall", which only stops, for rule 5.
class CrookedDriver extends RacingDriver:
	var how: String
	var honest_margin: float

	func _init(driving_level: RacingLevel, seed_value: int, cheat: String) -> void:
		super(driving_level, seed_value)
		how = cheat
		honest_margin = driving_level.grip_margin

	## Decides honestly, then cheats as `how` says.
	func decide(car: RacingCar, track: RacingTrack, index: int, time: float) -> void:
		if how in ["knob", "level"] and time > 5.0:
			level.grip_margin = 1.0
		super(car, track, index, time)
		match how:
			"swap":
				_swap(car, time)
			"nudge":
				car.position += Vector2.from_angle(car.heading) * 0.05
			"launch":
				car.speed = maxf(car.speed, car.physics.top_speed + 5.0)
			"ahead":
				target_speed = RacingDriver.speed_limit(track, track.wrapped(index + 3), car.physics, level.grip_margin)
			"wide", "narrow":
				aim = track.point_ahead(index, level.lookahead, 3.0 * level.wander + 1.0 if how == "wide" else 0.0)
				wanted_turn = RacingDriver.pursuit_turn(car, aim)
			"elsewhere":
				wanted_turn = RacingDriver.pursuit_turn(car, track.point_ahead(index, 2.0 * level.lookahead, 0.0))
			"track":
				track.full_grip_limit[index] = track.full_grip_limit[index] * 1.1
			"level":
				used["grip_margin"] = honest_margin
			"stall":
				target_speed = 0.0

	# A second into the race, a copy of the physics with a stronger engine.
	func _swap(car: RacingCar, time: float) -> void:
		if time > 1.0 and car.physics.acceleration < 10.0:
			car.physics = car.physics.duplicate()
			car.physics.acceleration *= 1.5


## A driver that credits its car with distance it did not drive, through
## the race it holds.
class BookkeeperDriver extends RacingDriver:
	var held_race: WeakRef
	var number: int

	func _init(driving_level: RacingLevel, seed_value: int, race: RacingRace, car_number: int) -> void:
		super(driving_level, seed_value)
		held_race = weakref(race)
		number = car_number

	## An honest decision, and thirty centimetres more on the race's books.
	func decide(car: RacingCar, track: RacingTrack, index: int, time: float) -> void:
		super(car, track, index, time)
		var race: RacingRace = held_race.get_ref()
		race.covered[number] += 0.3


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
	var entries: Array = []
	for level: RacingLevel in RacingLevel.ladder():
		entries.append([level, SEED])
	var race: RacingRace = _race_of(entries)
	failures.append_array(cheat_findings(race, entries))
	for failure: String in failures.slice(0, SHOWN):
		print(failure)
	if failures.size() > SHOWN:
		print("... and %d more" % (failures.size() - SHOWN))
	print("racing does not cheat: %d cars, %d frames, %d failure(s)" % [race.cars.size(), race.steps, failures.size()])
	quit(1 if not failures.is_empty() else 0)


## Run `race` until every car has finished `LAPS` laps, and say every way it
## was not a fair one. `entries` is what the caller entered, in order: each
## car's `[RacingLevel, seed]`, copied before the race starts so a driver
## cannot change the record of what it was meant to be. Empty when fair.
func cheat_findings(race: RacingRace, entries: Array) -> Array[String]:
	var began: RacingPhysics = race.physics.duplicate()
	var levels: Array[RacingLevel] = []
	var twin := RacingRace.new(began.duplicate())
	for entry: Array in entries:
		levels.append(_copy(entry[0]))
		twin.enter(RacingDriver.new(_copy(entry[0]), entry[1]))
	var findings: Array[String] = []
	while not _all_finished(race) and race.time < TIME_LIMIT:
		race.step()
		twin.step()
		for number: int in range(race.cars.size()):
			findings.append_array(_frame_findings(race, twin, number, began, levels[number]))
	for number: int in range(race.cars.size()):
		if race.laps(number) < LAPS:
			findings.append("car %d did not finish %d laps in %.0f s" % [number, LAPS, TIME_LIMIT])
	return findings


# Every rule on one car, on the frame just stepped.
func _frame_findings(race: RacingRace, twin: RacingRace, number: int, began: RacingPhysics,
		level: RacingLevel) -> Array[String]:
	var where: String = "car %d, frame %d" % [number, race.steps]
	var findings: Array[String] = _car_findings(race, number, began, where)
	findings.append_array(_limit_findings(race.cars[number], began, where))
	var said: Dictionary = race.drivers[number].used
	var knobs: Dictionary = {"lookahead": level.lookahead, "grip_margin": level.grip_margin, "wander": level.wander}
	if said != knobs:
		findings.append("%s: says it used %s, its level is %s" % [where, said, knobs])
	findings.append_array(_twin_findings(race, twin, number, where))
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


# Rule 2: the top speed, and the grip the car's own turn took.
func _limit_findings(car: RacingCar, began: RacingPhysics, where: String) -> Array[String]:
	var findings: Array[String] = []
	var sideways: float = car.sideways_acceleration()
	if car.speed > began.top_speed + TOLERANCE:
		findings.append("%s: speed %.3f over the top speed" % [where, car.speed])
	if sideways > began.grip + TOLERANCE:
		findings.append("%s: turned at %.3f sideways, over the grip" % [where, sideways])
	return findings


# Rule 4: car `number` and its twin, field by field. The first that differs
# is named; one is enough, and every later frame would repeat it.
func _twin_findings(race: RacingRace, twin: RacingRace, number: int, where: String) -> Array[String]:
	var ours: Dictionary = _seen(race, number)
	var honest: Dictionary = _seen(twin, number)
	for field: String in ours:
		if ours[field] != honest[field]:
			return ["%s: its %s is %s, its honest twin's is %s" % [where, field, ours[field], honest[field]]]
	return []


# Everything about car `number` in `race` that its twin must share, in the
# order one causes the next -- the decision, then the car that followed it,
# then the race's books -- so the first that differs names what was done.
func _seen(race: RacingRace, number: int) -> Dictionary:
	var car: RacingCar = race.cars[number]
	var driver: RacingDriver = race.drivers[number]
	return {"aim": driver.aim, "target speed": driver.target_speed, "turn": driver.wanted_turn,
		"speed": car.speed, "heading": car.heading, "position": car.position,
		"line sample": race.line_index[number], "centre sample": race.centre_index[number],
		"distance covered": race.covered[number], "laps": race.laps(number)}


func _copy(level: RacingLevel) -> RacingLevel:
	return RacingLevel.new(level.title, level.lookahead, level.grip_margin, level.wander)


func _all_finished(race: RacingRace) -> bool:
	for number: int in range(race.cars.size()):
		if race.laps(number) < LAPS:
			return false
	return true


# The planted races. Each must be refused by a finding naming the rule it
# breaks, not merely by some finding. The gripless car is driven by a level
# that dares half as much again as its grip, so it asks for turns no honest
# car could take.
func _planted() -> Array[String]:
	var hard: RacingLevel = RacingLevel.ladder()[2]
	var failures: Array[String] = []
	var two_hard: Array = [[hard, SEED], [hard, SEED]]
	var stronger: RacingRace = _race_of(two_hard)
	stronger.cars[1].physics = stronger.physics.duplicate()
	stronger.cars[1].physics.grip *= 1.2
	failures.append_array(_refused("more grip", stronger, two_hard, "its grip is"))
	var reckless: Array = [[RacingLevel.new("reckless", 8.0, 1.5, 0.0), SEED]]
	var gripless: RacingRace = _race_of(reckless)
	gripless.cars[0] = GriplessCar.new(gripless.physics, gripless.cars[0].position, gripless.cars[0].heading)
	failures.append_array(_refused("past its grip", gripless, reckless, "over the grip"))
	var engine: RacingRace = _race_of([[hard, SEED]])
	engine.cars[0] = StrongerEngineCar.new(engine.physics, engine.cars[0].position, engine.cars[0].heading)
	failures.append_array(_refused("a stronger engine", engine, [[hard, SEED]], "not a plain RacingCar"))
	failures.append_array(_planted_crooks())
	failures.append_array(_planted_through_the_race())
	return failures


# One easy driver for each of `CrookedDriver`'s cheats, alone, each with the
# finding that must name it. Entered with the very level it drives with, so
# a driver that changes its level changes the entry too -- which the check
# must have copied before the start.
func _planted_crooks() -> Array[String]:
	var expected: Dictionary = {"swap": "the race's physics", "launch": "over the top speed",
		"nudge": "its position", "ahead": "its target speed", "wide": "its aim", "narrow": "its aim",
		"elsewhere": "its turn", "track": "its target speed", "knob": "says it used",
		"level": "its target speed", "stall": "did not finish"}
	var failures: Array[String] = []
	for how: String in expected:
		var easy := RacingLevel.new("easy", 8.0, 0.75, 2.0)
		var race: RacingRace = _race_of([])
		race.enter(CrookedDriver.new(easy, SEED, how))
		failures.append_array(_refused("a driver that cheats by %s" % how, race, [[easy, SEED]], expected[how]))
	return failures


# The cheats that need the race itself: two rubber bands behind an honest
# leader, and distance credited that was not driven.
func _planted_through_the_race() -> Array[String]:
	var levels: Array[RacingLevel] = RacingLevel.ladder()
	var entered: Array = [[levels[2], SEED], [levels[0], SEED]]
	var failures: Array[String] = []
	for in_knob: bool in [true, false]:
		var race: RacingRace = _race_of([[levels[2], SEED]])
		race.enter(RubberBandDriver.new(levels[0], SEED, race, in_knob))
		var because: String = "says it used" if in_knob else "its target speed"
		failures.append_array(_refused("a rubber band %s" % ("in the knob" if in_knob else "where it is used"),
			race, entered, because))
	var books: RacingRace = _race_of([[levels[2], SEED]])
	books.enter(BookkeeperDriver.new(levels[0], SEED, books, 1))
	failures.append_array(_refused("distance not driven", books, entered, "its distance covered"))
	return failures


# A race with a plain driver for each `[RacingLevel, seed]` entry.
func _race_of(entries: Array) -> RacingRace:
	var race := RacingRace.new(RacingPhysics.new())
	for entry: Array in entries:
		race.enter(RacingDriver.new(entry[0], entry[1]))
	return race


# Empty when `race` is refused with a finding containing `because`.
func _refused(what: String, race: RacingRace, entries: Array, because: String) -> Array[String]:
	for finding: String in cheat_findings(race, entries):
		if because in finding:
			return []
	return ["planted, %s: not refused" % what]
