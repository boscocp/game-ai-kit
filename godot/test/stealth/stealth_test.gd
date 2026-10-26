# The stealth scenario: suspicion, the guards' three states, the rules of a
# turn, and the demo -- that it loads and writes out what each guard thinks.
# Whether that reads as a decision is the manual check, and a person's.
#
# The words are read in English, so each test starts in English whatever the
# machine's locale; the Portuguese one says so and sets it (T79).
extends GdUnitTestSuite

var _locale_before: String = ""


func before() -> void:
	_locale_before = TranslationServer.get_locale()


func before_test() -> void:
	TranslationServer.set_locale("en")


func after() -> void:
	TranslationServer.set_locale(_locale_before)


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
	assert_str(StealthGuard.next_state(StealthGuard.ALERT, 65.0)).is_equal(StealthGuard.ALERT)
	assert_str(StealthGuard.next_state(StealthGuard.INVESTIGATE, 65.0)).is_equal(StealthGuard.INVESTIGATE)
	assert_str(StealthGuard.next_state(StealthGuard.ALERT, 55.0)).is_equal(StealthGuard.INVESTIGATE)
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


func test_a_heard_sprint_sends_a_guard_to_look_without_seeing_anything() -> void:
	# A wall between the two, so whatever the guard learns it heard. The first
	# version of this test let the guard spin on the spot until it *saw* the
	# player, and could not tell hearing from sight.
	var room: StealthRoom = _open_room([Vector2i(4, 1), Vector2i(4, 1)])
	for column: int in range(10):
		room.graph.block(Vector2i(column, 2))
	room.player_start = Vector2i(2, 4)
	var world := StealthWorld.new(room)
	for _turn: int in range(3):
		world.play(Vector2i.RIGHT, true)
		world.play(Vector2i.LEFT, true)
	var guard: StealthGuard = world.guards[0]
	assert_str(guard.reason).contains("heard")
	assert_str(guard.state).is_equal(StealthGuard.INVESTIGATE)
	assert_that(guard.last_known).is_equal(world.player.cell)


func test_a_walk_is_heard_and_waiting_is_not() -> void:
	var world := StealthWorld.new(_open_room([Vector2i(2, 2), Vector2i(2, 2)]))
	world.guards[0].facing = Vector2i.UP
	world.play(Vector2i.ZERO)
	assert_float(world.guards[0].suspicion.inputs["noise"]).is_equal(0.0)
	world.play(Vector2i.RIGHT)
	assert_float(world.guards[0].suspicion.inputs["noise"]).is_greater(0.0)


func test_light_changes_what_a_sighting_means() -> void:
	var lit := Suspicion.new()
	var dark := Suspicion.new()
	lit.observe(true, 3.0, 1.0, 0.0)
	dark.observe(true, 3.0, 0.0, 0.0)
	assert_float(lit.level).is_greater(dark.level)


func test_the_level_moves_half_way_to_the_answer() -> void:
	var suspicion := Suspicion.new()
	suspicion.observe(true, 1.0, 1.0, 0.0)
	assert_float(suspicion.level).is_equal_approx(suspicion.alarm * Suspicion.RATE, 1e-9)


func test_a_guard_never_steps_onto_the_player_or_another_guard() -> void:
	var rounds: Array[Array] = [[Vector2i(1, 1), Vector2i(8, 1)], [Vector2i(8, 1), Vector2i(1, 1)]]
	var room := StealthRoom.new(GridGraph.new(10, 3), [] as Array[Vector2i], Vector2i(4, 2),
			Vector2i(9, 2), rounds)
	var world := StealthWorld.new(room)
	for _turn: int in range(20):
		world.play(Vector2i.ZERO)
		assert_that(world.guards[0].unit.cell).is_not_equal(world.guards[1].unit.cell)
		assert_that(world.guards[0].unit.cell).is_not_equal(world.player.cell)
		assert_that(world.guards[1].unit.cell).is_not_equal(world.player.cell)


func test_two_guards_in_a_corridor_get_past_each_other_when_there_is_room() -> void:
	# Head on in a corridor two cells wide: they used to spin in place forever,
	# because each planned straight through the other.
	var graph := GridGraph.new(8, 4)
	for column: int in range(8):
		graph.block(Vector2i(column, 0))
		graph.block(Vector2i(column, 3))
	var rounds: Array[Array] = [[Vector2i(0, 1), Vector2i(7, 1)], [Vector2i(7, 1), Vector2i(0, 1)]]
	var world := StealthWorld.new(StealthRoom.new(graph, [] as Array[Vector2i], Vector2i(0, 2), Vector2i(7, 2), rounds))
	world.player.cell = Vector2i(-5, -5)
	for _turn: int in range(10):
		world.play(Vector2i.ZERO)
	# Past each other: the one that started on the left is now on the right.
	assert_that(world.guards[0].unit.cell.x).is_greater(world.guards[1].unit.cell.x)


