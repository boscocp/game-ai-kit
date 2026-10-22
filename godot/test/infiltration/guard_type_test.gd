# The guard types read from guard_types.json, and the fuzzy rate each one
# raises its awareness by. The claims over many inputs and graphs are in
# awareness_properties.gd.
extends GdUnitTestSuite


func _types() -> Dictionary[String, GuardType]:
	return GuardType.all_in(GuardType.read_file())


func test_the_file_reads_and_every_type_has_a_sound_controller() -> void:
	var types: Dictionary[String, GuardType] = _types()
	assert_int(types.size()).is_greater_equal(2)
	for type_name: String in types:
		assert_str(types[type_name].rate_controller.problem()).is_empty()


func test_the_events_are_a_sound_table() -> void:
	assert_str(StimulusTable.problem(GuardType.read_file()["events"])).is_empty()


func test_a_clear_lit_body_close_by_raises_awareness_faster_than_a_faint_one_far_off() -> void:
	var patrol: GuardType = _types()["patrol"]
	assert_float(patrol.rate(1.0, 1.0, 1.0, 1.0)).is_greater(patrol.rate(0.1, 0.0, 0.0, 15.0))


func test_a_wall_between_is_silence_and_the_way_round_is_heard_less() -> void:
	var level := GridGraph.new(5, 3)
	for y: int in range(3):
		level.block(Vector2i(2, y))
	var walled: Dictionary[Vector2i, float] = SoundPaths.lengths(level, Vector2i(0, 1), 10.0, 1.0)
	assert_float(SoundPaths.loudness_at(walled, Vector2i(3, 1), 10.0, 1.0)).is_equal(0.0)
	level.set_cost(Vector2i(2, 0), GridGraph.DEFAULT_COST)
	var round_the_wall: Dictionary[Vector2i, float] = SoundPaths.lengths(level, Vector2i(0, 1), 10.0, 1.0)
	assert_float(SoundPaths.loudness_at(round_the_wall, Vector2i(3, 1), 10.0, 1.0)).is_equal_approx(0.5, 1e-9)


func test_only_a_minor_event_off_screen_and_far_is_halved() -> void:
	var hearing: Dictionary = _types()["patrol"].hearing
	assert_float(SoundPaths.listener_factor(hearing, 1, false, 20.0)).is_equal(0.5)
	assert_float(SoundPaths.listener_factor(hearing, 1, true, 20.0)).is_equal(1.0)
	assert_float(SoundPaths.listener_factor(hearing, 1, false, 3.0)).is_equal(1.0)
	assert_float(SoundPaths.listener_factor(hearing, 3, false, 20.0)).is_equal(1.0)


func test_a_stance_the_data_forgot_needs_every_point() -> void:
	var patrol: GuardType = _types()["patrol"]
	assert_int(patrol.needed_for("crouched")).is_equal(2)
	assert_int(patrol.needed_for("hanging")).is_equal(3)
