## A difficulty: T23's three knobs, and nothing else.
##
## The levels differ in how well the car is driven, never in the car. Each
## knob means what it means in T23 (`docs/concepts/racing-ai.md`):
##
##   * lookahead -- pure pursuit's one parameter: how far down the line the
##     driver aims. Longer turns in earlier and smoother; too short weaves;
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
## Metres down the line the driver aims at.
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
