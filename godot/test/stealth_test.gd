# The stealth scenario: suspicion, the guards' three states, the rules of a
# turn, and the demo -- that it loads and writes out what each guard thinks.
# Whether that reads as a decision is the manual check, and a person's.
extends GdUnitTestSuite


func _open_room(guard_round: Array = [Vector2i(5, 1), Vector2i(8, 1)]) -> StealthRoom:
	var rounds: Array[Array] = [guard_round]
	return StealthRoom.new(GridGraph.new(10, 6), [Vector2i(0, 0)] as Array[Vector2i],
			Vector2i(0, 4), Vector2i(9, 5), rounds)


func test_the_controller_is_sound() -> void:
	assert_str(Suspicion.build_controller().problem()).is_empty()


func test_suspicion_starts_at_nothing() -> void:
	assert_float(Suspicion.new().level).is_equal(0.0)


func test_seen_close_in_the_light_raises_suspicion_towards_alarmed() -> void:
	var suspicion := Suspicion.new()
	for _turn: int in range(6):
		suspicion.observe(true, 1.0, 1.0, 0.0)
	assert_float(suspicion.level).is_greater(StealthGuard.ALERT_AT)


func test_seen_far_off_in_the_dark_does_not_lower_it() -> void:
	var suspicion := Suspicion.new()
	for _turn: int in range(6):
		suspicion.observe(true, 1.0, 1.0, 0.0)
	var high: float = suspicion.level
	suspicion.observe(true, Suspicion.SIGHT, 0.0, 0.0)
	assert_float(suspicion.level).is_equal(high)


func test_out_of_sight_and_silent_it_falls_away() -> void:
	var suspicion := Suspicion.new()
	for _turn: int in range(6):
		suspicion.observe(true, 1.0, 1.0, 0.0)
	var high: float = suspicion.level
	for _turn: int in range(10):
		suspicion.observe(false, 0.0, 0.0, 0.0)
	assert_float(suspicion.level).is_less(StealthGuard.CALM_BELOW)
	assert_float(suspicion.level).is_less(high)


func test_a_noise_alone_makes_a_guard_wary() -> void:
	var suspicion := Suspicion.new()
	for _turn: int in range(4):
		suspicion.observe(false, 0.0, 0.0, 1.0)
	assert_float(suspicion.level).is_greater(StealthGuard.INVESTIGATE_AT)
	assert_int(suspicion.unseen_for).is_equal(0)


func test_the_why_is_written_down_for_every_term() -> void:
	var suspicion := Suspicion.new()
	suspicion.observe(true, 1.0, 1.0, 0.0)
	assert_dict(suspicion.activations["alarm"]).contains_keys(["calm", "wary", "alarmed"])
	assert_float(suspicion.activations["alarm"]["alarmed"]).is_equal(1.0)


func test_states_rise_with_suspicion() -> void:
	assert_str(StealthGuard.next_state(StealthGuard.PATROL, 10.0)).is_equal(StealthGuard.PATROL)
	assert_str(StealthGuard.next_state(StealthGuard.PATROL, 45.0)).is_equal(StealthGuard.INVESTIGATE)
	assert_str(StealthGuard.next_state(StealthGuard.PATROL, 80.0)).is_equal(StealthGuard.ALERT)


func test_coming_down_passes_through_investigate_and_waits_for_calm() -> void:
	assert_str(StealthGuard.next_state(StealthGuard.ALERT, 60.0)).is_equal(StealthGuard.INVESTIGATE)
	assert_str(StealthGuard.next_state(StealthGuard.ALERT, 30.0)).is_equal(StealthGuard.INVESTIGATE)
	assert_str(StealthGuard.next_state(StealthGuard.INVESTIGATE, 30.0)).is_equal(StealthGuard.INVESTIGATE)
	assert_str(StealthGuard.next_state(StealthGuard.INVESTIGATE, 20.0)).is_equal(StealthGuard.PATROL)


