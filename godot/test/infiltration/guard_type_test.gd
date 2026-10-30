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


func test_the_rate_vector_holds_the_patrol_rows_controller() -> void:
	# The fuzzy vector pins the rate both languages compute; it is only
	# worth that while its controller is the one the patrol guard uses.
	var path: String = ProjectSettings.globalize_path("res://").path_join("../spec/vectors/fuzzy/a-guards-awareness-rate.json")
	var vector: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_bool(vector is Dictionary).is_true()
	assert_dict(vector["controller"]).is_equal(GuardType.read_file()["guards"]["patrol"]["rate"])


func test_every_guard_types_awareness_row_is_sound() -> void:
	var types: Dictionary[String, GuardType] = _types()
	for type_name: String in types:
		assert_str(Awareness.problem(types[type_name].awareness)).is_empty()


func test_a_floor_at_the_last_phase_or_phases_out_of_order_are_refused() -> void:
	var row: Dictionary = _types()["patrol"].awareness.duplicate(true)
	row["caution"]["floor"] = 1.0
	assert_str(Awareness.problem(row)).contains("once alert, always alert")
	row = _types()["patrol"].awareness.duplicate(true)
	row["phases"][2]["at"] = 0.1
	assert_str(Awareness.problem(row)).contains("does not rise")


func test_the_events_are_a_sound_table() -> void:
	assert_str(StimulusTable.problem(GuardType.read_file()["events"])).is_empty()


func test_a_clear_lit_body_close_by_raises_awareness_faster_than_a_faint_one_far_off() -> void:
	var patrol: GuardType = _types()["patrol"]
	assert_float(patrol.rate(1.0, 1.0, 1.0, 1.0)).is_greater(patrol.rate(0.1, 0.0, 0.0, 15.0))


func test_a_wall_between_is_silence_and_the_way_round_is_heard_less() -> void:
	var level := GakGridGraph.new(5, 3)
	for y: int in range(3):
		level.block(Vector2i(2, y))
	var walled: Dictionary[Vector2i, float] = SoundPaths.lengths(level, Vector2i(0, 1), 10.0, 1.0)
	assert_float(SoundPaths.loudness_at(walled, Vector2i(3, 1), 10.0, 1.0)).is_equal(0.0)
	level.set_cost(Vector2i(2, 0), GakGridGraph.DEFAULT_COST)
	var round_the_wall: Dictionary[Vector2i, float] = SoundPaths.lengths(level, Vector2i(0, 1), 10.0, 1.0)
	assert_float(SoundPaths.loudness_at(round_the_wall, Vector2i(3, 1), 10.0, 1.0)).is_equal_approx(0.5, 1e-9)


func test_only_a_minor_event_off_screen_and_far_is_halved() -> void:
	var hearing: Dictionary = _types()["patrol"].hearing
	assert_float(SoundPaths.listener_factor(hearing, 1, false, 20.0)).is_equal(0.5)
	assert_float(SoundPaths.listener_factor(hearing, 1, true, 20.0)).is_equal(1.0)
	assert_float(SoundPaths.listener_factor(hearing, 1, false, 3.0)).is_equal(1.0)
	assert_float(SoundPaths.listener_factor(hearing, 3, false, 20.0)).is_equal(1.0)


func _seen_at(place: Vector2) -> GuardPercept:
	var percept := GuardPercept.new()
	percept.sight.certainty = 0.9
	percept.seen_place = place
	percept.distance = 2.0
	percept.light = 1.0
	percept.motion = 1.0
	return percept


func test_a_mind_seeing_the_target_grows_aware_and_remembers_where() -> void:
	var mind := GuardMind.new(_types()["patrol"])
	for second: int in range(1, 4):
		mind.step(_seen_at(Vector2(4, 5)), float(second), 1.0)
	assert_str(mind.phase_name()).is_equal("alert")
	assert_vector(mind.memory.place).is_equal(Vector2(4, 5))
	assert_str(mind.memory.source).is_equal("sight")


func test_a_mind_that_perceives_nothing_learns_nothing() -> void:
	var mind := GuardMind.new(_types()["patrol"])
	mind.step(GuardPercept.new(), 1.0, 1.0)
	assert_bool(mind.memory.known).is_false()
	assert_str(mind.phase_name()).is_equal("unaware")


func test_a_heard_footstep_is_remembered_as_one() -> void:
	var mind := GuardMind.new(_types()["patrol"])
	var percept := GuardPercept.new()
	percept.loudness = 0.5
	percept.heard_place = Vector2(7, 1)
	percept.heard_kind = "footstep"
	mind.step(percept, 1.0, 1.0)
	assert_str(mind.memory.source).is_equal("footstep")
	assert_float(mind.awareness["sound"].value).is_equal_approx(0.3, 1e-9)


func test_a_stance_the_data_forgot_needs_every_point() -> void:
	var patrol: GuardType = _types()["patrol"]
	assert_int(patrol.needed_for("crouched")).is_equal(2)
	assert_int(patrol.needed_for("hanging")).is_equal(3)
