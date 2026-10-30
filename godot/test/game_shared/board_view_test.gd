# The view is the one part of T2 whose real check is a person looking at it.
# These tests cover the half that is not a matter of taste: that the tile set
# gets built at all, that a cell's cost chooses the tile a reader expects, and
# T8's measured defects -- the board in a corner, the highlight that hid the
# terrain, the cost drawn nowhere.
#
# Without them the board could paint every cell as a wall and `make check`
# would stay green, because nothing else in this repository ever looks.
extends GdUnitTestSuite


func test_the_tile_set_has_one_tile_per_picture() -> void:
	var view: BoardView = _mounted_view()
	assert_object(view.tile_set).is_not_null()

	var source: TileSetAtlasSource = view.tile_set.get_source(BoardView.SOURCE_ID)
	assert_int(source.get_tiles_count()).is_equal(Art.TERRAIN.size())


# Each column of the atlas is its own picture. Stitching every tile from the
# same file, or the same column, would build a tile set of the right size that
# draws one kind of ground everywhere.
func test_every_tile_in_the_atlas_is_a_different_picture() -> void:
	var view: BoardView = _mounted_view()
	var atlas: Image = view.tile_set.get_source(BoardView.SOURCE_ID).texture.get_image()
	var seen: Dictionary = {}
	for index: int in range(Art.TERRAIN.size()):
		var region := Rect2i(index * BoardView.TILE_PIXELS, 0, BoardView.TILE_PIXELS, BoardView.TILE_PIXELS)
		seen[atlas.get_region(region).get_data()] = index
	assert_int(seen.size()).is_equal(Art.TERRAIN.size())


# A picture with see-through parts is laid over open ground: a tree on the
# board stands on grass, not on the window behind it.
func test_a_tile_with_see_through_parts_is_laid_over_open_ground() -> void:
	var trees: Image = BoardView.tile_image(BoardView.TREES)
	var corner: Color = trees.get_pixel(0, 0)
	assert_float(corner.a).is_equal(1.0)
	assert_that(corner).is_equal(BoardView.tile_image(BoardView.PLAIN).get_pixel(0, 0))


func test_the_cost_of_a_cell_chooses_its_tile() -> void:
	var view: BoardView = _mounted_view()

	assert_vector(view._tile_for(GakGridGraph.BLOCKED)).is_equal(BoardView.WALL)
	assert_vector(view._tile_for(GakGridGraph.DEFAULT_COST)).is_equal(BoardView.PLAIN)
	assert_vector(view._tile_for(BoardView.ROUGH_FROM_COST)).is_equal(BoardView.ROUGH)


func test_drawing_a_board_paints_every_cell_with_its_terrain() -> void:
	var view: BoardView = _mounted_view()
	var graph := GakGridGraph.new(3, 2)
	graph.block(Vector2i(1, 1))
	var reachable: Array[Vector2i] = [Vector2i(0, 0)]

	view.draw_board(graph, reachable)

	assert_int(view.get_used_cells().size()).is_equal(6)
	assert_vector(view.get_cell_atlas_coords(Vector2i(1, 1))).is_equal(BoardView.WALL)
	assert_vector(view.get_cell_atlas_coords(Vector2i(0, 0))).is_equal(BoardView.PLAIN)


func test_a_reachable_rough_cell_still_shows_that_it_is_rough() -> void:
	# T8: the reachable highlight used to *replace* the terrain tile, so the
	# moment a player most wanted to know what the ground cost was the moment
	# it was hidden. The highlight is an overlay now; the tile stays terrain.
	var view: BoardView = _mounted_view()
	var graph := GakGridGraph.new(2, 1)
	graph.set_cost(Vector2i(1, 0), 3)
	var reachable: Array[Vector2i] = [Vector2i(1, 0)]

	view.draw_board(graph, reachable)

	assert_vector(view.get_cell_atlas_coords(Vector2i(1, 0))).is_equal(BoardView.ROUGH)


func test_a_cell_dearer_than_a_step_says_what_it_costs() -> void:
	# "What it costs" is a third of what T2's manual check asks, and the cost
	# used to be drawn nowhere. Plain ground and walls stay unlabelled: a `1`
	# on every cell would be noise, and a wall has no price.
	var view: BoardView = _mounted_view()
	var graph := GakGridGraph.new(3, 1)
	graph.set_cost(Vector2i(1, 0), 3)
	graph.block(Vector2i(2, 0))

	view.draw_board(graph, [] as Array[Vector2i])

	# `marks()` is what `_draw_marks` draws, entry for entry.
	assert_dict(view.marks()["costs"]).is_equal({Vector2i(1, 0): "3"})


func test_the_reachable_cells_are_drawn_over_the_terrain() -> void:
	# The other half of the overlay: where the unit in hand may go. With the
	# highlight no longer a tile, this is the only place it is held.
	var view: BoardView = _mounted_view()
	var reachable: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]

	view.draw_board(GakGridGraph.new(3, 1), reachable)

	assert_array(view.marks()["reachable"]).contains_exactly(reachable)


func test_the_overlay_is_drawn_on_a_child_above_the_tiles() -> void:
	# Measured on 4.7.2: a TileMapLayer paints its tiles over its own `_draw`.
	# The first version of this overlay was drawn there -- correct, and
	# invisible. Moving it back would pass every test above, so this one
	# holds where it is drawn.
	var view: BoardView = _mounted_view()
	var marks: Node2D = view.get_node("Marks")

	assert_object(marks).is_not_null()
	assert_bool(marks.draw.is_connected(view._draw_marks)).is_true()
	assert_bool(view.has_method("_draw")).is_false()


func test_the_board_is_centred_in_the_window() -> void:
	# T8 measured a 384 px board pinned at (80, 80) in a 1280x720 window. The
	# window is the one the project asks for: headless, the real viewport is
	# 100x100, and a test against it would centre on nothing.
	var scene: PackedScene = load("res://game/main.tscn")
	var main: BoardGame = auto_free(scene.instantiate())
	add_child(main)
	var board: BoardView = main.get_node("BoardView")
	var window := Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))

	var drawn := Rect2(board.global_position, BoardView.pixel_size(main._state.graph))

	var off_centre: Vector2 = (drawn.get_center() - window / 2.0).abs()
	assert_float(off_centre.x).is_less_equal(BoardView.TILE_PIXELS)
	assert_float(off_centre.y).is_less_equal(BoardView.TILE_PIXELS)


func test_tiles_are_large_enough_to_read_a_number_on() -> void:
	# The tile set, not only the constant: a number has to fit on a real tile.
	var view: BoardView = _mounted_view()

	assert_int(view.tile_set.tile_size.x).is_greater_equal(48)
	assert_int(view.tile_set.tile_size.y).is_greater_equal(48)


func test_redrawing_forgets_the_previous_board() -> void:
	var view: BoardView = _mounted_view()
	view.draw_board(GakGridGraph.new(4, 4), [] as Array[Vector2i])
	assert_int(view.get_used_cells().size()).is_equal(16)

	# A smaller board must not leave the old one's cells painted behind it.
	view.draw_board(GakGridGraph.new(2, 2), [] as Array[Vector2i])
	assert_int(view.get_used_cells().size()).is_equal(4)


# A view in the tree, so the engine has called `_ready` and built the tile set.
func _mounted_view() -> BoardView:
	var view := BoardView.new()
	add_child(view)
	return auto_free(view)
