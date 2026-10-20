## A difficulty: exactly three knobs, and nothing else.
##
## The three levels differ in how well the car is driven, never in the car.
## Each knob has its source in `docs/concepts/racing-ai.md`:
##
##   * lookahead -- pure pursuit's one parameter: how far down the line the
##     driver aims. Longer turns in earlier and smoother; too short weaves;
##   * grip margin -- the fraction of the grip (and of the brakes) the driver
##     dares to use, Game AI Pro's skill. It is what moves the braking point:
##     a driver who dares more is faster through the corner and so can brake
##     later for it;
##   * wander -- how far, in metres, the point it aims at drifts off the line:
##     Melder and Tomlinson's error offset, the driver not quite on the line.
##
## A fourth knob is written down and justified where it is added, as in T12.
## The values are fixed for the whole race: nothing here may move with the
## race, which is what `racing_does_not_cheat.gd` holds.
class_name RacingLevel
extends RefCounted

var title: String
## Metres down the line the driver aims at.
var lookahead: float
## The fraction of its grip and brakes the driver dares use, up to 1.
var grip_margin: float
## Metres the aimed-at point drifts sideways from the line, at most.
var wander: float


func _init(name_shown: String, aim_distance: float, margin: float, drift: float) -> void:
	title = name_shown
	lookahead = aim_distance
	grip_margin = margin
	wander = drift


## The three levels, easiest first. Spread far enough apart that a person
## watching can tell them apart, which Game AI Pro warns a narrow range
## does not allow; `racing_ladder.gd` says by how much in lap time.
##
## Measured alone on this track (T59, 2026-10-20: 24 metres wide, 2.4 g of
## grip), five seeds and two laps each: easy 33.0 s, normal 31.7 s, hard
## 30.2 s a lap. The grip margin is what buys it -- normal's was lowered from
## T23's 0.87 to 0.84 when the kinder car brought it within 1.1 s of hard.
## Lookahead moves a lap by a few tenths at most, so it is chosen for what
## it shows, turning in earlier. Alone, no level leaves the tarmac and wander
## is only seen; in traffic a car passing near the edge of a corner can put
## its wheels on the grass, up to two seconds over three laps.
static func ladder() -> Array[RacingLevel]:
	return [
		RacingLevel.new("easy", 8.0, 0.75, 2.0),
		RacingLevel.new("normal", 12.0, 0.84, 1.0),
		RacingLevel.new("hard", 16.0, 0.97, 0.3),
	]
