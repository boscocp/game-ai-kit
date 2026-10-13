# ai_perception, one claim per test. The four properties that hold over every
# map are in perception_properties.gd; these are the edges of each part.
extends GdUnitTestSuite


func _open(size: int = 9) -> GridGraph:
	return GridGraph.new(size, size)


func test_an_open_board_hides_nothing() -> void:
	assert_bool(LineOfSight.clear(_open(), Vector2i(0, 0), Vector2i(8, 5))).is_true()


func test_a_wall_on_the_line_blocks_sight() -> void:
	var graph: GridGraph = _open()
	graph.block(Vector2i(2, 0))
	assert_bool(LineOfSight.clear(graph, Vector2i(0, 0), Vector2i(4, 0))).is_false()


func test_a_tree_blocks_sight_and_rough_ground_does_not() -> void:
	var graph: GridGraph = _open()
	graph.set_cost(Vector2i(2, 0), LineOfSight.DEFAULT_OPAQUE_FROM_COST)
	graph.set_cost(Vector2i(2, 1), LineOfSight.DEFAULT_OPAQUE_FROM_COST - 1)
	assert_bool(LineOfSight.clear(graph, Vector2i(0, 0), Vector2i(4, 0))).is_false()
	assert_bool(LineOfSight.clear(graph, Vector2i(0, 1), Vector2i(4, 1))).is_true()


func test_the_end_cells_are_not_asked() -> void:
	# A player standing in a tree is still seen: the tree hides what is behind it.
	var graph: GridGraph = _open()
	graph.set_cost(Vector2i(4, 0), LineOfSight.DEFAULT_OPAQUE_FROM_COST)
	assert_bool(LineOfSight.clear(graph, Vector2i(0, 0), Vector2i(4, 0))).is_true()


func test_neighbours_have_nothing_between_them() -> void:
	assert_array(LineOfSight.cells_between(Vector2i(3, 3), Vector2i(4, 3))).is_empty()
	assert_array(LineOfSight.cells_between(Vector2i(3, 3), Vector2i(3, 3))).is_empty()


func test_a_line_is_the_same_cells_from_either_end() -> void:
	var forwards: Array[Vector2i] = LineOfSight.cells_between(Vector2i(0, 0), Vector2i(5, 2))
	var backwards: Array[Vector2i] = LineOfSight.cells_between(Vector2i(5, 2), Vector2i(0, 0))
	assert_array(forwards).is_equal(backwards)
	assert_array(forwards).has_size(4)


func test_a_shallow_line_passes_through_the_cells_on_the_segment() -> void:
	var expected: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 2)]
	assert_array(LineOfSight.cells_between(Vector2i(0, 0), Vector2i(5, 2))).is_equal(expected)


func test_a_steep_line_passes_through_the_cells_on_the_segment() -> void:
	var expected: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(1, 3), Vector2i(2, 4)]
	assert_array(LineOfSight.cells_between(Vector2i(0, 0), Vector2i(2, 5))).is_equal(expected)


func test_a_line_upwards_passes_through_the_cells_on_the_segment() -> void:
	var expected: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, -1), Vector2i(3, -1), Vector2i(4, -2)]
	assert_array(LineOfSight.cells_between(Vector2i(0, 0), Vector2i(5, -2))).is_equal(expected)


func test_sight_does_not_slip_between_two_walls_meeting_at_a_corner() -> void:
	var graph: GridGraph = _open()
	graph.block(Vector2i(1, 0))
	graph.block(Vector2i(0, 1))
	assert_bool(LineOfSight.clear(graph, Vector2i(0, 0), Vector2i(1, 1))).is_false()
	assert_bool(LineOfSight.clear(graph, Vector2i(1, 1), Vector2i(0, 0))).is_false()
	assert_bool(LineOfSight.clear(graph, Vector2i(0, 0), Vector2i(3, 3))).is_false()


