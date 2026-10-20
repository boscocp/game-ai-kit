## The track as the drivers see it: grass, tarmac with kerbs, what stands
## beside it, and the racing line coloured by how fast one driver may be at
## each point of it.
##
## The colour is the speed limit that driver reasons with -- red where it
## must be slow, green where the top speed is the only limit -- so the
## braking zones are visible before any car reaches them, and change when
## another level is chosen. The grass, the trees, the stand and the tyres
## are Kenney's Racing Pack (CC0, `res://assets/LICENCES.md`); the tarmac and
## kerb colours are sampled from its road tiles. The line's two colours are
## dark, so they stand out on the light tarmac. Drawn in metres, once, and
## again only when the level changes; the cars are drawn above it by
## `RacingRaceView`.
class_name RacingTrackView
extends Node2D

const TARMAC := Color8(166, 201, 203)
const KERB_RED := Color8(232, 106, 23)
const KERB_WHITE := Color8(250, 250, 250)
const SLOW := Color(0.75, 0.05, 0.15)
const FAST := Color(0.0, 0.45, 0.2)
## Samples of kerb in one colour, and the kerb's width inside the tarmac.
const KERB_SAMPLES: int = 2
const KERB_WIDTH: float = 1.2
## The grass picture's 128 pixels cover this many metres.
const GRASS_METRES: float = 12.8
## How many trees are tried, from which seed, over how much ground.
const TREES: int = 70
const SCENERY_SEED: int = 59
## Grass reaches well past the track, so a camera close on a car at the edge
## never shows the void; trees are scattered only over the near part.
const BOUNDS := Rect2(-200, -200, 900, 750)
const TREE_BOUNDS := Rect2(-40, -40, 540, 400)

var race: RacingRace
## The level whose speed limit colours the line.
var level: RacingLevel
## A little under the slowest any corner allows, so even that one is not the
## reddest red.
var slowest: float = INF
## Each piece of scenery: [picture path, centre, metres across, angle].
var scenery: Array[Array] = []


func _init(shown_race: RacingRace, shown_level: RacingLevel) -> void:
	race = shown_race
	level = shown_level
	for limit: float in race.track.full_grip_limit:
		slowest = minf(slowest, limit * 0.8)
	scenery = _place_scenery()


## Colour the line for another level's driver.
func show_level(shown_level: RacingLevel) -> void:
	level = shown_level
	queue_redraw()


## The colour of `speed` on the line: red at the slowest the track asks of
## anyone, green at the top speed.
func speed_colour(speed: float) -> Color:
	return SLOW.lerp(FAST, clampf(inverse_lerp(slowest, race.physics.top_speed, speed), 0.0, 1.0))


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * GRASS_METRES / 128.0)
	var per_metre: float = 128.0 / GRASS_METRES
	draw_texture_rect(Art.texture(Art.RACING_GRASS), Rect2(BOUNDS.position * per_metre, BOUNDS.size * per_metre), true)
	draw_set_transform(Vector2.ZERO)
	_draw_tarmac(race.track)
	_draw_line_by_speed(race.track)
	_draw_start_line(race.track)
	for piece: Array in scenery:
		_draw_picture(piece[0], piece[1], piece[2], piece[3])


# The tarmac, one four-cornered piece between each two centre samples, with a kerb
# down each edge in the pack's orange and white.
func _draw_tarmac(track: RacingTrack) -> void:
	var count: int = track.centre.size()
	for index: int in range(count):
		var here: Vector2 = track.centre[index]
		var after: Vector2 = track.centre[(index + 1) % count]
		var left: Vector2 = _left(track, index)
		var next_left: Vector2 = _left(track, (index + 1) % count)
		_draw_piece(PackedVector2Array([here + left * RacingTrack.HALF_WIDTH,
			after + next_left * RacingTrack.HALF_WIDTH, after - next_left * RacingTrack.HALF_WIDTH,
			here - left * RacingTrack.HALF_WIDTH]), TARMAC)
		_draw_kerbs(here, after, left, next_left, KERB_RED if (index / KERB_SAMPLES) % 2 == 0 else KERB_WHITE)


# One piece of kerb down each edge, between two centre samples.
func _draw_kerbs(here: Vector2, after: Vector2, left: Vector2, next_left: Vector2, kerb: Color) -> void:
	for side: float in [1.0, -1.0]:
		var outer: float = RacingTrack.HALF_WIDTH * side
		var inner: float = (RacingTrack.HALF_WIDTH - KERB_WIDTH) * side
		_draw_piece(PackedVector2Array([here + left * outer, after + next_left * outer,
			after + next_left * inner, here + left * inner]), kerb)


