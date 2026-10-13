## How true is "near"? One term, as a trapezoid answering a degree in [0, 1].
##
## Four points: where the slope starts rising, where it reaches 1, where it
## starts falling, where it is 0 again. Three points make a triangle, a top one
## point wide; equal first two points make a shoulder. Constant time to ask.
##
## When not to use it: a discrete input. "Has a key" is not a matter of degree,
## and a fuzzy set over it is a boolean in disguise.
class_name FuzzySet
extends RefCounted

var name: String
var rise_start: float
var rise_end: float
var fall_start: float
var fall_end: float

# How many points the caller gave, kept so `problem` can name a wrong count
# after the triangle has been widened into a trapezoid.
var _given: int


## A set from three points (a triangle) or four (a trapezoid).
##
## A triangle's middle point is both the end of its rise and the start of its
## fall -- which is all a triangle is: a trapezoid with no top.
func _init(set_name: String, points: PackedFloat64Array) -> void:
	name = set_name
	_given = points.size()
	if _given == 3:
		points = PackedFloat64Array([points[0], points[1], points[1], points[2]])
	if points.size() != 4:
		points = PackedFloat64Array([NAN, NAN, NAN, NAN])
	rise_start = points[0]
	rise_end = points[1]
	fall_start = points[2]
	fall_end = points[3]


## Why this set describes no shape, or "" when it describes one.
##
## A falling edge before its rising edge would answer numbers outside [0, 1]
## rather than fail, which is why it is refused here and not discovered later.
func problem() -> String:
	if _given != 3 and _given != 4:
		return "F1 set %s needs three or four points, not %d" % [name, _given]
	var points: Array[float] = [rise_start, rise_end, fall_start, fall_end]
	for point: float in points:
		if is_nan(point) or is_inf(point):
			return "F1 set %s has a point that is not a number" % name
	var ordered: Array[float] = points.duplicate()
	ordered.sort()
	if ordered != points:
		return "F1 set %s has points out of order: %s" % [name, points]
	return ""


## How far `value` belongs to this set, from 0 (not at all) to 1.
##
## The flat top is tested before either slope, and that order is what lets a
## vertical edge -- a shoulder, `rise_start == rise_end` -- answer 1 at its
## corner instead of dividing by zero.
func degree(value: float) -> float:
	if value < rise_start or value > fall_end:
		return 0.0
	if rise_end <= value and value <= fall_start:
		return 1.0
	if value < rise_end:
		return (value - rise_start) / (rise_end - rise_start)
	return (fall_end - value) / (fall_end - fall_start)
