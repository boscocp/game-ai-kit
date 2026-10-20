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
## Measured before they were chosen, on this track: the grip margin is what
## buys lap time. Lookahead from 8 to 16 metres moved the hard driver's lap
## by under a tenth of a second, and at 20 it cut the inside of corners onto
## the grass -- so lookahead is chosen for what it shows, turning in earlier,
## and stops short of that. Wander past 1.5 metres puts the car on the grass.
static func ladder() -> Array[RacingLevel]:
	return [
		RacingLevel.new("easy", 8.0, 0.75, 2.0),
		RacingLevel.new("normal", 12.0, 0.87, 1.0),
		RacingLevel.new("hard", 16.0, 0.97, 0.3),
	]
