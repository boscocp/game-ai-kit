# The part that makes T23's ladder mean anything: a harder level is faster
# because of its three knobs, or this script fails. Over one recorded race,
# the three levels together, `LAPS` laps:
#
#   1. every car's physics is the race's one resource, and field for field
#      the same as every other car's;
#   2. on every frame, no car goes faster than the top speed or turns harder
#      than its grip holds (speed times turn rate);
#   3. the three knob values the driver *actually used* on every frame --
#      recorded from inside the controller, in `RacingDriver.used`, not read
#      back from the level -- are the same on every frame of the race, and
#      are the level's. Game AI Pro's slow "biorhythm" in skill, which T23
#      also refuses, would fail here too;
#   4. and what the driver decided on every frame is what its level's knobs
#      give: the speed it chose is the track's limit at the level's grip
#      margin, and the point it steers at is no further from the level's
#      lookahead point than the level's wander. A rubber band applied where
#      a knob is used, `margin * f(gap)` after the knob was read, slips past
#      rule 3 and is what this catches.
#
# Each rule first refuses a planted race: a car given more grip than the
# others; a car that turns past its grip; a driver whose grip margin grows
# with its distance behind the leader; and one that reads its margin
# honestly and scales the speed it chose by that distance.
#
#     ./scripts/godot --headless --path godot -s res://test/demo_racing/racing_does_not_cheat.gd
#
# Exit codes: 0 nobody cheated; 1 somebody did, or a planted cheat went unseen.
extends SceneTree

const LAPS: int = 2
const SEED: int = 23
## Seconds the recorded race may last; two laps take under eighty.
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


## A car that forgets the grip: it turns as tight as its turn rate allows,
## at any speed.
class GriplessCar extends RacingCar:
	## Only the turn rate, never the grip.
	func turn_limit() -> float:
		return physics.turn_rate


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
	var findings: Array[String] = _physics_findings(race)
	race.step()
	var first_used: Array[Dictionary] = []
	for driver: RacingDriver in race.drivers:
		first_used.append(driver.used.duplicate())
	while true:
		for number: int in range(race.cars.size()):
			findings.append_array(_frame_findings(race, number, first_used[number]))
		if _all_finished(race) or race.time >= TIME_LIMIT:
			break
		race.step()
	for number: int in range(race.cars.size()):
		findings.append_array(_level_findings(race.drivers[number], first_used[number]))
	return findings


# Rule 1: one resource, and the same fields on every car.
func _physics_findings(race: RacingRace) -> Array[String]:
	var findings: Array[String] = []
	for number: int in range(race.cars.size()):
		var physics: RacingPhysics = race.cars[number].physics
		if physics != race.physics:
			findings.append("car %d does not drive the race's physics" % number)
		findings.append_array(_field_findings(number, physics, race.cars[0].physics))
	return findings


# Every field car `number`'s physics declares in its script -- the car's
# limits -- that differs from car 0's.
func _field_findings(number: int, physics: RacingPhysics, reference: RacingPhysics) -> Array[String]:
	var findings: Array[String] = []
	for property: Dictionary in physics.get_property_list():
		var field: String = property["name"]
		if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE != 0 and physics.get(field) != reference.get(field):
			findings.append("car %d's %s is %s, car 0's is %s" % [number, field, physics.get(field), reference.get(field)])
	return findings


# Rules 2 and 3 on one car, on the frame just stepped.
func _frame_findings(race: RacingRace, number: int, first_used: Dictionary) -> Array[String]:
	var findings: Array[String] = []
	var car: RacingCar = race.cars[number]
	var where: String = "car %d, frame %d" % [number, race.steps]
	if car.speed > car.physics.top_speed + TOLERANCE:
		findings.append("%s: speed %.3f over the top speed" % [where, car.speed])
	if car.sideways_acceleration() > car.physics.grip + TOLERANCE:
		findings.append("%s: turned at %.3f sideways, over the grip" % [where, car.sideways_acceleration()])
	if race.drivers[number].used != first_used:
		findings.append("%s: used %s, but %s on its first frame" % [where, race.drivers[number].used, first_used])
	return findings + _decision_findings(race, number, where)


# Rule 4 on one car: the decision, recomputed from the level's own knobs.
func _decision_findings(race: RacingRace, number: int, where: String) -> Array[String]:
	var findings: Array[String] = []
	var driver: RacingDriver = race.drivers[number]
	var honest: float = RacingDriver.speed_limit(race.track, driver.decided_at, race.physics, driver.level.grip_margin)
	if absf(driver.target_speed - honest) > TOLERANCE:
		findings.append("%s: chose %.3f m/s, its level's margin gives %.3f" % [where, driver.target_speed, honest])
	var off: float = driver.aim.distance_to(race.track.point_ahead(driver.decided_at, driver.level.lookahead, 0.0))
	if off > driver.level.wander + TOLERANCE:
		findings.append("%s: aimed %.2f m from its level's lookahead point, wander allows %.2f" % [
			where, off, driver.level.wander])
	return findings


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


# The four planted races. Each must be refused, and by the rule it breaks:
# the finding has to name that rule, not merely exist. The gripless car is
# driven by a level that dares half as much again as its grip, so that it
# asks for turns no honest car could take.
func _planted() -> Array[String]:
	var failures: Array[String] = []
	var levels: Array[RacingLevel] = RacingLevel.ladder()
	var stronger := RacingRace.new(RacingPhysics.new())
	stronger.enter(RacingDriver.new(levels[2], SEED))
	stronger.enter(RacingDriver.new(levels[2], SEED))
	stronger.cars[1].physics = stronger.physics.duplicate()
	stronger.cars[1].physics.grip *= 1.2
	failures.append_array(_refused("a car given more grip", stronger, "grip is"))
	var gripless := RacingRace.new(RacingPhysics.new())
	gripless.enter(RacingDriver.new(RacingLevel.new("reckless", 8.0, 1.5, 0.0), SEED))
	gripless.cars[0] = GriplessCar.new(gripless.physics, gripless.cars[0].position, gripless.cars[0].heading)
	failures.append_array(_refused("a car that turns past its grip", gripless, "over the grip"))
	var banded := RacingRace.new(RacingPhysics.new())
	banded.enter(RacingDriver.new(levels[2], SEED))
	banded.enter(RubberBandDriver.new(levels[0], SEED, banded, true))
	failures.append_array(_refused("a rubber band in the knob", banded, "on its first frame"))
	var at_use := RacingRace.new(RacingPhysics.new())
	at_use.enter(RacingDriver.new(levels[2], SEED))
	at_use.enter(RubberBandDriver.new(levels[0], SEED, at_use, false))
	failures.append_array(_refused("a rubber band where the knob is used", at_use, "level's margin gives"))
	return failures


# "" in the list when `race` is refused with a finding containing `because`.
func _refused(what: String, race: RacingRace, because: String) -> Array[String]:
	for finding: String in cheat_findings(race):
		if because in finding:
			return []
	return ["planted, %s: not refused" % what]
