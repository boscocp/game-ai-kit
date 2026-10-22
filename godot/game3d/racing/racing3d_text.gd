## The words beside the 3D race: what the watched driver is deciding, the
## three switches, and every car's laps.
##
## Text, so a person can read the numbers the overlay draws: the speed the
## car does and the one it wants, where it must brake, how far it is from
## where it wants to be and the PID's three terms, where the heat line's
## ball is, and the grip and braking it races on against what its sheet
## says.
class_name Racing3DText
extends RefCounted


## The status panel for `race`, watching car `watched`; `human` is yours,
## and `switches` says [full PID, heat line, measured grip].
static func status(race: Race3D, watched: int, human: RaceHumanDriver3D, switches: Array) -> String:
	var lines: PackedStringArray = []
	if not race.racing:
		lines.append(_measuring(race, watched))
	else:
		lines.append(_watched(race, watched, human))
		if race.drivers[watched] != human:
			lines.append("the keys drive your car, the red one: Tab until \"you\" to watch it")
	lines.append("")
	lines.append("1 PID: %s" % ("full" if switches[0] else "proportional only"))
	lines.append("2 traffic: %s" % ("heat line" if switches[1] else "one rival at a time"))
	lines.append("3 grip: %s" % ("measured" if switches[2] else "off the car's sheet"))
	lines.append("")
	for number: int in range(race.cars.size()):
		lines.append(_laps(race, number, human))
	return "\n".join(lines)


static func _measuring(race: Race3D, watched: int) -> String:
	var test: GripTest3D = race.tests[watched]
	var sheet: Dictionary = Race3D.sheet_of(race.physics)
	return "Measuring each car on the test pad: the keys drive yours once\nevery car is on the grid, in about twenty seconds.\ncornering now %.1f m/s^2, best %.2f (sheet %.2f)\nbraking %.2f m/s^2 (sheet %.2f)" % [
		test.cornering, test.grip, sheet["grip"], test.braking, sheet["braking"]]


static func _watched(race: Race3D, watched: int, human: RaceHumanDriver3D) -> String:
	var driver: RaceDriver3D = race.drivers[watched]
	var speed: float = race.cars[watched].forward_speed()
	var who: String = "you" if driver == human else driver.level.title
	var braking: String = "brakes in %.0f m" % driver.braking_in if driver.braking_in >= 0.0 else "no braking in sight"
	var pid: PidController = driver.line_pid
	return "%s: %.0f km/h, wants %.0f; %s\noff where it wants to be: %.2f m\nPID: P %.3f  I %.3f  D %.3f rad\nheat ball %.2f m; races on grip %.2f, braking %.2f" % [
		who, speed * 3.6, driver.target_speed * 3.6, braking, driver.line_error,
		pid.proportional_term, pid.integral_term, pid.derivative_term,
		driver.traffic.heat.ball, driver.grip, driver.braking]


static func _laps(race: Race3D, number: int, human: RaceHumanDriver3D) -> String:
	var who: String = "you" if race.drivers[number] == human else race.drivers[number].level.title
	var done: int = race.laps(number)
	var last: String = "%.1f s" % race.lap_time(number, done - 1) if done > 0 else "-"
	return "%s: lap %d, last %s" % [who, done + 1, last]
