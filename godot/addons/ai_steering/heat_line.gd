## Melder's heat vision: where across the road to be, with every car in it
## weighed at once.
##
## One array of `CELLS` across the road's width, rebuilt every decision.
## Heat is added where a driver would rather not be: a little for every
## metre away from its line, a lot at the road's edges, and a hump wherever
## a car ahead is, hotter the nearer it is. A **ball** then rolls across the
## array, pushed downhill by the slope under it and slowed by drag: it keeps
## its momentum, so it does not flick from one gap to another, and where it
## rests is the coolest place it can reach -- the offset from the line the
## driver steers for. Overtaking two cars in one move, running alongside and
## settling back on the line all come out of that, which is the point of
## Melder's chapter ("The Heat Vision System for Racing AI", Game AI Pro,
## 2013): reacting to one car at a time pulls out, rejoins and pulls out
## again. Linear in the cells and the cars.
##
## Positions are metres to the left of the line (negative: right), between
## `-room_right` and `room_left`.
##
## When not to use it: a choice that is not a position across a strip --
## which of two routes, whether to pit. The ball only rolls sideways.
class_name HeatLine
extends RefCounted

const CELLS: int = 41

## How hot the road is for every metre away from the line, squared; how hot
## its edges are, and how far in from each edge that heat reaches.
var line_heat: float = 0.15
var edge_heat: float = 4.0
var edge_reach: float = 1.5
## How hard the slope pushes the ball, and how much of its speed drag takes
## each second.
var push: float = 6.0
var drag: float = 3.0

## The heat in each cell, and the cells' positions, from the last build.
var heat := PackedFloat64Array()
var positions := PackedFloat64Array()
## Where the ball is and how fast it moves, metres and metres a second.
var ball: float = 0.0
var ball_speed: float = 0.0


## Lay the array across a road `room_left` and `room_right` metres either
## side of the line, with the line's and the edges' heat in it.
func build(room_left: float, room_right: float) -> void:
	heat = PackedFloat64Array()
	positions = PackedFloat64Array()
	for cell: int in range(CELLS):
		var at: float = lerpf(-room_right, room_left, float(cell) / (CELLS - 1))
		positions.append(at)
		var from_edge: float = minf(room_left - at, at + room_right)
		var near_edge: float = edge_heat * maxf(0.0, 1.0 - from_edge / edge_reach)
		heat.append(line_heat * at * at + near_edge)


## Add a hump of `strength` centred `at` metres left of the line, falling
## off over `spread` metres: a car there.
func heat_up(at: float, strength: float, spread: float) -> void:
	for cell: int in range(positions.size()):
		var apart: float = (positions[cell] - at) / spread
		heat[cell] += strength * exp(-apart * apart)


## Roll the ball `step` seconds down the slope under it, kept on the road.
func roll(step: float) -> void:
	ball_speed += (-push * slope_at(ball) - drag * ball_speed) * step
	ball += ball_speed * step
	var lowest: float = positions[0]
	var highest: float = positions[positions.size() - 1]
	if ball < lowest or ball > highest:
		ball = clampf(ball, lowest, highest)
		ball_speed = 0.0


## The heat's slope at `at`, per metre, positive when it rises to the
## left: measured across one cell centred on `at`, so a ball resting
## between two equal sides feels no push either way.
func slope_at(at: float) -> float:
	var last: int = positions.size() - 1
	var cell: float = (positions[last] - positions[0]) / last
	if cell <= 0.0:
		return 0.0
	return (heat_at(at + cell / 2.0) - heat_at(at - cell / 2.0)) / cell


## The heat at `at`, read between the two cells either side of it, and the
## edge cell's beyond the ends.
func heat_at(at: float) -> float:
	var last: int = positions.size() - 1
	var width: float = positions[last] - positions[0]
	var place: float = clampf((at - positions[0]) / width * last, 0.0, float(last))
	var below: int = mini(floori(place), last - 1)
	return lerpf(heat[below], heat[below + 1], place - below)
