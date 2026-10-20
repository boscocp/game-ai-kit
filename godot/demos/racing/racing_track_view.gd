## The track as the drivers see it: tarmac, grass, and the racing line
## coloured by how fast one level's driver may be at each point of it.
##
## The colour is the speed limit the driver reasons with -- red where it
## must be slow, green where the car's top speed is the only limit -- so
## the braking zones are visible before any car reaches them, and change
## when another level is chosen. Drawn once, and again only when the level
## changes; the cars and their decisions are drawn above it, by the demo.
class_name RacingTrackView
extends Node2D

const GRASS := Color(0.16, 0.27, 0.16)
const TARMAC := Color(0.27, 0.27, 0.29)
const KERB := Color(0.85, 0.85, 0.85)
const SLOW := Color(0.95, 0.25, 0.2)
const FAST := Color(0.3, 0.9, 0.35)

var race: RacingRace
## The level whose speed limit colours the line.
var level: RacingLevel
## A little under the slowest any corner allows, so even that one is not
## the reddest red.
var slowest: float = INF


func _init(shown_race: RacingRace, shown_level: RacingLevel) -> void:
	race = shown_race
	level = shown_level
	for limit: float in race.track.full_grip_limit:
		slowest = minf(slowest, limit * 0.8)


## Colour the line for another level's driver.
func show_level(shown_level: RacingLevel) -> void:
	level = shown_level
	queue_redraw()


## The colour of `speed` on the line: red at the slowest the track asks of
## anyone, green at the top speed.
func speed_colour(speed: float) -> Color:
	return SLOW.lerp(FAST, clampf(inverse_lerp(slowest, race.physics.top_speed, speed), 0.0, 1.0))


func _draw() -> void:
	var track: RacingTrack = race.track
	draw_rect(Rect2(Vector2(-12, -28), Vector2(472, 360)), GRASS)
	var count: int = track.centre.size()
	for index: int in range(count):
		var here: Vector2 = track.centre[index]
		var after: Vector2 = track.centre[(index + 1) % count]
		var left: Vector2 = here.direction_to(after).rotated(-PI / 2.0) * RacingTrack.HALF_WIDTH
		var beyond: Vector2 = track.centre[(index + 2) % count]
		var next_left: Vector2 = after.direction_to(beyond).rotated(-PI / 2.0) * RacingTrack.HALF_WIDTH
		draw_colored_polygon(PackedVector2Array([here + left, after + next_left, after - next_left,
			here - left]), TARMAC)
	_draw_line_by_speed(track)
	var across: Vector2 = track.direction_at(0).rotated(PI / 2.0) * RacingTrack.HALF_WIDTH
	draw_line(track.centre[0] - across, track.centre[0] + across, KERB, 1.0)


# The racing line, each piece coloured by this level's limit there.
func _draw_line_by_speed(track: RacingTrack) -> void:
	for index: int in range(track.line.size()):
		var limit: float = RacingDriver.speed_limit(track, index, race.physics, level.grip_margin)
		draw_line(track.line[index], track.line[track.wrapped(index + 1)], speed_colour(limit), 1.6)

