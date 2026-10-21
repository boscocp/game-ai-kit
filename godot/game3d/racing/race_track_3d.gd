## A track: its centre, its width, and a racing line found from its shape.
##
## The track is data, as Game AI Pro's racing chapters have it: a closed
## loop of nodes along the centre and a half width, read from a JSON file in
## `tracks/`. The nodes are smoothed into a curve (Catmull-Rom, through every
## node) and cut into samples `SPACING` metres apart. Positions are on the
## map, `Vector2(x, z)` of the 3D world: the road is flat at y = 0.
##
## The racing line is not written down per track, as T23's offsets were. It
## is **found**, the same way on every track, by an elastic band: each
## sample is moved sideways to where the bend there would be the mean of
## its neighbours' -- the point that makes the sum of squared bends least
## with the others held -- and kept on the tarmac, less a margin. Done at a
## long reach first and shorter after, it settles on the outside, apex,
## outside line a driver would draw. It is an approximation of the
## minimum-curvature line, not a lap-time optimum; T53 leaves the optimiser
## for a lesson of its own. Measured: it bends 0.92 as much as the centre on
## the loop, whose corners leave little room, and 0.73 on the kidney.
## Linear in the samples per pass; built once when the track is loaded.
##
## When not to use it: a track that crosses itself, or one whose racing line
## must change with traffic. The heat line in `RaceDriver3D` moves off this
## line; the line itself stays put.
class_name RaceTrack3D
extends RefCounted

## Metres between two samples of the centre.
const SPACING: float = 3.0
## Points of the smooth curve between two nodes, before it is resampled.
const CURVE_STEPS: int = 40
## Metres of tarmac the racing line keeps from either edge: half a car and
## a little more.
const EDGE_MARGIN: float = 2.0
## The elastic band's reaches, in samples, longest first, and how many
## passes it makes at each.
const BAND_REACHES: Array[int] = [24, 12, 6, 3]
const BAND_PASSES: int = 60
## How far either side of the last known sample a car is looked for. A car
## covers under a metre a frame, so ninety metres is never too few.
const SEARCH: int = 30

var title: String = ""
## The grass starts this far from the centre, in metres.
var half_width: float = 0.0
## The centre, `SPACING` metres apart, in driving order; and the unit vector
## to the left of the way it runs, at each sample.
var centre := PackedVector2Array()
var left := PackedVector2Array()
## The racing line, as how far left of the centre it runs at each sample
## (negative: right), and as points.
var offsets := PackedFloat64Array()
var line := PackedVector2Array()
## The centre's length, in metres: one lap.
var length: float = 0.0


## The track in the JSON file at `path`: `{"title", "half_width", "nodes":
## [[x, z], ...]}`. An unreadable file leaves an empty track and says so.
static func from_file(path: String) -> RaceTrack3D:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var track := RaceTrack3D.new()
	if not (data is Dictionary):
		push_error("RaceTrack3D: cannot read %s" % path)
		return track
	var nodes: Array[Vector2] = []
	for pair: Array in data["nodes"]:
		nodes.append(Vector2(float(pair[0]), float(pair[1])))
	track.build(str(data["title"]), float(data["half_width"]), nodes)
	return track


## Lay the track out from its centre nodes and half width, and find its line.
func build(name_shown: String, width: float, nodes: Array[Vector2]) -> void:
	title = name_shown
	half_width = width
	centre = _resample(_smooth(nodes))
	length = centre.size() * SPACING
	left = PackedVector2Array()
	for index: int in range(centre.size()):
		left.append(left_of(centre[index].direction_to(centre[wrapped(index + 1)])))
	offsets = _elastic_band()
	line = PackedVector2Array()
	for index: int in range(centre.size()):
		line.append(centre[index] + left[index] * offsets[index])


## The unit vector to the left of `direction` on the map, seen from above:
## up crossed with the direction, in (x, z).
static func left_of(direction: Vector2) -> Vector2:
	return Vector2(direction.y, -direction.x)


## `index` brought back onto the loop: one past the last sample is the first.
func wrapped(index: int) -> int:
	return posmod(index, centre.size())


## The sample nearest `position` on the map, looked for near `hint`.
func nearest(position: Vector2, hint: int) -> int:
	var best: int = wrapped(hint)
	var best_distance: float = INF
	for step: int in range(-SEARCH, SEARCH + 1):
		var index: int = wrapped(hint + step)
		var distance: float = position.distance_squared_to(centre[index])
		if distance < best_distance:
			best = index
			best_distance = distance
	return best


## The sample nearest `position` over the whole loop: where a car is when
## nothing is known yet about where it was.
func nearest_anywhere(position: Vector2) -> int:
	var best: int = 0
	for index: int in range(centre.size()):
		if position.distance_squared_to(centre[index]) < position.distance_squared_to(centre[best]):
			best = index
	return best


## How far left of the centre at sample `index` the point `position` is.
func sideways(position: Vector2, index: int) -> float:
	return (position - centre[index]).dot(left[index])


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
			curve.append(points[index].cubic_interpolate(after, before, beyond, float(step) / CURVE_STEPS))
	return curve


# The closed curve cut into pieces exactly as long as each other, about
# `SPACING` metres, so a distance along the track is a count of samples.
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


# The racing line's offsets: every sample moved, over and over, at each
# reach in turn. In place, so a move is felt by the next sample at once.
func _elastic_band() -> PackedFloat64Array:
	var held: float = half_width - EDGE_MARGIN
	var pulled := PackedFloat64Array()
	pulled.resize(centre.size())
	pulled.fill(0.0)
	for reach: int in BAND_REACHES:
		for _pass: int in range(BAND_PASSES):
			_pull_once(pulled, reach, held)
	return pulled


# One pass of the band at `reach`, every sample in driving order. Each goes
# where its bend would be the mean of its neighbours' -- the point where the
# sum of squared bends is least, with the others held -- and is clamped on.
func _pull_once(pulled: PackedFloat64Array, reach: int, held: float) -> void:
	for index: int in range(centre.size()):
		var near: Vector2 = _band_point(pulled, index - reach) + _band_point(pulled, index + reach)
		var far: Vector2 = _band_point(pulled, index - 2 * reach) + _band_point(pulled, index + 2 * reach)
		pulled[index] = clampf(sideways((4.0 * near - far) / 6.0, index), -held, held)


func _band_point(pulled: PackedFloat64Array, index: int) -> Vector2:
	var at: int = wrapped(index)
	return centre[at] + left[at] * pulled[at]
