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
	var demo: Node = auto_free(load(SCENE).instantiate())
	demo.solve_in_background = true
	add_child(demo)
	var hand_made: InfiltrationWorld = demo.world
	demo.rules.level_generator = LevelGenerator.CONSTRAINTS
	demo._level_index = InfiltrationLevel.HAND_MADE.size() - 1
	demo.next_level()
	assert_object(demo.world).is_same(hand_made)
	assert_bool(demo._solving.busy()).is_true()
	var waited: int = 0
	while demo._solving.busy() and waited < 600:
		await get_tree().physics_frame
		waited += 1
	await get_tree().physics_frame
	var wanted: int = demo._seed + InfiltrationLevel.HAND_MADE.size()
	assert_str(demo.world.level.name).is_equal("solved %d" % wanted)
	assert_object(demo.solved).is_not_null()
	assert_dict(demo.solved.data).is_equal(LevelConstraints.solve(wanted, true).data)
