# T41: "the green start dot is hard to see on the grass". It was: the dot was
# (0.45, 0.85, 0.45) and grass averages (0.43, 0.72, 0.21) -- nearer to each
# other than to anything else on the board.
#
# A command cannot look at the screen (`--headless` rasterises nothing), but
# it can measure what a person would be comparing: a marker's colour against
# the average colour of each tile it can sit on. That is a floor, not taste --
# it says nothing about whether a marker is pretty, only that it is not the
# ground's own colour. Seeing it stays under T41's manual check.
extends GdUnitTestSuite

## How far apart, in RGB, a marker and its tile must be. The old green start
## on grass measured 0.28; the pink frontier on mud, T8's fix, about 0.66.
const ENOUGH: float = 0.5

const OLD_GREEN_START: Color = Color(0.45, 0.85, 0.45)


func test_the_rule_rejects_the_start_dot_the_owner_could_not_see() -> void:
	assert_bool(_stands_out(OLD_GREEN_START, BoardView.PLAIN)).is_false()


func test_the_search_demo_s_start_and_goal_stand_out_on_grass_and_mud() -> void:
	for marker: Color in [ExpansionView.START, ExpansionView.GOAL, ExpansionView.MARKER_RING]:
		for tile: Vector2i in [BoardView.PLAIN, BoardView.ROUGH]:
			_assert_stands_out(marker, tile)


func test_the_stealth_exit_stands_out_on_the_floor() -> void:
	_assert_stands_out(StealthView.EXIT, BoardView.PLAIN)


func _assert_stands_out(marker: Color, tile: Vector2i) -> void:
	assert_bool(_stands_out(marker, tile)).override_failure_message(
		"%s on tile %s: %.2f" % [marker, tile, _distance(marker, tile)]).is_true()


func _stands_out(marker: Color, tile: Vector2i) -> bool:
	return _distance(marker, tile) >= ENOUGH


# The marker as drawn over the tile -- a translucent one is partly the tile --
# against the tile's average, as a distance in RGB.
func _distance(marker: Color, tile: Vector2i) -> float:
	var ground: Color = _average(BoardView.tile_image(tile))
	var drawn: Color = ground.lerp(Color(marker, 1.0), marker.a)
	return Vector3(drawn.r - ground.r, drawn.g - ground.g, drawn.b - ground.b).length()


func _average(image: Image) -> Color:
	var total := Vector3.ZERO
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var pixel: Color = image.get_pixel(x, y)
			total += Vector3(pixel.r, pixel.g, pixel.b)
	total /= float(image.get_width() * image.get_height())
	return Color(total.x, total.y, total.z)
