## What the racing demo says beside the race, in words a player reads.
##
## Kept apart from the demo so the sentences can be read in one place: what
## the keys do, where each car is, and -- the point of the example -- what
## the AI is doing and why a harder AI is faster. Each function reads the
## race and returns text; nothing here changes it.
class_name RacingDemoText
extends RefCounted

## The end of a race, you first and then the AI: once one has finished, and
## once both have, with the margin.
const WINS: Array[String] = ["You win", "The {level} AI wins"]  # shown through tr()
const WINS_BY: Array[String] = [  # shown through tr()
	"You win by {seconds} s  ·  R to race again",
	"The {level} AI wins by {seconds} s  ·  R to race again",
]


## The panel while you, car `you`, race the AI, car `ai`: the keys, both
## cars, and what the AI decides.
static func racing(race: RacingRace, you: int, ai: int, laps: int, paused: bool) -> String:
	var level: RacingLevel = race.drivers[ai].level
	var heading: String = TranslationServer.translate("YOU AGAINST THE {level} AI, {laps} laps").format({
		level = TranslationServer.translate(level.title).to_upper(), laps = laps})
	var lines: Array[String] = [
		heading + (TranslationServer.translate("  (paused)") if paused else ""),
		TranslationServer.translate("arrows or WASD drive  ·  1-3 the AI's level"),
		TranslationServer.translate("R again  ·  P pause  ·  Tab watch the three AIs"),
		"",
		TranslationServer.translate("you: {car}").format({car = _car_line(race, you, laps)}),
		TranslationServer.translate("AI:  {car}").format({car = _car_line(race, ai, laps)}),
		"",
		TranslationServer.translate("What the AI does, every frame:"),
		TranslationServer.translate("· steers at the white dot, {metres} m down the line").format({
			metres = "%.0f" % level.lookahead}),
		TranslationServer.translate("· keeps to the speed the line allows: red, slow"),
		TranslationServer.translate("· must be braking by the white bar (yours: yellow)"),
		TranslationServer.translate("· dares {percent}% of the tyres' grip").format({
			percent = "%.0f" % (level.grip_margin * 100.0)}),
		TranslationServer.translate("· steps aside to pass a slower car"),
		"",
		TranslationServer.translate("Harder AIs dare more grip: they brake later."),
		TranslationServer.translate("Same car as yours; it starts on the inside."),
	]
	return "\n".join(lines)


## The panel while watching T23's three levels, `followed` drawn deciding.
static func watching(race: RacingRace, followed: int, paused: bool) -> String:
	var lines: Array[String] = [
		TranslationServer.translate("WATCHING THE THREE AIs")
			+ (TranslationServer.translate("  (paused)") if paused else ""),
		TranslationServer.translate("1-3 follow one  ·  A alone  ·  R again  ·  Tab race them"),
		"",
	]
	for number: int in range(race.cars.size()):
		var driver: RacingDriver = race.drivers[number]
		lines.append("%s%s: %s" % ["> " if number == followed else "",
			TranslationServer.translate(driver.level.title), _car_line(race, number, 0)])
	lines.append("")
	lines.append(TranslationServer.translate("Same car, three drivers, easy starting in front: the harder ones pass it."))
	lines.append(TranslationServer.translate("Their bar sits closer to each corner, their line greener."))
	return "\n".join(lines)


## Under your car: how fast you are going, which pedal is down, and whether
## you are on the grass -- the feedback the keys alone do not give. Rebuilt
## every frame: two lookups and one format.
static func speedo(race: RacingRace, you: int) -> String:
	var driver: RacingHumanDriver = race.drivers[you]
	var pedal: String = "BRAKE" if driver.brake else ("throttle" if driver.throttle else "coasting")  # shown through tr()
	var line: String = "{speed} km/h   {pedal}" if race.on_track(you) else "{speed} km/h   {pedal}   ON THE GRASS"  # shown through tr()
	return TranslationServer.translate(line).format({speed = roundi(race.cars[you].speed * 3.6),
		pedal = TranslationServer.translate(pedal)})


## Who won and by how much, once someone has finished `laps`; "" before.
## The margin is read as prose, so its decimal separator follows the language.
static func result(race: RacingRace, you: int, ai: int, laps: int) -> String:
	var you_done: bool = race.laps(you) >= laps
	var ai_done: bool = race.laps(ai) >= laps
	if not you_done and not ai_done:
		return ""
	var you_time: float = race.lap_ends[you][laps - 1] if you_done else INF
	var ai_time: float = race.lap_ends[ai][laps - 1] if ai_done else INF
	var words: Dictionary = {level = TranslationServer.translate(race.drivers[ai].level.title),
		seconds = Language.decimal(absf(you_time - ai_time), 1)}
	var sentence: String = WINS[0 if you_time < ai_time else 1]
	if you_done and ai_done:
		sentence = WINS_BY[0 if you_time < ai_time else 1]
	return TranslationServer.translate(sentence).format(words)


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
		return TranslationServer.translate("lap {lap}, {speed} km/h").format({
			lap = race.laps(number) + 1, speed = "%.0f" % kmh})
	var ordinal: Array[String] = ["1st", "2nd", "3rd", "4th"]  # shown through tr()
	return TranslationServer.translate("lap {lap}/{laps}, {speed} km/h, {place}").format({
		lap = mini(race.laps(number) + 1, laps), laps = laps, speed = "%.0f" % kmh,
		place = TranslationServer.translate(ordinal[place(race, number, laps) - 1])})
