# T20's pieces, one at a time: the domain the commander plans with, the
# schedule that times a plan, the queue's one rule, the belief under fog,
# the squads' choice, the levels and the end. `rts_match.gd` holds the whole
# match; these hold the parts small enough that a failure names the part.
extends GdUnitTestSuite

const StagedRaid := preload("res://test/rts/staged_raid.gd")

# English, whatever the machine speaks: the engine starts in the system's
# locale, and these read the English the game writes (T80). The locale
# found is put back.
var _locale_before: String


func before() -> void:
	_locale_before = TranslationServer.get_locale()
	TranslationServer.set_locale("en")


func after() -> void:
	TranslationServer.set_locale(_locale_before)


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
	queue.wish(RtsKinds.BARRACKS, 70, Sentence.of("planted: dearer than what is held"))
	queue.wish(RtsKinds.WORKER, 50, Sentence.of("planted: affordable, but below"))
	var given: Array[RtsCommand] = queue.commands(RtsSnapshot.of(world, RtsScenario.WEST))
	for command: RtsCommand in given:
		assert_str(command.kind).is_not_equal(RtsCommand.TRAIN)
	assert_int(queue.wishes.size()).is_equal(2)


func test_an_enemy_out_of_sight_is_believed_less_as_time_passes_then_forgotten() -> void:
	var world := RtsWorld.new(GakGridGraph.new(48, 32), 1)
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
	# Walk the squad across the map until two regions score within STICK of
	# each other; there, set on the second, it must stay on the second.
	var tactics := SquadTactics.new(RtsScenario.WEST, 1, 0.0, 1)
	var belief := RtsInfluence.new(48, 32)
	var squad := Squad.new(1, RtsScenario.WEST)
	squad.strength = 500.0
	var found: bool = false
	for index: int in range(48 * 32):
		squad.centre = Vector2(index % 48, index / 48)
		squad.target = ""
		var best: String = tactics.choose(squad, belief)
		var second: String = _runner_up(squad.scores, best)
		if squad.scores[second] < squad.scores[best] and squad.scores[second] * SquadTactics.STICK >= squad.scores[best]:
			squad.target = second
			assert_str(tactics.choose(squad, belief)).is_equal(second)
			found = true
			break
	assert_bool(found).is_true()
	squad.target = "west home"
	squad.centre = Vector2(24, 15)
	assert_str(tactics.choose(squad, belief)).is_not_equal("west home")


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


func test_runners_focus_the_mortar_they_beat_before_a_shield_and_a_worker() -> void:
	var world := RtsWorld.new(GakGridGraph.new(20, 10), 1)
	for index: int in range(3):
		world.add_unit(RtsKinds.RUNNER, 0, Vector2i(5, 3 + index))
	var shield: RtsUnit = world.add_unit(RtsKinds.SHIELD, 1, Vector2i(8, 4))
	var mortar: RtsUnit = world.add_unit(RtsKinds.MORTAR, 1, Vector2i(9, 5))
	var worker: RtsUnit = world.add_unit(RtsKinds.WORKER, 1, Vector2i(7, 3))
	var view: RtsSnapshot = RtsSnapshot.of(world, 0)
	var scored: Array[Dictionary] = FocusFire.scores(view, view.mine(), Vector2(5.5, 4.5), Squad.NEAR)
	assert_int(scored[0]["id"]).is_equal(mortar.id)
	assert_str(Sentence.english(scored[0]["why"])).contains("we beat it")
	assert_int(scored[-1]["id"]).is_equal(worker.id)
	assert_bool(scored.any(func(entry: Dictionary) -> bool: return entry["id"] == shield.id)).is_true()


func test_a_member_that_struck_the_nearest_is_turned_to_the_squads_focus() -> void:
	var world := RtsWorld.new(GakGridGraph.new(20, 10), 1)
	var squad := Squad.new(1, 0)
	for index: int in range(3):
		squad.members.append(world.add_unit(RtsKinds.RUNNER, 0, Vector2i(5, 3 + index)).id)
	var worker: RtsUnit = world.add_unit(RtsKinds.WORKER, 1, Vector2i(6, 3))
	var mortar: RtsUnit = world.add_unit(RtsKinds.MORTAR, 1, Vector2i(9, 5))
	world.command(0, RtsCommand.attack([squad.members[0]] as Array[int], worker.id))
	var view: RtsSnapshot = RtsSnapshot.of(world, 0)
	squad.update(view)
	assert_str(squad.machine.current).is_equal(Squad.FIGHT)
	var given: Array[RtsCommand] = squad.commands(view)
	assert_int(given.size()).is_equal(1)
	assert_int(given[0].target_id).is_equal(mortar.id)
	assert_bool(squad.members[0] in given[0].unit_ids).is_true()