func test_a_patrolling_guard_walks_its_round_by_a_star() -> void:
	var world := StealthWorld.new(_open_room())
	world.play(Vector2i.ZERO)
	world.play(Vector2i.ZERO)
	var guard: StealthGuard = world.guards[0]
	assert_str(guard.state).is_equal(StealthGuard.PATROL)
	assert_that(guard.unit.cell).is_equal(Vector2i(7, 1))
	assert_that(guard.facing).is_equal(Vector2i.RIGHT)


func test_a_guard_walks_round_a_wall_rather_than_through_it() -> void:
	var room: StealthRoom = _open_room([Vector2i(5, 1), Vector2i(8, 1)])
	room.graph.block(Vector2i(6, 1))
	var world := StealthWorld.new(room)
	world.play(Vector2i.ZERO)
	assert_that(world.guards[0].unit.cell).is_not_equal(Vector2i(6, 1))


func test_a_heard_sprint_sends_a_guard_to_look() -> void:
	var world := StealthWorld.new(_open_room([Vector2i(4, 1), Vector2i(4, 1)]))
	world.guards[0].facing = Vector2i.UP
	for _turn: int in range(3):
		world.play(Vector2i.RIGHT, true)
		world.play(Vector2i.LEFT, true)
	var guard: StealthGuard = world.guards[0]
	assert_str(guard.state).is_not_equal(StealthGuard.PATROL)
	assert_that(guard.last_known).is_not_equal(StealthGuard.NOWHERE)


func test_a_wall_stops_the_player_and_the_turn_still_passes() -> void:
	var room: StealthRoom = _open_room()
	room.graph.block(Vector2i(1, 4))
	var world := StealthWorld.new(room)
	world.play(Vector2i.RIGHT)
	assert_that(world.player.cell).is_equal(Vector2i(0, 4))
	assert_int(world.turn).is_equal(1)
	assert_float(world.last_noise).is_equal(0.0)


func test_a_sprint_covers_two_cells_and_carries_further() -> void:
	var world := StealthWorld.new(_open_room())
	world.play(Vector2i.RIGHT, true)
	assert_that(world.player.cell).is_equal(Vector2i(2, 4))
	assert_float(world.last_noise).is_equal(StealthWorld.SPRINT_NOISE)


func test_reaching_the_exit_ends_the_game() -> void:
	var room: StealthRoom = _open_room()
	room.player_start = Vector2i(8, 5)
	var world := StealthWorld.new(room)
	world.play(Vector2i.RIGHT)
	assert_str(world.outcome).is_equal(StealthWorld.ESCAPED)
	assert_bool(world.play(Vector2i.LEFT)).is_false()


func test_standing_in_the_light_in_front_of_a_guard_gets_you_caught() -> void:
	var room: StealthRoom = _open_room([Vector2i(3, 0), Vector2i(3, 0)])
	room.player_start = Vector2i(0, 0)
	var world := StealthWorld.new(room)
	world.guards[0].facing = Vector2i.LEFT
	for _turn: int in range(12):
		world.play(Vector2i.ZERO)
	assert_str(world.outcome).is_equal(StealthWorld.CAUGHT)


func test_the_danger_map_peaks_under_each_guard() -> void:
	var world := StealthWorld.new(StealthRoom.default_room())
	var map: InfluenceMap = world.danger()
	for guard: StealthGuard in world.guards:
		assert_float(map.value_at(guard.unit.cell)).is_equal(map.strongest())


func test_the_default_room_has_a_way_out() -> void:
	var room: StealthRoom = StealthRoom.default_room()
	var route: Array[Vector2i] = AStarSearch.new().find_path(room.graph, room.player_start, room.exit)
	assert_array(route).is_not_empty()


func test_the_demo_loads_and_writes_out_every_guard() -> void:
	var demo: StealthDemo = auto_free(load("res://game/stealth/stealth.tscn").instantiate())
	add_child(demo)
	demo.press(Vector2i.RIGHT)
	var text: String = demo.status_text()
	assert_str(text).contains("turn 1")
	assert_str(text).contains("guard 1")
	assert_str(text).contains("guard 2")
	assert_str(text).contains("rules: calm")
	demo.toggle_danger()
	demo.restart()
	assert_str(demo.status_text()).contains("turn 0")
