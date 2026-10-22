# The infiltration levels as data: the two hand-made ones read and are
# playable, and the generator makes playable ones from any seed.
extends GdUnitTestSuite


func _every_place_walkable(level: InfiltrationLevel) -> void:
	assert_bool(level.walkable(level.cell_of(level.start))).is_true()
	assert_bool(level.walkable(level.cell_of(level.exit_place))).is_true()
	for spec: Dictionary in level.guard_specs:
		assert_bool(level.walkable(level.cell_of(spec["post"]))).is_true()
		for point: Vector2 in spec["route"]:
			assert_bool(level.walkable(level.cell_of(point))).is_true()


func test_the_hand_made_levels_read_and_every_place_is_walkable() -> void:
	for path: String in InfiltrationLevel.HAND_MADE:
		var level: InfiltrationLevel = InfiltrationLevel.read(path)
		assert_int(level.guard_specs.size()).is_greater_equal(3)
		_every_place_walkable(level)


func test_lamps_light_the_aisles_and_leave_the_corners_dark() -> void:
	var level: InfiltrationLevel = InfiltrationLevel.read(InfiltrationLevel.WAREHOUSE)
	assert_float(level.light_at(Vector2(11.5, 6.5))).is_greater(0.8)
	assert_float(level.light_at(Vector2(34.5, 23.5))).is_less(0.2)


func test_a_hiding_place_covers_its_cells() -> void:
	var level: InfiltrationLevel = InfiltrationLevel.read(InfiltrationLevel.WAREHOUSE)
	assert_float(level.hidden_at(Vector2(3.5, 3.5))).is_equal(0.7)
	assert_float(level.hidden_at(Vector2(9.5, 3.5))).is_equal(0.0)


func test_the_generator_makes_a_playable_level_from_every_seed() -> void:
	for seed_value: int in range(1, 21):
		var data: Dictionary = LevelGenerator.make(seed_value)
		assert_bool(data.is_empty()).is_false()
		_every_place_walkable(InfiltrationLevel.read(data))


func test_the_same_seed_is_the_same_level() -> void:
	assert_dict(LevelGenerator.make(7)).is_equal(LevelGenerator.make(7))


func test_the_belief_graph_is_the_free_walk_cells() -> void:
	var level: InfiltrationLevel = InfiltrationLevel.read(InfiltrationLevel.COURTYARD)
	assert_int(level.neighbours.size()).is_equal(level.cells.size())
	assert_bool(level.walkable(Vector2i(10, 7))).is_false()
