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

## The three switches' lines, on and then off.
const PID: Array[String] = ["1 PID: full", "1 PID: proportional only"]  # shown through tr()
const TRAFFIC: Array[String] = ["2 traffic: heat line", "2 traffic: one rival at a time"]  # shown through tr()
const GRIP: Array[String] = ["3 grip: measured", "3 grip: off the car's sheet"]  # shown through tr()


## The status panel for `race`, watching car `watched`; `human` is yours,
## and `switches` says [full PID, heat line, measured grip]. Rebuilt every
## frame, as it was before T80: each line is one lookup and one format.
static func status(race: Race3D, watched: int, human: RaceHumanDriver3D, switches: Array) -> String:
	var lines: PackedStringArray = []
	if not race.racing:
		lines.append(_measuring(race, watched))
	else:
		lines.append(_watched(race, watched, human))
		if race.drivers[watched] != human:
			lines.append(TranslationServer.translate("the keys drive your car, the red one: Tab until \"you\" to watch it"))
	lines.append("")
	lines.append(TranslationServer.translate(PID[0 if switches[0] else 1]))
	lines.append(TranslationServer.translate(TRAFFIC[0 if switches[1] else 1]))
	lines.append(TranslationServer.translate(GRIP[0 if switches[2] else 1]))
	lines.append("")
	for number: int in range(race.cars.size()):
		lines.append(_laps(race, number, human))
	return "\n".join(lines)


static func _measuring(race: Race3D, watched: int) -> String:
	var test: GripTest3D = race.tests[watched]
	var sheet: Dictionary = Race3D.sheet_of(race.physics)
	return "\n".join([
		TranslationServer.translate("Measuring each car on the test pad: the keys drive yours once"),
		TranslationServer.translate("every car is on the grid, in about twenty seconds."),
		TranslationServer.translate("cornering now {cornering} m/s^2, best {best} (sheet {sheet_grip})").format({
			cornering = "%.1f" % test.cornering, best = "%.2f" % test.grip, sheet_grip = "%.2f" % sheet["grip"]}),
		TranslationServer.translate("braking {braking} m/s^2 (sheet {sheet_braking})").format({
			braking = "%.2f" % test.braking, sheet_braking = "%.2f" % sheet["braking"]}),
	])


static func _watched(race: Race3D, watched: int, human: RaceHumanDriver3D) -> String:
	var driver: RaceDriver3D = race.drivers[watched]
	var speed: float = race.cars[watched].forward_speed()
	var braking: String = TranslationServer.translate("no braking in sight")
	if driver.braking_in >= 0.0:
		braking = TranslationServer.translate("brakes in {metres} m").format({metres = "%.0f" % driver.braking_in})
	var pid: PidController = driver.line_pid
	return "\n".join([
		TranslationServer.translate("{who}: {speed} km/h, wants {wanted}; {braking}").format({
			who = _who(race, watched, human), speed = "%.0f" % (speed * 3.6),
			wanted = "%.0f" % (driver.target_speed * 3.6), braking = braking}),
		TranslationServer.translate("off where it wants to be: {off} m").format({off = "%.2f" % driver.line_error}),
		TranslationServer.translate("PID: P {p}  I {i}  D {d} rad").format({p = "%.3f" % pid.proportional_term,
			i = "%.3f" % pid.integral_term, d = "%.3f" % pid.derivative_term}),
		TranslationServer.translate("heat ball {ball} m; races on grip {grip}, braking {braking}").format({
			ball = "%.2f" % driver.traffic.heat.ball, grip = "%.2f" % driver.grip, braking = "%.2f" % driver.braking}),
	])


# A finished lap's time is read as prose, so its decimal separator follows
# the language; the panel's other numbers are measurements and keep the point.
static func _laps(race: Race3D, number: int, human: RaceHumanDriver3D) -> String:
	var done: int = race.laps(number)
	var last: String = "-"
	if done > 0:
		last = TranslationServer.translate("{seconds} s").format({seconds = Language.decimal(race.lap_time(number, done - 1), 1)})
	return TranslationServer.translate("{who}: lap {lap}, last {last}").format({
		who = _who(race, number, human), lap = done + 1, last = last})


# Who drives car `number`, as the panel names it: you, or the AI's level.
static func _who(race: Race3D, number: int, human: RaceHumanDriver3D) -> String:
	var driver: RaceDriver3D = race.drivers[number]
	return TranslationServer.translate("you" if driver == human else driver.level.title)