func test_a_trained_step_waits_for_its_producer_and_buys_a_squad() -> void:
	# Ore enough for everything at once, so only the barracks can hold the
	# runners back.
	var world: RtsWorld = RtsScenario.start(1)
	world.set_funds(RtsScenario.WEST, 2000)
	var view: RtsSnapshot = _with_workers_on_ore(world)
	var timed: Array[Dictionary] = BuildSchedule.of(PackedStringArray(["build_barracks", "train_runners"]), view)
	assert_float(timed[1]["starts"]).is_greater_equal(timed[0]["ready"])
	var runner_seconds: float = float(RtsKinds.of(RtsKinds.RUNNER, "ticks")) / RtsWorld.TICKS_PER_SECOND
	assert_float(timed[1]["ready"] - timed[1]["starts"]).is_equal_approx(runner_seconds * BuildOrder.SQUAD, 0.001)


func test_a_squad_falling_back_breaks_off_its_fight() -> void:
	var world := RtsWorld.new(RtsScenario.board(), 1)
	var squad := Squad.new(1, RtsScenario.WEST)
	for index: int in range(6):
		squad.members.append(world.add_unit(RtsKinds.RUNNER, 0, Vector2i(30 + index % 3, 10 + index / 3)).id)
	for index: int in range(12):
		world.add_unit(RtsKinds.SHIELD, 1, Vector2i(30 + index % 4, 13 + index / 4))
	var view: RtsSnapshot = RtsSnapshot.of(world, 0)
	squad.update(view)
	for command: RtsCommand in squad.commands(view):
		world.command(0, command)
	squad.machine.current = Squad.FIGHT
	view = RtsSnapshot.of(world, 0)
	squad.update(view)
	assert_str(squad.machine.current).is_equal(Squad.RETREAT)
	var given: Array[RtsCommand] = squad.commands(view)
	assert_int(given.size()).is_equal(1)
	assert_str(given[0].kind).is_equal(RtsCommand.MOVE)
	assert_int(given[0].unit_ids.size()).is_equal(6)


func test_the_focus_holds_until_another_scores_a_quarter_better() -> void:
	var world := RtsWorld.new(GakGridGraph.new(20, 10), 1)
	var squad := Squad.new(1, 0)
	for index: int in range(3):
		squad.members.append(world.add_unit(RtsKinds.SHIELD, 0, Vector2i(5, 3 + index)).id)
	var first: RtsUnit = world.add_unit(RtsKinds.RUNNER, 1, Vector2i(8, 4))
	var second: RtsUnit = world.add_unit(RtsKinds.RUNNER, 1, Vector2i(8, 5))
	var view: RtsSnapshot = RtsSnapshot.of(world, 0)
	squad.update(view)
	squad.commands(view)
	var chosen: int = squad.focus["id"]
	var other: RtsUnit = second if chosen == first.id else first
	# A little more hurt -- not a quarter better -- and the focus stays.
	other.health -= 5
	view = RtsSnapshot.of(world, 0)
	squad.update(view)
	squad.commands(view)
	assert_int(squad.focus["id"]).is_equal(chosen)
	other.health = 10
	view = RtsSnapshot.of(world, 0)
	squad.update(view)
	squad.commands(view)
	assert_int(squad.focus["id"]).is_equal(other.id)


func test_a_tower_arming_or_armed_holds_tower_armed_and_one_lost_does_not() -> void:
	var world: RtsWorld = RtsScenario.start(1)
	var home: Vector2i = RtsScenario.home(RtsScenario.WEST)
	var tower: RtsUnit = world.add_unit(RtsKinds.TOWER, RtsScenario.WEST, world.free_cell_near(home))
	world.set_funds(RtsScenario.WEST, 500, 500)
	assert_str(world.command(RtsScenario.WEST, RtsCommand.train(tower.id, RtsKinds.ARM))).is_empty()
	assert_bool("tower_armed" in BuildOrder.facts(RtsSnapshot.of(world, RtsScenario.WEST))).is_true()
	tower.queue.clear()
	tower.armed = true
	assert_bool("tower_armed" in BuildOrder.facts(RtsSnapshot.of(world, RtsScenario.WEST))).is_true()
	tower.health = 0
	world.step()
	assert_bool("tower_armed" in BuildOrder.facts(RtsSnapshot.of(world, RtsScenario.WEST))).is_false()


func test_both_planners_raise_a_tower_then_arm_it() -> void:
	var held := PackedStringArray(["supply_room", "workers_saturated", "magma_flowing"])
	for planner: BuildOrder.Planner in [BuildOrder.Planner.STRIPS, BuildOrder.Planner.HTN]:
		var found: Dictionary = BuildOrder.plan(held, PackedStringArray(["tower_armed"]), planner)
		assert_array(Array(found["steps"])).is_equal(["build_tower", "arm_tower"])


