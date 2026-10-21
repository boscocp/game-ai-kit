## Where across the road to be, with other cars on it: the heat line, or
## one rival at a time.
##
## With `heat_vision` on, every car alongside, or ahead within `REACH` and
## no faster, is a hump of heat
## on `ai_steering`'s `HeatLine`, hotter the nearer it is, and the ball's
## resting place is the offset the driver steers for (Melder's heat vision,
## T53). With it off, the driver reacts to the nearest car about that
## blocks its line, and only to that one: it picks the side with more room
## once, holds a car's width and a gap off it, and comes back to the line
## when that car is behind -- the "pull out, rejoin, pull out again" the
## chapter was written to replace. Both move the offset at most
## `SIDE_SPEED` metres a second, which is how fast a car moves across the
## road without a lurch. Linear in the cars it sees.
##
## When not to use it: defending a position, or choosing the moment. Neither
## mode blocks or waits; they only find room.
class_name RaceTraffic3D
extends RefCounted

## Metres ahead a car is weighed from, and the heat of one at the bumper.
## A car alongside -- up to `BESIDE` metres behind -- is `ALONGSIDE` times
## hotter still: it is the one already in the way, and two cars that only
## leaned away from each other measured rubbing doors for seconds.
const REACH: float = 60.0
const BESIDE: float = 6.0
const RIVAL_HEAT: float = 3.0
const ALONGSIDE: float = 3.0
## The heat's spread across the road, and the gap the one-rival rule keeps
## beside the car it passes, in metres.
const SPREAD: float = 2.6
const PASS_GAP: float = 1.2
const SIDE_SPEED: float = 4.0

var heat_vision: bool = true
var heat := HeatLine.new()
## The offset from the line the driver is asked for, in metres (positive:
## left), and the side of a pass under way without the heat line (1 left,
## -1 right, 0 none).
var offset: float = 0.0
var passing_side: int = 0


## The offset to steer for this decision, `step` seconds long, on a road
## `room_left` and `room_right` metres either side of the line, seen from a
## car going `speed` among `rivals` ([ahead, left of the line, speed]).
func plan(rivals: Array[PackedFloat64Array], room_left: float, room_right: float, speed: float, step: float) -> float:
	var wanted: float = 0.0
	if heat_vision:
		wanted = _heat_vision(rivals, room_left, room_right, speed, step)
	else:
		wanted = _one_rival(rivals, room_left, room_right)
	offset = move_toward(offset, wanted, SIDE_SPEED * step)
	return offset


# Every car ahead heats the road, and the ball rolls.
func _heat_vision(rivals: Array[PackedFloat64Array], room_left: float, room_right: float, speed: float, step: float) -> float:
	heat.build(room_left, room_right)
	for rival: PackedFloat64Array in rivals:
		var alongside: bool = rival[0] > -BESIDE and rival[0] <= 0.0
		var closing: bool = rival[0] > 0.0 and rival[0] < REACH and rival[2] < speed + 1.0
		if alongside:
			heat.heat_up(rival[1], RIVAL_HEAT * ALONGSIDE, SPREAD)
		elif closing:
			heat.heat_up(rival[1], RIVAL_HEAT * (1.0 - rival[0] / REACH), SPREAD)
	heat.roll(step)
	return heat.ball


# The nearest car ahead on the line, passed on the roomier side; none, the
# line itself.
func _one_rival(rivals: Array[PackedFloat64Array], room_left: float, room_right: float) -> float:
	var nearest: int = -1
	for index: int in range(rivals.size()):
		var rival: PackedFloat64Array = rivals[index]
		var blocking: bool = absf(rival[1]) < SPREAD + PASS_GAP
		var near: bool = rival[0] > -BESIDE and rival[0] < REACH
		if near and blocking and (nearest < 0 or absf(rival[0]) < absf(rivals[nearest][0])):
			nearest = index
	if nearest < 0:
		passing_side = 0
		return 0.0
	var rival_left: float = rivals[nearest][1]
	if passing_side == 0:
		passing_side = 1 if room_left - rival_left >= rival_left + room_right else -1
	return clampf(rival_left + passing_side * (SPREAD + PASS_GAP), -room_right, room_left)