# Four corners as two triangles. Not `draw_colored_polygon`: in the hairpin
# the bend's radius is barely more than the half width, the inner corners
# of a piece cross, and a polygon that crosses itself cannot be triangulated
# -- the engine refuses it. Two triangles are drawn whatever their shape.
func _draw_piece(corners: PackedVector2Array, colour: Color) -> void:
	draw_primitive(corners, PackedColorArray([colour, colour, colour, colour]), PackedVector2Array())


# The start and finish: a chequered band across the tarmac, so it is not
# taken for the AI's white braking bar.
func _draw_start_line(track: RacingTrack) -> void:
	var along: Vector2 = track.direction_at(0)
	var across: Vector2 = along.rotated(PI / 2.0)
	var square: float = 1.5
	var count: int = int(2.0 * RacingTrack.HALF_WIDTH / square)
	for cell: int in range(count * 2):
		var column: int = cell / 2
		var row: int = cell % 2
		var corner: Vector2 = track.centre[0] + across * (column * square - RacingTrack.HALF_WIDTH) + along * row * square
		var colour: Color = KERB_WHITE if (column + row) % 2 == 0 else Color.BLACK
		_draw_piece(PackedVector2Array([corner, corner + across * square, corner + (across + along) * square,
			corner + along * square]), colour)


# The racing line, each piece coloured by this level's limit there.
func _draw_line_by_speed(track: RacingTrack) -> void:
	for index: int in range(track.line.size()):
		var limit: float = RacingDriver.speed_limit(track, index, race.physics, level.grip_margin)
		draw_line(track.line[index], track.line[track.wrapped(index + 1)], speed_colour(limit), 1.2)


# Trees scattered on the grass, never closer to the tarmac than a tree's
# width; a stand beside the start straight, on its outside; tyres outside the slowest corner.
# Seeded, so the scenery is the same every time.
func _place_scenery() -> Array[Array]:
	var track: RacingTrack = race.track
	var placed: Array[Array] = []
	var outside: Vector2 = -_left(track, 0) * (RacingTrack.HALF_WIDTH + 12.0)
	placed.append([Art.RACING_SCENERY[3], track.centre[0] + outside, 26.0, track.direction_at(0).angle()])
	var bottleneck: int = _slowest_sample(track)
	var away: float = -signf(track.curvature[bottleneck])
	var near_centre: int = _nearest_centre(track, track.line[bottleneck])
	placed.append([Art.RACING_SCENERY[2], track.centre[near_centre] + _left(track, near_centre) * away
		* (RacingTrack.HALF_WIDTH + 4.0), 4.0, 0.0])
	var dice := RandomNumberGenerator.new()
	dice.seed = SCENERY_SEED
	for tree: int in range(TREES):
		var at := Vector2(dice.randf_range(TREE_BOUNDS.position.x, TREE_BOUNDS.end.x),
			dice.randf_range(TREE_BOUNDS.position.y, TREE_BOUNDS.end.y))
		var size: float = dice.randf_range(6.0, 11.0)
		if _distance_to_tarmac(track, at) > size:
			placed.append([Art.RACING_SCENERY[tree % 2], at, size, 0.0])
	return placed


func _draw_picture(path: String, centre: Vector2, metres: float, angle: float) -> void:
	var picture: Texture2D = Art.texture(path)
	var size: Vector2 = picture.get_size() * metres / maxf(picture.get_size().x, 1.0)
	draw_set_transform(centre, angle, Vector2.ONE)
	draw_texture_rect(picture, Rect2(-size / 2.0, size), false)
	draw_set_transform(Vector2.ZERO)


# How far `at` is from the edge of the tarmac; negative on it.
func _distance_to_tarmac(track: RacingTrack, at: Vector2) -> float:
	var nearest: float = INF
	for point: Vector2 in track.centre:
		nearest = minf(nearest, point.distance_to(at))
	return nearest - RacingTrack.HALF_WIDTH


# The centre sample nearest `at`, looked for all the way round: built once,
# so the cost of not knowing where to start does not matter.
func _nearest_centre(track: RacingTrack, at: Vector2) -> int:
	var best: int = 0
	for index: int in range(track.centre.size()):
		if track.centre[index].distance_squared_to(at) < track.centre[best].distance_squared_to(at):
			best = index
	return best


# The unit vector to the centre line's left at centre sample `index`.
func _left(track: RacingTrack, index: int) -> Vector2:
	var count: int = track.centre.size()
	return track.centre[index].direction_to(track.centre[(index + 1) % count]).rotated(-PI / 2.0)


func _slowest_sample(track: RacingTrack) -> int:
	var slowest_sample: int = 0
	for index: int in range(track.full_grip_limit.size()):
		if track.full_grip_limit[index] < track.full_grip_limit[slowest_sample]:
			slowest_sample = index
	return slowest_sample
