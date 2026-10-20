# T20's pieces, one at a time: the domain the commander plans with, the
# schedule that times a plan, the queue's one rule, the belief under fog,
# the squads' choice, the levels and the end. `rts_match.gd` holds the whole
# match; these hold the parts small enough that a failure names the part.
extends GdUnitTestSuite


func test_the_games_domain_is_a_byte_for_byte_copy_of_the_spec() -> void:
	var spec: String = ProjectSettings.globalize_path("res://").path_join("../spec/pddl/rts-build-order.json")
	assert_str(FileAccess.get_file_as_string(BuildOrder.DOMAIN_PATH)).is_equal(FileAccess.get_file_as_string(spec))


func test_both_planners_find_the_six_steps_to_mortars_from_the_opening() -> void:
	var opening := PackedStringArray(["supply_room"])
	var goal := PackedStringArray(["mortars_ready"])
	for planner: BuildOrder.Planner in [BuildOrder.Planner.STRIPS, BuildOrder.Planner.HTN]:
		var found: Dictionary = BuildOrder.plan(opening, goal, planner)
		assert_bool(found["solved"]).is_true()
		assert_int((found["steps"] as PackedStringArray).size()).is_equal(6)
		assert_str(found["steps"][-1]).is_equal("train_mortars")


func test_a_short_horizon_gives_a_partial_plan_towards_the_goal() -> void:
	var found: Dictionary = BuildOrder.plan(PackedStringArray(["supply_room"]), PackedStringArray(["mortars_ready"]),
		BuildOrder.Planner.STRIPS, 2)
	assert_bool(found["solved"]).is_false()
	assert_bool(found["partial"]).is_true()
	assert_int((found["steps"] as PackedStringArray).size()).is_less_equal(2)


func test_the_opening_holds_room_and_nothing_else() -> void:
	var held: PackedStringArray = BuildOrder.facts(RtsSnapshot.of(RtsScenario.start(1), RtsScenario.WEST))
	assert_array(Array(held)).contains_exactly(["supply_room"])


func test_the_schedule_jumps_to_the_second_the_price_is_met() -> void:
	# Four workers on ore, 200 ore held: a barracks (150) now, then a depot
	# (100) when 50 more has come in at four workers' rate.
	var world: RtsWorld = RtsScenario.start(1)
	var view: RtsSnapshot = _with_workers_on_ore(world)
	var rate: float = BuildSchedule.income(view)[RtsKinds.ORE]
	assert_float(rate).is_greater(0.0)
	var timed: Array[Dictionary] = BuildSchedule.of(PackedStringArray(["build_barracks", "build_depot"]), view)
	assert_float(timed[0]["starts"]).is_equal(0.0)
	assert_float(timed[1]["starts"]).is_equal_approx(50.0 / rate, 0.001)
	assert_str(timed[1]["waits"]).is_equal(RtsKinds.ORE)


func test_a_step_whose_resource_nobody_mines_never_comes() -> void:
	var view: RtsSnapshot = _with_workers_on_ore(RtsScenario.start(1))
	var timed: Array[Dictionary] = BuildSchedule.of(PackedStringArray(["build_tower"]), view)
	assert_float(timed[0]["starts"]).is_equal(BuildSchedule.NEVER)
	assert_str(timed[0]["waits"]).is_equal(RtsKinds.MAGMA)


func test_the_top_wish_waits_and_nothing_below_it_spends_meanwhile() -> void:
	var world: RtsWorld = RtsScenario.start(1)
	world.set_funds(RtsScenario.WEST, 120)
	var queue := EconomyQueue.new(RtsScenario.WEST, 1)
	queue.wish(RtsKinds.BARRACKS, 70, "planted: dearer than what is held")
	queue.wish(RtsKinds.WORKER, 50, "planted: affordable, but below")
	var given: Array[RtsCommand] = queue.commands(RtsSnapshot.of(world, RtsScenario.WEST))
	for command: RtsCommand in given:
		assert_str(command.kind).is_not_equal(RtsCommand.TRAIN)
	assert_int(queue.wishes.size()).is_equal(2)


