## What the racing demo says beside the race, in words a player reads.
##
## Kept apart from the demo so the sentences can be read in one place: what
## the keys do, where each car is, and -- the point of the example -- what
## the AI is doing and why a harder AI is faster. Each function reads the
## race and returns text; nothing here changes it.
class_name RacingDemoText
extends RefCounted


## The panel while you, car `you`, race the AI, car `ai`: the keys, both
## cars, and what the AI decides.
static func racing(race: RacingRace, you: int, ai: int, laps: int, paused: bool) -> String:
	var level: RacingLevel = race.drivers[ai].level
	var lines: Array[String] = [
		"YOU AGAINST THE %s AI, %d laps%s" % [level.title.to_upper(), laps, "  (paused)" if paused else ""],
		"arrows or WASD drive  ·  1-3 the AI's level",
		"R again  ·  P pause  ·  Tab watch the three AIs",
		"",
		"you: %s" % _car_line(race, you, laps),
		"AI:  %s" % _car_line(race, ai, laps),
		"",
		"What the AI does, every frame:",
		"· steers at the white dot, %.0f m down the line" % level.lookahead,
		"· keeps to the speed the line allows: red, slow",
		"· must be braking by the white bar (yours: yellow)",
		"· dares %.0f%% of the tyres' grip" % (level.grip_margin * 100.0),
		"· steps aside to pass a slower car",
		"",
		"Harder AIs dare more grip: they brake later. Same car as yours; it starts on the inside.",
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
	lines.append("Same car, three drivers, easy starting in front: the harder ones pass it. Their bar sits closer to each corner, their line greener.")
	return "\n".join(lines)


## Under your car: how fast you are going, which pedal is down, and whether
## you are on the grass -- the feedback the keys alone do not give.
static func speedo(race: RacingRace, you: int) -> String:
	var driver: RacingHumanDriver = race.drivers[you]
	var pedal: String = "BRAKE" if driver.brake else ("throttle" if driver.throttle else "coasting")
	var grass: String = "   ON THE GRASS" if not race.on_track(you) else ""
	return "%d km/h   %s%s" % [roundi(race.cars[you].speed * 3.6), pedal, grass]


## Who won and by how much, once someone has finished `laps`; "" before.
static func result(race: RacingRace, you: int, ai: int, laps: int) -> String:
	var you_done: bool = race.laps(you) >= laps
	var ai_done: bool = race.laps(ai) >= laps
	if not you_done and not ai_done:
		return ""
	var you_time: float = race.lap_ends[you][laps - 1] if you_done else INF
	var ai_time: float = race.lap_ends[ai][laps - 1] if ai_done else INF
	var winner: String = "You win" if you_time < ai_time else "The %s AI wins" % race.drivers[ai].level.title
	if you_done and ai_done:
		return "%s by %.1f s  ·  R to race again" % [winner, absf(you_time - ai_time)]
	return winner


## Car `number`'s place: 1 for the leader. Who has finished `laps` comes
## first, in the order they finished; then whoever is further round; a tie
## goes to the lower number, so two cars never share a place.
static func place(race: RacingRace, number: int, laps: int) -> int:
	var ahead: int = 0
	for other: int in range(race.cars.size()):
		if other != number and _is_ahead(race, other, number, laps):
			ahead += 1
	return ahead + 1


static func _is_ahead(race: RacingRace, other: int, number: int, laps: int) -> bool:
	var other_end: float = race.lap_ends[other][laps - 1] if laps > 0 and race.laps(other) >= laps else INF
	var number_end: float = race.lap_ends[number][laps - 1] if laps > 0 and race.laps(number) >= laps else INF
	if other_end != number_end:
		return other_end < number_end
	if race.covered[other] != race.covered[number]:
		return race.covered[other] > race.covered[number]
	return other < number


# One car: its lap, its speed, and for a race of `laps`, its place.
static func _car_line(race: RacingRace, number: int, laps: int) -> String:
	var kmh: float = race.cars[number].speed * 3.6
	if laps <= 0:
		return "lap %d, %.0f km/h" % [race.laps(number) + 1, kmh]
	var ordinal: Array[String] = ["1st", "2nd", "3rd", "4th"]
	return "lap %d/%d, %.0f km/h, %s" % [mini(race.laps(number) + 1, laps), laps, kmh,
		ordinal[place(race, number, laps) - 1]]
