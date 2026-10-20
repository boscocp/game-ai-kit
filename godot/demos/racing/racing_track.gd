## The track: a closed loop of points, a racing line through it, and the
## fastest a car may be going at every point of that line.
##
## The track is data, as Game AI Pro's racing chapters have it: nodes along
## the centre, a width, and the racing line stored as a sideways offset at
## each node. Both are smoothed into a curve and cut into samples `SPACING`
## metres apart. Building it is linear in the number of samples; asking where
## a car is on it looks only near where it was, so it is constant time a step.
##
## The speed limit is the part a driver reasons with. Where the line bends,
## grip caps the speed: on a curve of curvature k a car holding `a` metres a
## second squared sideways goes at most sqrt(a / k). Before each bend the
## car must already have braked down to that, so the limit is carried
## backwards from the tightest corner -- the bottleneck -- at the rate the
## brakes allow. That pass is in `_braking_limits`.
##
## When not to use it: a track whose racing line must change with traffic.
## This line is fixed, and overtaking needs a line that moves.
class_name RacingTrack
extends RefCounted

## Metres between two samples of the line.
const SPACING: float = 2.0
## How far either side of the last known sample a car is looked for. A car
## covers at most one metre a frame, so sixty metres is never too few.
const SEARCH: int = 30

## The centre of the track, in metres, in driving order. The loop closes from
## the last node back to the first.
const NODES: Array[Vector2] = [
	Vector2(60, 290), Vector2(200, 295), Vector2(330, 292), Vector2(405, 275),
	Vector2(440, 225), Vector2(432, 160), Vector2(390, 122), Vector2(335, 118),
	Vector2(300, 150), Vector2(262, 178), Vector2(220, 160), Vector2(205, 110),
	Vector2(225, 62), Vector2(195, 28), Vector2(130, 30), Vector2(85, 62),
	Vector2(52, 120), Vector2(36, 200), Vector2(42, 255),
]
## The racing line at each node, as a fraction of the half width: 1 is the
## left edge, -1 the right, 0 the centre. Outside, inside at the apex, outside
## again. Placed by a small search over lap time made once while this file
## was written, as Game AI Pro improves a designer's line offline. The search
## is not part of the kit and cannot be rerun from it; the line is these
## numbers, and you can edit them.
const OFFSETS: Array[float] = [
	-0.1, -0.8, -0.7, 0.8, 0.8, 0.8, 0.8, 0.8, -0.5, -0.8,
	-0.8, -0.8, 0.8, 0.8, 0.5, 0.1, 0.1, 0.0, -0.8,
]
## Half the track's width, in metres: the grass starts this far from centre.
const HALF_WIDTH: float = 8.0
## Points of the smooth curve between two nodes, before it is resampled.
const CURVE_STEPS: int = 40
## Samples each side used to measure the bend at a sample: a few, so the
## measure is of the curve and not of the rounding between two samples.
const BEND_REACH: int = 3

## The racing line, `SPACING` metres apart, in driving order.
var line := PackedVector2Array()
## The track's centre, sampled the same way, for "is the car on the track".
var centre := PackedVector2Array()
## How sharply the line bends at each sample, in 1 / metres (signed).
var curvature := PackedFloat64Array()
## The fastest a car may be at each sample if it dares use all its grip and
## all its brakes, before the top speed is applied. A driver who dares only a
## fraction m of both goes sqrt(m) times this: every speed in the formula
## above is the square root of an acceleration.
var full_grip_limit := PackedFloat64Array()
## The line's length, in metres.
var length: float = 0.0


func _init(physics: RacingPhysics) -> void:
	centre = _resample(_smooth(NODES))
	line = _resample(_smooth(_racing_line_nodes()))
	length = line.size() * SPACING
	curvature = _curvatures(line)
	full_grip_limit = _braking_limits(_corner_limits(physics.grip), physics.braking)


## The sample of the line nearest `position`, looked for near `hint`.
func nearest(position: Vector2, hint: int) -> int:
	return _nearest_in(line, position, hint)


## The sample of the centre nearest `position`, looked for near `hint`.
func nearest_centre(position: Vector2, hint: int) -> int:
	return _nearest_in(centre, position, hint)


## True when `position` is on the tarmac: within the half width of the centre
## sample nearest it.
func on_track(position: Vector2, centre_hint: int) -> bool:
	return position.distance_to(centre[nearest_centre(position, centre_hint)]) <= HALF_WIDTH


## `index` brought back onto the loop: one past the last sample is the first.
func wrapped(index: int) -> int:
	return posmod(index, line.size())


## The point `distance` metres down the line from sample `index`, pushed
## `sideways` metres to its left. That is where a driver looking that far
## ahead steers.
func point_ahead(index: int, distance: float, sideways: float) -> Vector2:
	var ahead: int = wrapped(index + roundi(distance / SPACING))
	return line[ahead] + _left_at(ahead) * sideways