func test_the_schedule_times_the_arm_after_the_tower_stands() -> void:
	var world: RtsWorld = RtsScenario.start(1)
	world.set_funds(RtsScenario.WEST, 2000, 2000)
	var view: RtsSnapshot = _with_workers_on_ore(world)
	var timed: Array[Dictionary] = BuildSchedule.of(PackedStringArray(["build_tower", "arm_tower"]), view)
	assert_float(timed[1]["starts"]).is_equal(timed[0]["ready"])
	assert_str(timed[1]["waits"]).is_equal(RtsKinds.TOWER)
	var arm_seconds: float = float(RtsKinds.of(RtsKinds.ARM, "ticks")) / RtsWorld.TICKS_PER_SECOND
	assert_float(timed[1]["ready"] - timed[1]["starts"]).is_equal_approx(arm_seconds, 0.001)


func test_the_arm_is_weighed_by_the_raid_and_by_how_soon_help_comes() -> void:
	# A tower standing and funds to spare: only the raid and help change.
	var world: RtsWorld = StagedRaid.home_with_a_tower(1)
	var home: Vector2i = RtsScenario.home(RtsScenario.WEST)
	var raid: Array[RtsUnit] = StagedRaid.add(world, RtsScenario.EAST, RtsKinds.RUNNER, 4, home + StagedRaid.IN_REACH)
	var belief := RtsInfluence.new(48, 32)
	belief.update(RtsSnapshot.of(world, RtsScenario.WEST))
	assert_bool(TowerWorth.weigh(RtsSnapshot.of(world, RtsScenario.WEST), belief)["worth_it"]).is_true()
	# The same raid with its own shields standing at home: help is there.
	var guards: Array[RtsUnit] = StagedRaid.add(world, RtsScenario.WEST, RtsKinds.SHIELD, 4, home + Vector2i(1, -1))
	var weighed: Dictionary = TowerWorth.weigh(RtsSnapshot.of(world, RtsScenario.WEST), belief)
	assert_float(weighed["help"]).is_less(2.0)
	assert_bool(weighed["worth_it"]).is_false()
	# One scout, the shields gone: too little to pay for a gun.
	for unit: RtsUnit in guards + raid.slice(1):
		unit.health = 0
	world.step()
	var scout := RtsInfluence.new(48, 32)
	scout.update(RtsSnapshot.of(world, RtsScenario.WEST))
	assert_bool(TowerWorth.weigh(RtsSnapshot.of(world, RtsScenario.WEST), scout)["worth_it"]).is_false()


func test_a_raid_out_of_the_guns_reach_is_not_weighed() -> void:
	var world: RtsWorld = StagedRaid.home_with_a_tower(1)
	var home: Vector2i = RtsScenario.home(RtsScenario.WEST)
	StagedRaid.add(world, RtsScenario.EAST, RtsKinds.RUNNER, 4, home + StagedRaid.OUT_OF_REACH)
	var belief := RtsInfluence.new(48, 32)
	belief.update(RtsSnapshot.of(world, RtsScenario.WEST))
	var weighed: Dictionary = TowerWorth.weigh(RtsSnapshot.of(world, RtsScenario.WEST), belief)
	assert_float(weighed["raid"]).is_equal(0.0)
	assert_bool(weighed["worth_it"]).is_false()


func test_a_raid_lost_from_sight_is_weighed_less_as_it_fades() -> void:
	var world: RtsWorld = StagedRaid.home_with_a_tower(1)
	var home: Vector2i = RtsScenario.home(RtsScenario.WEST)
	var raid: Array[RtsUnit] = StagedRaid.add(world, RtsScenario.EAST, RtsKinds.RUNNER, 4, home + StagedRaid.IN_REACH)
	var belief := RtsInfluence.new(48, 32)
	belief.update(RtsSnapshot.of(world, RtsScenario.WEST))
	var seen: float = TowerWorth.weigh(RtsSnapshot.of(world, RtsScenario.WEST), belief)["raid"]
	for unit: RtsUnit in raid:
		world.place(unit, Vector2(40.5, 4.5))
	world.tick += RtsWorld.TICKS_PER_SECOND * 20
	belief.update(RtsSnapshot.of(world, RtsScenario.WEST))
	var remembered: float = TowerWorth.weigh(RtsSnapshot.of(world, RtsScenario.WEST), belief)["raid"]
	assert_float(remembered).is_greater(0.0)
	assert_float(remembered).is_less(seen * 0.6)


