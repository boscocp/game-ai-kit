# The real-time core's pieces, one at a time. The two scripts beside this --
# rts_core_budget.gd and rts_simulation.gd -- hold the whole at scale; these
# hold the parts small enough that a failure names the part.
extends GdUnitTestSuite


func test_the_spatial_hash_answers_a_circle_sorted_by_id_edge_included() -> void:
	var spatial := SpatialHash.new(2.0)
	spatial.place(7, Vector2(1.0, 1.0))
	spatial.place(3, Vector2(3.0, 1.0))
	spatial.place(5, Vector2(9.0, 9.0))
	assert_array(spatial.near(Vector2(1.0, 1.0), 2.0)).is_equal([3, 7])


func test_the_spatial_hash_follows_a_move_across_buckets_and_forgets_on_remove() -> void:
	var spatial := SpatialHash.new(2.0)
	spatial.place(1, Vector2(0.5, 0.5))
	spatial.place(1, Vector2(8.5, 8.5))
	assert_array(spatial.near(Vector2(0.5, 0.5), 1.0)).is_empty()
	assert_array(spatial.near(Vector2(8.5, 8.5), 1.0)).is_equal([1])
	spatial.remove(1)
	spatial.remove(1)
	assert_int(spatial.size()).is_equal(0)


func test_a_flow_field_leads_round_a_wall_to_its_goal() -> void:
	# A wall down column 2 with one gap at the bottom row.
	var graph := GridGraph.new(5, 3)
	graph.block(Vector2i(2, 0))
	graph.block(Vector2i(2, 1))
	var field := FlowField.new(graph, Vector2i(4, 0))
	field.settle(1000)
	assert_bool(field.complete).is_true()
	assert_vector(field.direction_at(Vector2i(4, 0))).is_equal(Vector2i.ZERO)
	# From the top left, the arrows must be followable all the way there.
	var cell := Vector2i(0, 0)
	for _step: int in range(20):
		cell += field.direction_at(cell)
	assert_vector(cell).is_equal(Vector2i(4, 0))


func test_a_flow_field_settles_in_slices_and_says_when_it_is_done() -> void:
	var field := FlowField.new(GridGraph.new(10, 10), Vector2i(0, 0))
	assert_bool(field.settle(10)).is_false()
	# A slice is counted in steps, and a step that skips an empty bucket
	# settles nothing, so ten steps settle ten cells at most.
	assert_int(field.work).is_equal(10)
	assert_int(field.settled).is_less_equal(10)
	assert_bool(field.settle(1000)).is_true()
	assert_int(field.settled).is_equal(100)


func test_a_cell_walled_off_is_unreachable_and_points_nowhere() -> void:
	var graph := GridGraph.new(3, 3)
	graph.block(Vector2i(1, 0))
	graph.block(Vector2i(0, 1))
	var field := FlowField.new(graph, Vector2i(2, 2))
	field.settle(1000)
	assert_int(field.distance_at(Vector2i(0, 0))).is_equal(FlowField.UNREACHABLE)
	assert_vector(field.direction_at(Vector2i(0, 0))).is_equal(Vector2i.ZERO)


func test_a_command_survives_its_recording_and_a_damaged_one_is_refused() -> void:
	var given: RtsCommand = RtsCommand.build(4, RtsKinds.BARRACKS, Vector2i(6, 7))
	var back: RtsCommand = RtsCommand.from_dict(given.to_dict())
	assert_dict(back.to_dict()).is_equal(given.to_dict())
	assert_object(RtsCommand.from_dict({"kind": "teleport", "units": [1], "cell": [0, 0]})).is_null()
	assert_object(RtsCommand.from_dict({"kind": RtsCommand.MOVE, "units": [1], "cell": [0]})).is_null()


func test_a_refused_command_says_why_and_changes_nothing() -> void:
	var world := RtsWorld.new(GridGraph.new(8, 8), 1)
	var soldier: RtsUnit = world.add_unit(RtsKinds.SOLDIER, 0, Vector2i(1, 1))
	var mine: RtsUnit = world.add_unit(RtsKinds.MINE, RtsWorld.NEUTRAL, Vector2i(2, 1))
	var before: String = world.digest()
	assert_str(world.command(1, RtsCommand.move([soldier.id] as Array[int], Vector2i(5, 5)))).contains("not yours")
	assert_str(world.command(0, RtsCommand.gather([soldier.id] as Array[int], mine.id))).contains("only a worker")
	assert_str(world.command(0, RtsCommand.move([soldier.id] as Array[int], Vector2i(2, 1)))).contains("nobody can stand")
	assert_str(world.digest()).is_equal(before)


func test_training_is_paid_for_when_ordered_and_refused_without_the_money() -> void:
	var world := RtsWorld.new(GridGraph.new(8, 8), 1)
	var base: RtsUnit = world.add_unit(RtsKinds.BASE, 0, Vector2i(3, 3))
	world.resources[0] = 60
	assert_str(world.command(0, RtsCommand.train(base.id, RtsKinds.WORKER))).is_empty()
	assert_int(world.resources[0]).is_equal(10)
	assert_str(world.command(0, RtsCommand.train(base.id, RtsKinds.WORKER))).contains("costs")
	assert_int(base.queue.size()).is_equal(1)


