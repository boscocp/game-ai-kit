## What a driver perceives on one physics frame, and nothing else.
##
## ADR 0018's rule for every 3D decision: it runs on a plain snapshot, never
## on the physics server. This is that snapshot for a driver. Every number
## is in the car's own frame -- metres forward and metres to the left of
## where it points -- so a decision made from it holds no track coordinate
## and cannot tell one track from another: placed on a new track, the driver
## sees a new road ahead and nothing more. `RaceSenses3D` fills it in from
## the world; a test or a conformance vector can write one by hand.
##
## The racing line ahead is what a driver who has walked the track would
## carry in its head: one point every few metres, up to `HORIZON` of them,
## with the tarmac left either side of each. The rivals are the cars it can
## see, each as how far ahead along the track it is, how far left of the
## racing line, and how fast.
class_name RaceView3D
extends RefCounted

## Points of the racing line a driver sees ahead: 180 metres, longer than
## any braking distance from the top speed.
const HORIZON: int = 60

## Seconds since the race began, and the seconds this decision lasts.
var time: float = 0.0
var step: float = 1.0 / 60.0
## Metres a second along the way the car points.
var speed: float = 0.0
## How far left of the racing line the car is, in metres (negative: right).
var cross_track: float = 0.0
## The racing line ahead, point by point, from the one nearest the car:
## metres forward of the car and metres to its left.
var line_forward := PackedFloat64Array()
var line_left := PackedFloat64Array()
## Metres of tarmac to the left and to the right of each of those points.
var room_left := PackedFloat64Array()
var room_right := PackedFloat64Array()
## Each rival seen: [metres ahead along the track (negative: behind),
## metres left of the racing line, metres a second].
var rivals: Array[PackedFloat64Array] = []


## The view as plain JSON-ready values, for a conformance vector.
func to_dictionary() -> Dictionary:
	var seen: Array = []
	for rival: PackedFloat64Array in rivals:
		seen.append(Array(rival))
	return {
		"time": time, "step": step, "speed": speed, "cross_track": cross_track,
		"line_forward": Array(line_forward), "line_left": Array(line_left),
		"room_left": Array(room_left), "room_right": Array(room_right), "rivals": seen,
	}


## A view from `to_dictionary`'s shape, as a vector writes one.
static func from_dictionary(values: Dictionary) -> RaceView3D:
	var view := RaceView3D.new()
	view.time = float(values["time"])
	view.step = float(values["step"])
	view.speed = float(values["speed"])
	view.cross_track = float(values["cross_track"])
	view.line_forward = PackedFloat64Array(values["line_forward"])
	view.line_left = PackedFloat64Array(values["line_left"])
	view.room_left = PackedFloat64Array(values["room_left"])
	view.room_right = PackedFloat64Array(values["room_right"])
	for rival: Array in values["rivals"]:
		view.rivals.append(PackedFloat64Array(rival))
	return view
