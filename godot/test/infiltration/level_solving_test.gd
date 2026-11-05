# A level solved off the main thread (T122): the pool makes the level the
# inline call makes, cell for cell and step for step, on three seeds with
# the slowest (144) among them; one solve runs at a time; and the scene
# keeps playing the old level until the new one is ready.
extends GdUnitTestSuite

const SEEDS: Array[int] = [3, 54, 144]
const SCENE: String = "res://game3d/infiltration/infiltration.tscn"


func test_the_pool_solves_the_level_the_inline_call_solves() -> void:
	for seed_value: int in SEEDS:
		var inline := LevelConstraints.solve(seed_value, true)
		var solving := LevelSolving.new()
		solving.start(seed_value)
		var pooled: LevelConstraints = solving.wait()
		var message: String = "seed %d" % seed_value
		assert_bool(pooled.data.is_empty()).override_failure_message(message).is_false()
		assert_dict(pooled.data).override_failure_message(message).is_equal(inline.data)
		assert_dict(pooled.assignment).override_failure_message(message).is_equal(inline.assignment)
		assert_int(pooled.solver.assignments).override_failure_message(message).is_equal(inline.solver.assignments)
		assert_int(pooled.solver.backtracks).override_failure_message(message).is_equal(inline.solver.backtracks)
		assert_int(pooled.restarts).override_failure_message(message).is_equal(inline.restarts)
		assert_array(pooled.solver.trace).override_failure_message(message).is_equal(inline.solver.trace)


# Seed 144 takes about two seconds: the second start lands while it runs and
# is ignored, since a task cannot be stopped.
func test_one_solve_at_a_time() -> void:
	var solving := LevelSolving.new()
	solving.start(144)
	solving.start(3)
	assert_bool(solving.busy()).is_true()
	assert_int(solving.seed_value).is_equal(144)
	assert_int(solving.wait().seed_value).is_equal(144)
	assert_bool(solving.busy()).is_false()
	assert_object(solving.poll()).is_null()
	assert_object(solving.wait()).is_null()


func test_the_scene_plays_the_old_level_until_the_new_one_is_solved() -> void:
	var demo: Node = _demo_on_last_hand_made()
	var hand_made: InfiltrationWorld = demo.world
	demo.next_level()
	assert_object(demo.world).is_same(hand_made)
	assert_bool(demo._solving.busy()).is_true()
	var wanted: int = demo._seed + InfiltrationLevel.HAND_MADE.size()
	demo._show()
	assert_str(demo._panel.text).contains(_solving_line(wanted))
	await _settle(demo)
	assert_str(demo.world.level.name).is_equal("solved %d" % wanted)
	assert_str(demo._panel.text).not_contains(_solving_line(wanted))
	assert_object(demo.solved).is_not_null()
	assert_dict(demo.solved.data).is_equal(LevelConstraints.solve(wanted, true).data)


# L pressed twice while the first generated level solves: the level asked
# for last is the one that arrives, and the panel names it meanwhile.
func test_l_pressed_mid_solve_reaches_the_level_asked_for() -> void:
	var demo: Node = _demo_on_last_hand_made()
	demo.next_level()
	demo.next_level()
	var wanted: int = demo._seed + demo._level_index
	assert_int(demo._awaited).is_equal(wanted)
	await _settle(demo)
	await _settle(demo)
	assert_str(demo.world.level.name).is_equal("solved %d" % wanted)


# A solve that ends after K went back to drawn neither rebuilds the drawn
# world being played nor says, meanwhile, that it will replace it.
func test_a_solve_no_longer_wanted_leaves_the_level_played_alone() -> void:
	var demo: Node = _demo_on_last_hand_made()
	demo.next_level()
	var wanted: int = demo._seed + demo._level_index
	demo.rules.level_generator = LevelGenerator.DRAW
	demo.new_world()
	var drawn: InfiltrationWorld = demo.world
	assert_bool(demo._solving.busy()).is_true()
	demo._show()
	assert_str(demo._panel.text).not_contains(_solving_line(wanted))
	await _settle(demo)
	assert_object(demo.world).is_same(drawn)
	assert_object(demo._last_solved).is_not_null()


# The scene freed while a solve runs waits for it, so the pool frees it.
func test_the_scene_freed_mid_solve_waits_for_the_task() -> void:
	var demo: Node = load(SCENE).instantiate()
	demo.solve_in_background = true
	add_child(demo)
	demo.rules.level_generator = LevelGenerator.CONSTRAINTS
	demo._level_index = InfiltrationLevel.HAND_MADE.size() - 1
	demo.next_level()
	var solving: LevelSolving = demo._solving
	assert_bool(solving.busy()).is_true()
	demo.free()
	assert_bool(solving.busy()).is_false()


# The scene on the last hand-made level, the solver's mode on, the pool on.
func _demo_on_last_hand_made() -> Node:
	var demo: Node = auto_free(load(SCENE).instantiate())
	demo.solve_in_background = true
	add_child(demo)
	demo.rules.level_generator = LevelGenerator.CONSTRAINTS
	demo._level_index = InfiltrationLevel.HAND_MADE.size() - 1
	return demo


# Physics frames until the pool's solve is collected, and one more.
func _settle(demo: Node) -> void:
	var waited: int = 0
	while demo._solving.busy() and waited < 1200:
		await get_tree().physics_frame
		waited += 1
	await get_tree().physics_frame


func _solving_line(seed_value: int) -> String:
	return tr("solving level {seed}: this one plays until it is ready").format({seed = seed_value})