func test_a_trained_unit_steps_out_once_its_ticks_are_done() -> void:
	var world := RtsWorld.new(GridGraph.new(8, 8), 1)
	var base: RtsUnit = world.add_unit(RtsKinds.BASE, 0, Vector2i(3, 3))
	world.resources[0] = 50
	world.command(0, RtsCommand.train(base.id, RtsKinds.WORKER))
	for _tick: int in range(RtsKinds.of(RtsKinds.WORKER, "ticks")):
		world.step()
	assert_int(world.units().size()).is_equal(2)
	assert_array(base.queue).is_empty()


func test_a_building_blocks_its_cell_and_frees_it_when_it_falls() -> void:
	var world := RtsWorld.new(GridGraph.new(8, 8), 1)
	var barracks: RtsUnit = world.add_unit(RtsKinds.BARRACKS, 0, Vector2i(4, 4))
	assert_bool(world.graph.is_blocked(Vector2i(4, 4))).is_true()
	barracks.health = 0
	world.step()
	assert_object(world.unit(barracks.id)).is_null()
	assert_bool(world.graph.is_blocked(Vector2i(4, 4))).is_false()


func test_a_snapshot_is_a_read_only_copy_that_obeys_the_fog() -> void:
	var world := RtsWorld.new(GridGraph.new(30, 30), 1)
	world.add_unit(RtsKinds.SOLDIER, 0, Vector2i(1, 1))
	var near: RtsUnit = world.add_unit(RtsKinds.SOLDIER, 1, Vector2i(3, 1))
	var far: RtsUnit = world.add_unit(RtsKinds.SOLDIER, 1, Vector2i(28, 28))
	var view: RtsSnapshot = RtsSnapshot.of(world, 0)
	var ids: Array = view.units.map(func(unit: Dictionary) -> int: return unit["id"])
	assert_bool(near.id in ids).is_true()
	assert_bool(far.id in ids).is_false()
	assert_bool(view.units.is_read_only()).is_true()
	assert_bool(view.units[0].is_read_only()).is_true()
	assert_bool(is_same(view.graph, world.graph)).is_false()


func test_an_idle_soldier_goes_for_an_enemy_it_can_see() -> void:
	var world := RtsWorld.new(GridGraph.new(10, 10), 1)
	var soldier: RtsUnit = world.add_unit(RtsKinds.SOLDIER, 0, Vector2i(1, 1))
	var enemy: RtsUnit = world.add_unit(RtsKinds.WORKER, 1, Vector2i(4, 1))
	for _tick: int in range(RtsOrders.LOOK_EVERY):
		world.step()
	assert_str(soldier.order).is_equal(RtsCommand.ATTACK)
	assert_int(soldier.target_id).is_equal(enemy.id)


func test_the_frame_budget_reads_the_mean_and_the_slow_frames() -> void:
	var budget := FrameBudget.new()
	for time: int in [1000, 1000, 1000, 9000]:
		budget.record(FrameBudget.SIMULATION, time)
	assert_float(budget.mean_ms(FrameBudget.SIMULATION)).is_equal_approx(3.0, 0.001)
	assert_float(budget.percentile_ms(FrameBudget.SIMULATION, 0.95)).is_equal_approx(9.0, 0.001)
	assert_str(budget.why_over(FrameBudget.SIMULATION)).contains("95th percentile")
	assert_str(budget.why_over(FrameBudget.TACTICS)).contains("never measured")


func test_the_longest_sight_is_the_tables_longest() -> void:
	# `visible_to` only asks this far; a kind that saw further would be
	# silently half blind.
	var longest: float = 0.0
	for kind: String in RtsKinds.TABLE:
		longest = maxf(longest, RtsKinds.of(kind, "sight"))
	assert_float(RtsKinds.LONGEST_SIGHT).is_equal(longest)


func test_nobody_can_build_over_a_unit_standing_near_the_cells_edge() -> void:
	var world := RtsWorld.new(GridGraph.new(10, 10), 1)
	var worker: RtsUnit = world.add_unit(RtsKinds.WORKER, 0, Vector2i(2, 2))
	var standing: RtsUnit = world.add_unit(RtsKinds.SOLDIER, 0, Vector2i(5, 5))
	world.place(standing, Vector2(5.05, 5.05))
	world.resources[0] = 500
	assert_str(world.command(0, RtsCommand.build(worker.id, RtsKinds.BARRACKS, Vector2i(5, 5)))).contains("not free")


func test_building_in_the_fog_is_refused_without_saying_who_stands_there() -> void:
	var world := RtsWorld.new(GridGraph.new(40, 10), 1)
	var worker: RtsUnit = world.add_unit(RtsKinds.WORKER, 0, Vector2i(1, 1))
	world.add_unit(RtsKinds.WORKER, 1, Vector2i(35, 5))
	world.resources[0] = 500
	assert_str(world.command(0, RtsCommand.build(worker.id, RtsKinds.BARRACKS, Vector2i(35, 5)))).contains("not in sight")
	assert_str(world.command(0, RtsCommand.attack([worker.id] as Array[int], 9999))).is_equal("unit 9999 is not in sight")