func test_the_default_room_s_guards_keep_walking() -> void:
	# The rounds are drawn so that no two share a one-cell corridor, which is
	# the one place two guards can still block each other (see StealthGuard).
	var world := StealthWorld.new(StealthRoom.default_room())
	world.player.cell = Vector2i(-5, -5)
	var visited: Dictionary = {}
	for _turn: int in range(200):
		world.play(Vector2i.ZERO)
		for guard: StealthGuard in world.guards:
			visited[guard.unit.cell] = true
	for room_round: Array in world.room.rounds:
		for waypoint: Vector2i in room_round:
			assert_bool(visited.has(waypoint)).is_true()


func test_a_walking_guard_faces_the_way_it_walks() -> void:
	var world := StealthWorld.new(_open_room([Vector2i(5, 1), Vector2i(5, 4)]))
	world.play(Vector2i.ZERO)
	assert_that(world.guards[0].facing).is_equal(Vector2i.DOWN)


func test_a_guard_beside_the_player_it_is_after_faces_them() -> void:
	var guard := StealthGuard.new(Unit.new(1, 1, Vector2i(3, 1)), [Vector2i(3, 1)])
	guard.state = StealthGuard.INVESTIGATE
	guard.last_known = Vector2i(3, 2)
	guard.facing = Vector2i.UP
	var room: StealthRoom = _open_room()
	guard.take_turn(room, VisionCone.new(8.0, 50.0), Unit.new(0, 0, Vector2i(3, 2)), 0.0, [Vector2i(3, 2)] as Array[Vector2i])
	assert_that(guard.facing).is_equal(Vector2i.DOWN)
	assert_that(guard.unit.cell).is_equal(Vector2i(3, 1))


func _alert_guard_beside(world: StealthWorld, facing: Vector2i) -> StealthGuard:
	var guard: StealthGuard = world.guards[0]
	guard.state = StealthGuard.ALERT
	guard.facing = facing
	return guard


func test_an_alert_guard_beside_and_facing_the_player_catches_them() -> void:
	var world := StealthWorld.new(_open_room())
	var guard: StealthGuard = _alert_guard_beside(world, Vector2i.LEFT)
	guard.unit.cell = world.player.cell + Vector2i.RIGHT
	assert_bool(world._catches(guard)).is_true()


func test_a_guard_with_its_back_turned_does_not_catch() -> void:
	var world := StealthWorld.new(_open_room())
	var guard: StealthGuard = _alert_guard_beside(world, Vector2i.RIGHT)
	guard.unit.cell = world.player.cell + Vector2i.RIGHT
	assert_bool(world._catches(guard)).is_false()


func test_a_guard_two_cells_off_does_not_catch() -> void:
	var world := StealthWorld.new(_open_room())
	var guard: StealthGuard = _alert_guard_beside(world, Vector2i.LEFT)
	guard.unit.cell = world.player.cell + Vector2i(2, 0)
	assert_bool(world._catches(guard)).is_false()


func test_only_an_alert_guard_catches() -> void:
	var world := StealthWorld.new(_open_room())
	var guard: StealthGuard = _alert_guard_beside(world, Vector2i.LEFT)
	guard.unit.cell = world.player.cell + Vector2i.RIGHT
	guard.state = StealthGuard.INVESTIGATE
	assert_bool(world._catches(guard)).is_false()


func test_a_guard_that_has_arrived_looks_round() -> void:
	var world := StealthWorld.new(_open_room([Vector2i(5, 1)]))
	world.guards[0].facing = Vector2i.RIGHT
	world.play(Vector2i.ZERO)
	assert_that(world.guards[0].facing).is_equal(Vector2i.DOWN)
	world.play(Vector2i.ZERO)
	assert_that(world.guards[0].facing).is_equal(Vector2i.LEFT)


func test_an_alert_guard_runs_two_cells_a_turn() -> void:
	var world := StealthWorld.new(_open_room([Vector2i(8, 1)]))
	var guard: StealthGuard = world.guards[0]
	guard.state = StealthGuard.ALERT
	guard.suspicion.level = 100.0
	guard.last_known = Vector2i(4, 1)
	world.player.cell = Vector2i(0, 5)
	world.play(Vector2i.ZERO)
	assert_that(guard.unit.cell).is_equal(Vector2i(6, 1))