func test_one_wall_at_a_corner_does_not_block_a_diagonal() -> void:
	var graph: GridGraph = _open()
	graph.block(Vector2i(1, 0))
	assert_bool(LineOfSight.clear(graph, Vector2i(0, 0), Vector2i(1, 1))).is_true()


func test_a_cell_exactly_on_the_cone_s_edge_is_seen() -> void:
	# The diagonal measures 45.00000125 degrees; an exact comparison missed it.
	var cone := VisionCone.new(5.0, 45.0)
	assert_bool(cone.sees(_open(), Vector2i(4, 4), Vector2i.RIGHT, Vector2i(5, 5))).is_true()
	assert_bool(VisionCone.new(5.0, 90.0).sees(_open(), Vector2i(4, 4), Vector2i.RIGHT, Vector2i(4, 2))).is_true()


func test_a_target_off_the_board_is_never_seen() -> void:
	assert_bool(VisionCone.new(5.0, 90.0).sees(_open(), Vector2i(6, 4), Vector2i.RIGHT, Vector2i(9, 4))).is_false()


func test_a_watcher_with_no_reach_sees_only_its_own_cell() -> void:
	var cone := VisionCone.new(0.0, 45.0)
	assert_array(cone.visible_cells(_open(), Vector2i(4, 4), Vector2i.RIGHT)).is_equal([Vector2i(4, 4)] as Array[Vector2i])
	assert_float(cone.closeness(Vector2i(4, 4), Vector2i(4, 4))).is_equal(1.0)
	assert_float(cone.closeness(Vector2i(4, 4), Vector2i(5, 4))).is_equal(0.0)


func test_nan_raises_nothing() -> void:
	var map := InfluenceMap.new(2, 2)
	map.raise_to(Vector2i(0, 0), NAN)
	assert_float(map.value_at(Vector2i(0, 0))).is_equal(0.0)


func test_watchers_without_a_facing_each_are_refused_as_a_whole() -> void:
	var map := InfluenceMap.of_watchers(_open(), VisionCone.new(3.0, 45.0),
			[Vector2i(2, 2), Vector2i(6, 6)] as Array[Vector2i], [Vector2i.RIGHT] as Array[Vector2i])
	assert_float(map.strongest()).is_equal(0.0)


func test_a_watcher_sees_its_own_cell() -> void:
	var cone := VisionCone.new(3.0, 10.0)
	assert_bool(cone.sees(_open(), Vector2i(4, 4), Vector2i.RIGHT, Vector2i(4, 4))).is_true()


func test_out_of_reach_is_not_seen() -> void:
	var cone := VisionCone.new(3.0, 90.0)
	assert_bool(cone.sees(_open(), Vector2i(0, 0), Vector2i.RIGHT, Vector2i(3, 0))).is_true()
	assert_bool(cone.sees(_open(), Vector2i(0, 0), Vector2i.RIGHT, Vector2i(4, 0))).is_false()


func test_behind_the_cone_is_not_seen() -> void:
	var cone := VisionCone.new(5.0, 45.0)
	assert_bool(cone.sees(_open(), Vector2i(4, 4), Vector2i.RIGHT, Vector2i(6, 5))).is_true()
	assert_bool(cone.sees(_open(), Vector2i(4, 4), Vector2i.RIGHT, Vector2i(4, 6))).is_false()
	assert_bool(cone.sees(_open(), Vector2i(4, 4), Vector2i.RIGHT, Vector2i(2, 4))).is_false()


func test_facing_nowhere_sees_the_whole_circle() -> void:
	var cone := VisionCone.new(5.0, 10.0)
	assert_bool(cone.sees(_open(), Vector2i(4, 4), Vector2i.ZERO, Vector2i(2, 4))).is_true()


func test_a_cone_does_not_see_through_a_wall() -> void:
	var graph: GridGraph = _open()
	graph.block(Vector2i(5, 4))
	assert_bool(VisionCone.new(5.0, 45.0).sees(graph, Vector2i(4, 4), Vector2i.RIGHT, Vector2i(7, 4))).is_false()


