## What the racing demo says beside the race, in words a player reads.
##
## Kept apart from the demo so the sentences can be read in one place: what
## the keys do, where each car is, and -- the point of the example -- what
## the AI is doing and why a harder AI is faster. Each function reads the
## race and returns text; nothing here changes it.
class_name RacingDemoText
extends RefCounted


## The panel while you race the AI at `level`: the keys, both cars, and
## what the AI decides.
static func racing(race: RacingRace, level: RacingLevel, laps: int, paused: bool) -> String:
	var lines: Array[String] = [
		"YOU AGAINST THE %s AI, %d laps%s" % [level.title.to_upper(), laps, "  (paused)" if paused else ""],
		"arrows or WASD drive  ·  1-3 the AI's level",
		"R again  ·  P pause  ·  Tab watch the three AIs",
		"",
		"you: %s" % _car_line(race, 0, laps),
		"AI:  %s" % _car_line(race, 1, laps),
		"",
		"What the AI does, every frame:",
		"· steers at the white dot, %.0f m down the line" % level.lookahead,
		"· keeps to the speed the line allows: red, slow",
		"· must be braking by the white bar",
		"· dares %.0f%% of the tyres' grip" % (level.grip_margin * 100.0),
		"",
		"Harder AIs dare more grip: they brake later. Same car as yours.",
	]
	return "\n".join(lines)


## The panel while watching T23's three levels, `followed` drawn deciding.
static func watching(race: RacingRace, followed: int, paused: bool) -> String:
	var lines: Array[String] = [
		"WATCHING THE THREE AIs%s" % ("  (paused)" if paused else ""),
		"1-3 follow one  ·  A alone  ·  R again  ·  Tab race them",
		"",
	]
	for number: int in range(race.cars.size()):
		var driver: RacingDriver = race.drivers[number]
		lines.append("%s%s: %s" % ["> " if number == followed else "", driver.level.title, _car_line(race, number, 0)])
	lines.append("")
	lines.append("Same car, three drivers: the harder one's bar sits closer to each corner, and its line stays greener.")
	return "\n".join(lines)


## Who won and by how much, once someone has finished `laps`; "" before.
static func result(race: RacingRace, ai_title: String, laps: int) -> String:
	var you_done: bool = race.laps(0) >= laps
	var ai_done: bool = race.laps(1) >= laps
	if not you_done and not ai_done:
		return ""
	var you_time: float = race.lap_ends[0][laps - 1] if you_done else INF
	var ai_time: float = race.lap_ends[1][laps - 1] if ai_done else INF
	var winner: String = "You win" if you_time < ai_time else "The %s AI wins" % ai_title
	if you_done and ai_done:
		return "%s by %.1f s\nR to race again" % [winner, absf(you_time - ai_time)]
	return winner


# One car: its lap, its speed, and for a race of `laps`, its place.
static func _car_line(race: RacingRace, number: int, laps: int) -> String:
	var lap: int = mini(race.laps(number) + 1, laps) if laps > 0 else race.laps(number) + 1
	var place: String = ""
	if laps > 0:
		var ahead: bool = race.covered[number] >= race.covered[1 - number]
		place = ", 1st" if ahead else ", 2nd"
	return "lap %d%s, %.0f km/h%s" % [lap, "/%d" % laps if laps > 0 else "", race.cars[number].speed * 3.6, place]