func test_a_catch_ends_the_turn_for_every_other_guard() -> void:
	var rounds: Array[Array] = [[Vector2i(1, 4)], [Vector2i(8, 1), Vector2i(8, 4)]]
	var world := StealthWorld.new(StealthRoom.new(GridGraph.new(10, 6), [Vector2i(0, 4)] as Array[Vector2i],
			Vector2i(0, 4), Vector2i(9, 5), rounds))
	var catcher: StealthGuard = _alert_guard_beside(world, Vector2i.LEFT)
	catcher.suspicion.level = 100.0
	catcher.last_known = world.player.cell
	world.play(Vector2i.ZERO)
	assert_str(world.outcome).is_equal(StealthWorld.CAUGHT)
	assert_that(world.guards[1].unit.cell).is_equal(Vector2i(8, 1))


func test_the_player_cannot_walk_into_a_guard() -> void:
	var world := StealthWorld.new(_open_room([Vector2i(1, 4), Vector2i(1, 4)]))
	world.play(Vector2i.RIGHT)
	assert_that(world.player.cell).is_equal(Vector2i(0, 4))


func test_a_sprint_stops_on_the_exit() -> void:
	# An exit in the middle of the board: at the edge, the edge stops a sprint
	# whatever the rule says, and the first version of this test was there.
	var room: StealthRoom = _open_room()
	room.exit = Vector2i(5, 4)
	room.player_start = Vector2i(4, 4)
	var world := StealthWorld.new(room)
	world.play(Vector2i.RIGHT, true)
	assert_that(world.player.cell).is_equal(Vector2i(5, 4))
	assert_str(world.outcome).is_equal(StealthWorld.ESCAPED)


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
	var route: Array[Vector2i] = GridPathfinder.new().find_path(room.graph, room.player_start, room.exit)
	assert_array(route).is_not_empty()


func test_walking_straight_across_alarms_a_guard_on_the_way() -> void:
	# The manual check is to watch suspicion rise and fall; on the obvious
	# route it has to rise, or the room teaches nothing to the obvious player.
	var world := StealthWorld.new(StealthRoom.default_room())
	var search := GridPathfinder.new(AStarSearch.new())
	var alarmed: bool = false
	for _turn: int in range(40):
		var route: Array[Vector2i] = search.find_path(world.room.graph, world.player.cell, world.room.exit)
		world.play(route[0] - world.player.cell if not route.is_empty() else Vector2i.ZERO)
		for guard: StealthGuard in world.guards:
			alarmed = alarmed or guard.state == StealthGuard.ALERT
	assert_bool(alarmed).is_true()


func test_the_demo_loads_and_writes_out_every_guard() -> void:
	var demo: StealthDemo = auto_free(load("res://game/stealth/stealth.tscn").instantiate())
	add_child(demo)
	demo.press(Vector2i.RIGHT)
	var text: String = demo.status_text()
	assert_str(text).contains("turn 1")
	assert_str(text).contains("guard 1")
	assert_str(text).contains("guard 2")
	assert_str(text).contains("guard 3")
	assert_str(text).contains("rules: calm")
	assert_str(text).contains("patrol")
	assert_str(text).contains("suspicion")
	assert_str(text).contains("distance")
	assert_str(text).contains("light")
	demo.toggle_danger()
	demo.restart()
	assert_str(demo.status_text()).contains("turn 0")


func test_switching_to_portuguese_rewords_the_turn_already_played() -> void:
	# A guard's reason is put into words when it is read, so the line about
	# the last turn follows the language, and the scene rebuilds its status.
	var demo: StealthDemo = auto_free(load("res://game/stealth/stealth.tscn").instantiate())
	add_child(demo)
	demo.press(Vector2i.RIGHT)
	TranslationServer.set_locale("pt_BR")
	var status: Label = demo.get_node("Interface/Status")

	assert_str(status.text).contains("turno 1")
	assert_str(status.text).contains("guarda 1  ronda · suspeita")
	assert_str(status.text).contains("regras: calmo")
	assert_str(status.text).not_contains("patrol")


# Trees cost what rough ground costs, so the board would draw them as mud
# unless the demo says which cells are trees; the legend says "trees".
func test_the_demo_draws_its_trees_as_trees() -> void:
	var demo: StealthDemo = auto_free(load("res://game/stealth/stealth.tscn").instantiate())
	add_child(demo)
	var board: BoardView = demo.get_node("BoardView")
	var graph: GridGraph = demo.world.room.graph
	var trees: int = 0
	for index: int in range(graph.width * graph.height):
		var cell := Vector2i(index % graph.width, index / graph.width)
		if graph.cost_at(cell) == StealthRoom.TREE:
			trees += 1
			assert_vector(board.get_cell_atlas_coords(cell)).is_equal(BoardView.TREES)
	assert_int(trees).is_greater(0)