func test_closeness_runs_from_one_at_the_eye_to_nought_at_reach() -> void:
	var cone := VisionCone.new(4.0, 45.0)
	assert_float(cone.closeness(Vector2i(0, 0), Vector2i(0, 0))).is_equal(1.0)
	assert_float(cone.closeness(Vector2i(0, 0), Vector2i(2, 0))).is_equal(0.5)
	assert_float(cone.closeness(Vector2i(0, 0), Vector2i(6, 0))).is_equal(0.0)


func test_visible_cells_hold_the_eye_and_nothing_behind_it() -> void:
	var cells: Array[Vector2i] = VisionCone.new(3.0, 45.0).visible_cells(_open(), Vector2i(4, 4), Vector2i.RIGHT)
	assert_array(cells).contains([Vector2i(4, 4), Vector2i(7, 4)])
	assert_array(cells).not_contains([Vector2i(3, 4), Vector2i(4, 7)])


func test_a_silent_action_is_heard_nowhere() -> void:
	assert_float(Hearing.loudness_at(Vector2i(0, 0), Vector2i(0, 0), 0.0)).is_equal(0.0)


func test_loudness_falls_from_the_source_to_the_radius() -> void:
	assert_float(Hearing.loudness_at(Vector2i(0, 0), Vector2i(0, 0), 4.0)).is_equal(1.0)
	assert_float(Hearing.loudness_at(Vector2i(2, 0), Vector2i(0, 0), 4.0)).is_equal(0.5)
	assert_float(Hearing.loudness_at(Vector2i(5, 0), Vector2i(0, 0), 4.0)).is_equal(0.0)


func test_a_wall_does_not_stop_a_sound() -> void:
	# Said in the header, and pinned so that changing it is a decision.
	assert_float(Hearing.loudness_at(Vector2i(2, 0), Vector2i(0, 0), 4.0)).is_greater(0.0)


func test_a_cell_keeps_the_strongest_value_it_was_raised_to() -> void:
	var map := InfluenceMap.new(4, 4)
	map.raise_to(Vector2i(1, 1), 0.7)
	map.raise_to(Vector2i(1, 1), 0.3)
	assert_float(map.value_at(Vector2i(1, 1))).is_equal(0.7)


func test_values_are_clamped_into_nought_and_one() -> void:
	var map := InfluenceMap.new(4, 4)
	map.raise_to(Vector2i(0, 0), 3.0)
	map.raise_to(Vector2i(1, 0), -1.0)
	assert_float(map.value_at(Vector2i(0, 0))).is_equal(1.0)
	assert_float(map.value_at(Vector2i(1, 0))).is_equal(0.0)


func test_off_the_board_is_nought_and_raising_it_does_nothing() -> void:
	var map := InfluenceMap.new(4, 4)
	map.raise_to(Vector2i(-1, 0), 1.0)
	assert_float(map.value_at(Vector2i(-1, 0))).is_equal(0.0)
	assert_float(map.strongest()).is_equal(0.0)


func test_a_route_fades_from_its_first_cell() -> void:
	var map := InfluenceMap.new(4, 1)
	map.raise_along([Vector2i(0, 0), Vector2i(1, 0)] as Array[Vector2i], 0.8)
	assert_float(map.value_at(Vector2i(0, 0))).is_equal(0.8)
	assert_float(map.value_at(Vector2i(1, 0))).is_equal(0.4)


func test_watchers_make_their_own_cells_the_most_dangerous() -> void:
	var cone := VisionCone.new(3.0, 45.0)
	var map := InfluenceMap.of_watchers(_open(), cone, [Vector2i(2, 2)] as Array[Vector2i],
			[Vector2i.RIGHT] as Array[Vector2i])
	assert_float(map.value_at(Vector2i(2, 2))).is_equal(1.0)
	assert_float(map.value_at(Vector2i(4, 2))).is_greater(0.0)
	assert_float(map.value_at(Vector2i(0, 2))).is_equal(0.0)
