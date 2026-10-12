# The view is the one part of T2 whose real check is a person looking at it.
# These tests cover the half that is not a matter of taste: that the tile set
# gets built at all, and that a cell's cost chooses the tile a reader expects.
#
# Without them the board could paint every cell as a wall and `make check`
# would stay green, because nothing else in this repository ever looks.
extends GdUnitTestSuite


func test_the_tile_set_has_one_tile_per_swatch() -> void:
	var view: BoardView = _mounted_view()
	assert_object(view.tile_set).is_not_null()

	var source: TileSetAtlasSource = view.tile_set.get_source(BoardView.SOURCE_ID)
	assert_int(source.get_tiles_count()).is_equal(BoardView.SWATCHES.size())


func test_the_cost_of_a_cell_chooses_its_tile() -> void:
	var view: BoardView = _mounted_view()

	assert_vector(view._tile_for(GridGraph.BLOCKED)).is_equal(BoardView.WALL)
	assert_vector(view._tile_for(GridGraph.DEFAULT_COST)).is_equal(BoardView.PLAIN)
	assert_vector(view._tile_for(BoardView.ROUGH_FROM_COST)).is_equal(BoardView.ROUGH)


func test_drawing_a_board_paints_every_cell_and_marks_the_reachable() -> void:
	var view: BoardView = _mounted_view()
	var graph := GridGraph.new(3, 2)
	graph.block(Vector2i(1, 1))
	var reachable: Array[Vector2i] = [Vector2i(0, 0)]

	view.draw_board(graph, reachable)

	assert_int(view.get_used_cells().size()).is_equal(6)
	assert_vector(view.get_cell_atlas_coords(Vector2i(1, 1))).is_equal(BoardView.WALL)
	assert_vector(view.get_cell_atlas_coords(Vector2i(0, 0))).is_equal(BoardView.REACHABLE)


func test_redrawing_forgets_the_previous_board() -> void:
	var view: BoardView = _mounted_view()
	view.draw_board(GridGraph.new(4, 4), [] as Array[Vector2i])
	assert_int(view.get_used_cells().size()).is_equal(16)

	# A smaller board must not leave the old one's cells painted behind it.
	view.draw_board(GridGraph.new(2, 2), [] as Array[Vector2i])
	assert_int(view.get_used_cells().size()).is_equal(4)


# A view in the tree, so the engine has called `_ready` and built the tile set.
func _mounted_view() -> BoardView:
	var view := BoardView.new()
	add_child(view)
	return auto_free(view)