func test_raided_while_the_army_is_away_the_gun_stands_when_the_weighing_said() -> void:
	# What the weighing promises from the staged start, plus the first
	# decision's half second and a second's grace: a gun bought behind other
	# steps, as it once was, came some 25 s late.
	var start: RtsSnapshot = RtsSnapshot.of(StagedRaid.home_with_a_tower(1), RtsScenario.WEST)
	var promised: float = TowerWorth.gun_ready_in(start) + 1.5
	var played: RtsMatch = StagedRaid.play(StagedRaid.stage(1, 4, StagedRaid.IN_REACH, false), 1, StagedRaid.IN_REACH, true,
		ceili(promised))
	assert_int(StagedRaid.arms_by(played, RtsScenario.WEST)).is_equal(1)
	var towers: Array[Dictionary] = RtsSnapshot.of(played.world, RtsScenario.WEST).mine(RtsKinds.TOWER)
	assert_bool(towers[0]["armed"]).is_true()


func test_a_passing_scout_buys_no_arm() -> void:
	var played: RtsMatch = StagedRaid.play(StagedRaid.stage(1, 1, StagedRaid.IN_REACH, false), 1, StagedRaid.IN_REACH,
		true, 60)
	assert_int(StagedRaid.arms_by(played, RtsScenario.WEST)).is_equal(0)


func test_the_same_raid_met_by_its_squad_at_home_buys_no_arm() -> void:
	var played: RtsMatch = StagedRaid.play(StagedRaid.stage(1, 4, StagedRaid.IN_REACH, true), 1, StagedRaid.IN_REACH,
		true, 60)
	assert_int(StagedRaid.arms_by(played, RtsScenario.WEST)).is_equal(0)


func test_the_same_raid_out_of_the_guns_reach_buys_no_arm() -> void:
	var played: RtsMatch = StagedRaid.play(StagedRaid.stage(1, 4, StagedRaid.OUT_OF_REACH, false), 1,
		StagedRaid.OUT_OF_REACH, true, 60)
	assert_int(StagedRaid.arms_by(played, RtsScenario.WEST)).is_equal(0)


func test_no_goal_the_commander_sets_searches_past_the_gate() -> void:
	# Every set of the seven economy facts held, against every goal the
	# commander can set, at normal's horizon -- the search the game runs.
	var economy: Array[String] = ["supply_room", "workers_saturated", "magma_flowing", "barracks_up", "lab_up",
		"tower_up", "expansion_up"]
	var horizon: int = RtsLevels.named("normal").plan_horizon
	var goals: Array[PackedStringArray] = _every_goal_set()
	var worst: int = 0
	for question: int in range((1 << economy.size()) * goals.size()):
		var held: PackedStringArray = _the_ones_in(economy, question / goals.size())
		var found: Dictionary = BuildOrder.plan(held, goals[question % goals.size()], BuildOrder.Planner.STRIPS, horizon)
		worst = maxi(worst, found["visited"])
	assert_int(worst).is_less_equal(BuildOrder.WORST_VISITED)


func test_the_queues_arm_their_tower_while_raided_and_take_the_wish_back_after() -> void:
	var world: RtsWorld = RtsScenario.start(1)
	var home: Vector2i = RtsScenario.home(RtsScenario.WEST)
	world.add_unit(RtsKinds.BARRACKS, RtsScenario.WEST, home + Vector2i(0, -3))
	world.add_unit(RtsKinds.TOWER, RtsScenario.WEST, home + Vector2i(3, -3))
	var raider: RtsUnit = world.add_unit(RtsKinds.RUNNER, RtsScenario.EAST, home + Vector2i(4, 0))
	var queue := EconomyQueue.new(RtsScenario.WEST, 1)
	QueueSide.wish_by_rules(queue, RtsSnapshot.of(world, RtsScenario.WEST))
	assert_bool(queue.wishes.any(func(wish: Dictionary) -> bool: return wish["what"] == RtsKinds.ARM)).is_true()
	raider.health = 0
	world.step()
	QueueSide.wish_by_rules(queue, RtsSnapshot.of(world, RtsScenario.WEST))
	assert_bool(queue.wishes.any(func(wish: Dictionary) -> bool: return wish["what"] == RtsKinds.ARM)).is_false()


# Every goal `RtsCommander.goal` can return: workers, one army, and with
# or without the scouting tower and the expansion.
static func _every_goal_set() -> Array[PackedStringArray]:
	var goals: Array[PackedStringArray] = []
	for army: String in ["runners_ready", "shields_ready", "mortars_ready"]:
		for extra: int in range(4):
			var goal := PackedStringArray(["workers_saturated", army])
			goal.append_array(_the_ones_in(["tower_up", "expansion_up"] as Array[String], extra))
			goals.append(goal)
	return goals


# The facts of `facts` whose bits are set in `mask`.
static func _the_ones_in(facts: Array[String], mask: int) -> PackedStringArray:
	var held := PackedStringArray()
	for index: int in range(facts.size()):
		if mask & (1 << index):
			held.append(facts[index])
	return held


static func _runner_up(scores: Dictionary, best: String) -> String:
	var second: String = ""
	for region: String in scores:
		if region != best and (second == "" or scores[region] > scores[second]):
			second = region
	return second
