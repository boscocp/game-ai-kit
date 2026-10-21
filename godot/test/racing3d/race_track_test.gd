# The tracks, and the racing line each finds for itself. Nothing here drives:
# the line must be on the tarmac, gentler than the centre it came from, and
# found the same way on two tracks of different shapes.
extends GdUnitTestSuite

const TRACKS: Array[String] = [
	"res://game3d/racing/tracks/the_loop.json",
	"res://game3d/racing/tracks/the_kidney.json",
]


func test_every_track_loads_as_a_closed_loop_of_even_samples() -> void:
	for path: String in TRACKS:
		var track: RaceTrack3D = RaceTrack3D.from_file(path)
		assert_int(track.centre.size()).is_greater(250)
		for index: int in range(track.centre.size()):
			var gap: float = track.centre[index].distance_to(track.centre[track.wrapped(index + 1)])
			assert_float(gap).is_equal_approx(RaceTrack3D.SPACING, 0.2)


func test_the_racing_line_stays_on_the_tarmac_with_its_margin() -> void:
	for path: String in TRACKS:
		var track: RaceTrack3D = RaceTrack3D.from_file(path)
		var held: float = track.half_width - RaceTrack3D.EDGE_MARGIN
		for offset: float in track.offsets:
			assert_float(absf(offset)).is_less_equal(held + 1e-4)


## Measured (2026-10-21): the line's sum of squared bends is 0.92 of the
## centre's on the loop, whose corners leave little room for its width,
## and 0.73 on the kidney.
const LESS_BENT: float = 0.95


func test_the_racing_line_uses_the_width_and_bends_less_than_the_centre() -> void:
	for path: String in TRACKS:
		var track: RaceTrack3D = RaceTrack3D.from_file(path)
		var widest: float = 0.0
		for offset: float in track.offsets:
			widest = maxf(widest, absf(offset))
		# Outside, apex, outside: somewhere the line reaches its margin.
		assert_float(widest).is_greater(track.half_width - RaceTrack3D.EDGE_MARGIN - 0.5)
		assert_float(_bend_sum(track.line)).is_less(_bend_sum(track.centre) * LESS_BENT)


func test_a_planted_line_left_on_the_centre_fails_the_bend_check() -> void:
	# The check above must be able to fail: a band that never pulled leaves
	# the line on the centre, and it bends exactly as much.
	var track: RaceTrack3D = RaceTrack3D.from_file(TRACKS[0])
	var unpulled := PackedVector2Array(track.centre)
	assert_bool(_bend_sum(unpulled) < _bend_sum(track.centre) * LESS_BENT).is_false()


func test_a_car_is_found_where_it_is_and_measured_sideways() -> void:
	var track: RaceTrack3D = RaceTrack3D.from_file(TRACKS[1])
	var sample: int = 100
	var beside: Vector2 = track.centre[sample] + track.left[sample] * 2.5
	assert_int(track.nearest(beside, sample - 20)).is_equal(sample)
	assert_int(track.nearest_anywhere(beside)).is_equal(sample)
	assert_float(track.sideways(beside, sample)).is_equal_approx(2.5, 1e-3)


# The sum of the squared bends along a loop -- what the band makes least --
# each the curvature of the circle through a sample and the ones five
# samples either side.
func _bend_sum(points: PackedVector2Array) -> float:
	var total: float = 0.0
	var count: int = points.size()
	for index: int in range(count):
		var before: Vector2 = points[posmod(index - 5, count)]
		var here: Vector2 = points[index]
		var after: Vector2 = points[(index + 5) % count]
		var sides: float = before.distance_to(here) * here.distance_to(after) * before.distance_to(after)
		total += pow(2.0 * (here - before).cross(after - here) / sides, 2.0)
	return total