func test_an_enemy_out_of_sight_is_believed_less_as_time_passes_then_forgotten() -> void:
	var world := RtsWorld.new(GridGraph.new(48, 32), 1)
	world.add_unit(RtsKinds.WORKER, 0, Vector2i(2, 2))
	var enemy: RtsUnit = world.add_unit(RtsKinds.SHIELD, 1, Vector2i(5, 2))
	var belief := RtsInfluence.new(48, 32)
	belief.update(RtsSnapshot.of(world, 0))
	var seen: float = belief.at(Vector2i(5, 2))[1]
	world.place(enemy, Vector2(40.5, 30.5))
	world.tick += RtsWorld.TICKS_PER_SECOND * 20
	belief.update(RtsSnapshot.of(world, 0))
	var remembered: float = belief.at(Vector2i(5, 2))[1]
	assert_float(remembered).is_greater(0.0)
	assert_float(remembered).is_less(seen)
	assert_float(belief.at(Vector2i(40, 30))[1]).is_equal(0.0)
	world.tick += RtsWorld.TICKS_PER_SECOND * 30
	belief.update(RtsSnapshot.of(world, 0))
	assert_float(belief.at(Vector2i(5, 2))[1]).is_equal(0.0)


func test_a_squad_keeps_its_region_until_another_is_clearly_better() -> void:
	# At the bridge with nothing seen: the east home scores about 0.98, the
	# east expansion -- unknown, so worth a look -- about 0.55, under the
	# best by more than STICK.
	var tactics := SquadTactics.new(RtsScenario.WEST, 1, 0.0, 1)
	var belief := RtsInfluence.new(48, 32)
	var squad := Squad.new(1, RtsScenario.WEST)
	squad.strength = 500.0
	squad.centre = Vector2(24, 15)
	squad.target = "east expansion"
	assert_str(tactics.choose(squad, belief)).is_equal("east home")
	assert_float(squad.scores["east expansion"] * SquadTactics.STICK).is_less(squad.scores["east home"])
	squad.target = "east home"
	assert_str(tactics.choose(squad, belief)).is_equal("east home")
	# A region within STICK of the best keeps the squad on it.
	squad.target = "bridge"
	squad.centre = Vector2(24, 15)
	var near_best: bool = squad.scores["bridge"] * SquadTactics.STICK >= squad.scores["east home"]
	assert_str(tactics.choose(squad, belief)).is_equal("bridge" if near_best else "east home")


func test_the_rts_levels_are_t12s_class_and_its_three_knobs() -> void:
	var names: Array[String] = []
	for level: Difficulty in RtsLevels.presets():
		names.append(level.name)
	assert_array(names).contains_exactly(["easy", "normal"])
	assert_array(Difficulty.KNOBS).contains_exactly(["plan_horizon", "search_depth", "evaluation_noise"])


func test_time_runs_out_to_the_side_worth_more_and_a_lost_base_ends_it_sooner() -> void:
	var world: RtsWorld = RtsScenario.start(1)
	assert_int(RtsVictory.winner(world)).is_equal(RtsVictory.UNDECIDED)
	world.tick = RtsScenario.TIME_LIMIT_SECONDS * RtsWorld.TICKS_PER_SECOND
	assert_int(RtsVictory.winner(world)).is_equal(RtsVictory.DRAW)
	world.set_funds(RtsScenario.EAST, RtsScenario.START_ORE + 1)
	assert_int(RtsVictory.winner(world)).is_equal(RtsScenario.EAST)
	world.tick = 0
	for unit: RtsUnit in world.units():
		if unit.side == RtsScenario.EAST and unit.kind == RtsKinds.BASE:
			unit.health = 0
	world.step()
	assert_int(RtsVictory.winner(world)).is_equal(RtsScenario.WEST)


# Every west worker set gathering from its nearest rocks, and the snapshot.
func _with_workers_on_ore(world: RtsWorld) -> RtsSnapshot:
	var rocks: Array[RtsUnit] = []
	for unit: RtsUnit in world.units():
		if unit.kind == RtsKinds.ROCKS and unit.position.distance_to(Vector2(RtsScenario.home(RtsScenario.WEST))) < 6.0:
			rocks.append(unit)
	var workers: Array[int] = []
	for unit: RtsUnit in world.units():
		if unit.side == RtsScenario.WEST and unit.kind == RtsKinds.WORKER:
			workers.append(unit.id)
	world.command(RtsScenario.WEST, RtsCommand.gather(workers, rocks[0].id))
	return RtsSnapshot.of(world, RtsScenario.WEST)