func test_a_blow_struck_at_a_building_going_up_stays_struck() -> void:
	var world := RtsWorld.new(GridGraph.new(10, 10), 1)
	var worker: RtsUnit = world.add_unit(RtsKinds.WORKER, 0, Vector2i(4, 5))
	world.resources[0] = 500
	world.command(0, RtsCommand.build(worker.id, RtsKinds.BARRACKS, Vector2i(5, 5)))
	var site: RtsUnit = world.unit(worker.target_id)
	for _tick: int in range(100):
		world.step()
	var before: int = site.health
	site.health -= 40
	world.step()
	assert_int(site.health).is_less(before)


func test_a_snapshot_board_leaves_out_the_buildings_in_the_fog() -> void:
	var world := RtsWorld.new(GridGraph.new(40, 10), 1)
	world.add_unit(RtsKinds.SOLDIER, 0, Vector2i(1, 1))
	world.add_unit(RtsKinds.BARRACKS, 1, Vector2i(35, 5))
	var view: RtsSnapshot = RtsSnapshot.of(world, 0)
	assert_bool(world.graph.is_blocked(Vector2i(35, 5))).is_true()
	assert_bool(view.graph.is_blocked(Vector2i(35, 5))).is_false()


func test_a_straight_walk_does_not_cut_a_corner_the_board_cannot() -> void:
	# A wall on the diagonal: (5, 5) is on the far side of it.
	var graph := GridGraph.new(10, 10)
	for step: int in range(10):
		graph.block(Vector2i(step, 9 - step))
	var world := RtsWorld.new(graph, 1)
	var soldier: RtsUnit = world.add_unit(RtsKinds.SOLDIER, 0, Vector2i(4, 4))
	world.command(0, RtsCommand.move([soldier.id] as Array[int], Vector2i(5, 5)))
	for _tick: int in range(120):
		world.step()
	assert_vector(soldier.cell()).is_equal(Vector2i(4, 4))


func test_a_move_into_a_building_in_the_fog_is_taken_and_ends_at_it() -> void:
	var world := RtsWorld.new(GridGraph.new(40, 10), 1)
	var soldier: RtsUnit = world.add_unit(RtsKinds.SOLDIER, 0, Vector2i(1, 5))
	world.add_unit(RtsKinds.BARRACKS, 1, Vector2i(35, 5))
	assert_str(world.command(0, RtsCommand.move([soldier.id] as Array[int], Vector2i(35, 5)))).is_empty()
	world.step()
	assert_str(soldier.order).is_equal(RtsUnit.IDLE)
	assert_vector(soldier.cell()).is_equal(Vector2i(1, 5))


func test_a_move_whose_goal_is_built_over_ends_instead_of_walking_in() -> void:
	var world := RtsWorld.new(GridGraph.new(20, 10), 1)
	var soldier: RtsUnit = world.add_unit(RtsKinds.SOLDIER, 0, Vector2i(1, 5))
	world.command(0, RtsCommand.move([soldier.id] as Array[int], Vector2i(15, 5)))
	world.step()
	# Its own side's, so the soldier, idle again, has no enemy to turn on.
	world.add_unit(RtsKinds.BARRACKS, 0, Vector2i(15, 5))
	for _tick: int in range(600):
		world.step()
	assert_str(soldier.order).is_equal(RtsUnit.IDLE)
	assert_bool(world.graph.is_blocked(soldier.cell())).is_false()


func test_a_site_struck_down_while_going_up_stays_down() -> void:
	var world := RtsWorld.new(GridGraph.new(10, 10), 1)
	var worker: RtsUnit = world.add_unit(RtsKinds.WORKER, 0, Vector2i(4, 5))
	world.resources[0] = 500
	world.command(0, RtsCommand.build(worker.id, RtsKinds.BARRACKS, Vector2i(5, 5)))
	var site: RtsUnit = world.unit(worker.target_id)
	world.step()
	# Killed between ticks, at exactly 0. The worker acts first next tick,
	# and that tick's share of health is 1: it must not be added.
	site.health = 0
	world.step()
	assert_object(world.unit(site.id)).is_null()


func test_an_enemy_in_sight_shows_what_a_player_sees_and_no_more() -> void:
	var world := RtsWorld.new(GridGraph.new(10, 10), 1)
	world.add_unit(RtsKinds.SOLDIER, 0, Vector2i(1, 1))
	var enemy: RtsUnit = world.add_unit(RtsKinds.WORKER, 1, Vector2i(3, 1))
	var shown: Dictionary = RtsSnapshot.of(world, 0).enemies()[0]
	assert_int(shown["id"]).is_equal(enemy.id)
	assert_bool(shown.has("order") or shown.has("carrying") or shown.has("queued")).is_false()
	assert_bool(RtsSnapshot.of(world, 0).mine()[0].has("order")).is_true()
