## A difficulty: T23's three knobs, and nothing else.
##
## The levels differ in how well the car is driven, never in the car. Each
## knob means what it means in T23 (`docs/concepts/racing-ai.md`):
##
##   * lookahead -- pure pursuit's one parameter: how far down the line the
##     driver aims, here in **seconds** of travel at the speed it is going,
##     not T23's metres: a 16-metre aim at 35 m/s weaved this car off the
##     road (measured, T54 step 3). Longer turns in earlier and smoother;
##   * grip margin -- the fraction of the grip and of the braking the driver
##     dares to use, Game AI Pro's skill. It moves the braking point;
##   * wander -- how far, in metres, the point it aims at drifts off the
##     line: Melder and Tomlinson's error offset.
##
## A fourth knob is written down and justified where it is added, as in
## T12. The values are fixed for the whole race, which is what
## `racing3d_does_not_cheat.gd` holds on the values each driver used.
class_name RaceLevel3D
extends RefCounted

var title: String
## Seconds of travel down the line the driver aims at.
var lookahead: float
## The fraction of its grip and braking the driver dares use, up to 1.
var grip_margin: float
## Metres the aimed-at point drifts sideways from the line, at most.
var wander: float


func _init(name_shown: String, aim_distance: float, margin: float, drift: float) -> void:
	title = name_shown
	lookahead = aim_distance
	grip_margin = margin
	wander = drift


## The three levels, easiest first, spread far enough apart that a person
## watching can tell them apart (Game AI Pro warns a narrow range does
## not). `racing3d_ladder.gd` says by how much in lap time.
##
## Measured alone (2026-10-21), three laps from a standing start on three
## seeds: on the loop easy 50.6 s, normal 48.4 s, hard 47.2 s a lap; on the
## kidney, which nothing was tuned on, 43.9, 41.9 and 40.4. The grip margin
## is what buys most of it, as in T23. Hard's 0.97 is Game AI Pro's top of
## range, of a grip the driver measured; the sheet's grip at the same
## margin puts it on the grass (`racing3d_effects.gd`).
static func ladder() -> Array[RaceLevel3D]:
	return [
		RaceLevel3D.new("easy", 0.5, 0.75, 2.0),
		RaceLevel3D.new("normal", 0.7, 0.86, 1.0),
		RaceLevel3D.new("hard", 0.9, 0.97, 0.3),
	]