## The direction the line runs at sample `index`.
func direction_at(index: int) -> Vector2:
	return line[index].direction_to(line[wrapped(index + 1)])


# The racing line's nodes: each centre node pushed sideways by its offset.
func _racing_line_nodes() -> Array[Vector2]:
	var placed: Array[Vector2] = []
	for index: int in range(NODES.size()):
		var before: Vector2 = NODES[posmod(index - 1, NODES.size())]
		var after: Vector2 = NODES[(index + 1) % NODES.size()]
		var left: Vector2 = before.direction_to(after).rotated(-PI / 2.0)
		placed.append(NODES[index] + left * OFFSETS[index] * HALF_WIDTH)
	return placed


# A closed Catmull-Rom curve through `points`: it passes through each one and
# turns smoothly between them.
func _smooth(points: Array[Vector2]) -> PackedVector2Array:
	var curve := PackedVector2Array()
	var count: int = points.size()
	for index: int in range(count):
		var before: Vector2 = points[posmod(index - 1, count)]
		var after: Vector2 = points[(index + 1) % count]
		var beyond: Vector2 = points[(index + 2) % count]
		for step: int in range(CURVE_STEPS):
			var weight: float = float(step) / CURVE_STEPS
			curve.append(points[index].cubic_interpolate(after, before, beyond, weight))
	return curve


# The closed curve cut into pieces exactly as long as each other, about
# `SPACING` metres: the same distance between every two samples is what lets
# a lookahead in metres be a count of samples.
func _resample(curve: PackedVector2Array) -> PackedVector2Array:
	var total: float = 0.0
	for index: int in range(curve.size()):
		total += curve[index].distance_to(curve[(index + 1) % curve.size()])
	var count: int = roundi(total / SPACING)
	var samples := PackedVector2Array()
	var walked: float = 0.0
	var segment: int = 0
	for sample: int in range(count):
		var wanted: float = sample * total / count
		var piece: float = curve[segment].distance_to(curve[(segment + 1) % curve.size()])
		while walked + piece < wanted:
			walked += piece
			segment += 1
			piece = curve[segment].distance_to(curve[(segment + 1) % curve.size()])
		samples.append(curve[segment].lerp(curve[(segment + 1) % curve.size()], (wanted - walked) / piece))
	return samples


# How sharply the line bends at each sample: one over the radius of the
# circle through it and the samples `BEND_REACH` either side. Positive bends
# left, negative right.
func _curvatures(points: PackedVector2Array) -> PackedFloat64Array:
	var bends := PackedFloat64Array()
	for index: int in range(points.size()):
		var before: Vector2 = points[wrapped(index - BEND_REACH)]
		var here: Vector2 = points[index]
		var after: Vector2 = points[wrapped(index + BEND_REACH)]
		var turned: float = (here - before).cross(after - here)
		var sides: float = before.distance_to(here) * here.distance_to(after) * before.distance_to(after)
		bends.append(-2.0 * turned / sides)
	return bends


# The fastest each sample can be taken on its own: sqrt(grip / curvature).
# A straight has no such limit; it is left as infinity and the top speed,
# applied by the driver, decides it.
func _corner_limits(grip: float) -> PackedFloat64Array:
	var limits := PackedFloat64Array()
	for bend: float in curvature:
		limits.append(sqrt(grip / absf(bend)) if bend != 0.0 else INF)
	return limits


# Each corner's limit carried backwards: a sample may be no faster than full
# braking can bring down to the next sample's limit in `SPACING` metres,
# v^2 = v_next^2 + 2 * braking * SPACING. Starting from the slowest sample,
# the bottleneck no other corner can lower, one lap backwards settles it.
func _braking_limits(limits: PackedFloat64Array, braking: float) -> PackedFloat64Array:
	var settled: PackedFloat64Array = limits.duplicate()
	var bottleneck: int = 0
	for index: int in range(limits.size()):
		if limits[index] < limits[bottleneck]:
			bottleneck = index
	for back: int in range(1, limits.size()):
		var index: int = wrapped(bottleneck - back)
		var next_limit: float = settled[wrapped(index + 1)]
		settled[index] = minf(settled[index], sqrt(next_limit * next_limit + 2.0 * braking * SPACING))
	return settled


# The sample of `points` nearest `position`, looked for within `SEARCH`
# samples of `hint`.
func _nearest_in(points: PackedVector2Array, position: Vector2, hint: int) -> int:
	var best: int = posmod(hint, points.size())
	var best_distance: float = INF
	for offset: int in range(-SEARCH, SEARCH + 1):
		var index: int = posmod(hint + offset, points.size())
		var distance: float = position.distance_squared_to(points[index])
		if distance < best_distance:
			best = index
			best_distance = distance
	return best


# The unit vector to the line's left at sample `index`.
func _left_at(index: int) -> Vector2:
	return direction_at(index).rotated(-PI / 2.0)
