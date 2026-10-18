# T11: the planner plays the tactical board. The bridge from board to
# predicates and back, and `PlannedBlue` carrying out a plan, replanning, and
# showing it.
extends GdUnitTestSuite

const SEEDS: int = 6


# --- the domain is data, and it is the spec's ---------------------------------

func test_the_game_s_domain_is_the_spec_s_byte_for_byte() -> void:
	var spec: String = ProjectSettings.globalize_path("res://").path_join("../spec/pddl/tactics.json")
	assert_str(FileAccess.get_file_as_string(TacticalPlanBridge.DOMAIN_PATH)).is_equal(FileAccess.get_file_as_string(spec))


func test_every_action_in_the_domain_is_one_the_bridge_can_carry_out() -> void:
	# A step the bridge does not know would be planned and never done.
	for action: StripsAction in TacticalPlanBridge.actions():
		assert_str(TacticalPlanBridge.asks(action.name)[0]).override_failure_message(action.name).is_not_empty()


func test_every_unit_type_a_step_names_is_one_the_workshop_builds() -> void:
	for action: StripsAction in TacticalPlanBridge.actions():
		var type_name: String = TacticalPlanBridge.asks(action.name)[1]
		if type_name != "":
			assert_bool(type_name in TacticalRules.BUILDABLE).override_failure_message(action.name).is_true()


# --- predicates out ----------------------------------------------------------

func test_blue_s_first_turn_reads_as_the_spec_s_opening_problem() -> void:
	# `spec/pddl/tactics-opening-problem.pddl` is this board, written by hand.
	var state: BoardState = _blues_first_turn()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TacticalPlanBridge.DOMAIN_PATH))

	assert_str(TacticalPlanBridge.world_of(state).key()).is_equal(WorldState.new(PackedStringArray(data["init"])).key())


func test_a_crossing_stays_open_while_one_of_the_three_is_clear() -> void:
	# The bridge and the two fords (T48): one of theirs on the bridge leaves
	# the fords, and only all three shut close the river to a walker.
	var state: BoardState = _blues_first_turn()
	var crossings: Array[Array] = TacticalPlanBridge.crossings()
	var on_the_bridge: BoardState = _moved(state, 4, TacticalRules.cells_of(TacticalScenario.MAP, TacticalRules.BRIDGE)[0])

	assert_int(crossings.size()).is_equal(3)
	assert_bool(TacticalPlanBridge.world_of(on_the_bridge).holds("crossing_open")).is_true()
	assert_bool(TacticalPlanBridge.world_of(_on_every_crossing(state)).holds("crossing_open")).is_false()


func test_a_walker_is_home_across_or_at_their_workshop_by_where_it_stands() -> void:
	var state: BoardState = _blues_first_turn()
	var theirs: Unit = TacticalPlanBridge.their_workshop(state)
	var runner: Unit = state.unit_by_id(9)

	assert_str(TacticalPlanBridge.zone_of(runner, theirs)).is_equal("home")
	assert_str(TacticalPlanBridge.zone_of(_moved(state, 9, Vector2i(4, 3)).unit_by_id(9), theirs)).is_equal("across")
	assert_str(TacticalPlanBridge.zone_of(_moved(state, 9, Vector2i(1, 6)).unit_by_id(9), theirs)).is_equal("at_their_workshop")


# --- the plan, carried out ---------------------------------------------------

func test_the_opening_plan_buys_the_forge_first_which_the_rules_never_do() -> void:
	var planner := PlannedBlue.new()
	var state: BoardState = _blues_first_turn()

	var decision: TacticalDecision = planner.decide_build(state, _workshop(state).id)

	assert_str(decision.kind()).is_equal("buy")
	assert_str(decision.reason).contains("plan step 1")
	assert_bool(planner.plan.solved).is_true()


func test_a_saved_turn_says_what_it_is_saving_for() -> void:
	var planner := PlannedBlue.new()
	var state: BoardState = _blues_first_turn()
	state = planner.decide_build(state, _workshop(state).id).played_on(state)

	var decision: TacticalDecision = planner.decide_build(state, _workshop(state).id)

	assert_str(decision.kind()).is_equal("hold")
	assert_str(decision.reason).contains("saves")
	assert_str(decision.reason).contains("ram")


func test_a_walker_no_step_names_is_the_rules_and_says_so() -> void:
	var planner := PlannedBlue.new()
	var state: BoardState = _blues_first_turn()

	assert_str(planner.decide_move(state, 9).reason).contains("the rules decide")


func test_shut_crossings_break_a_plan_that_crosses_and_the_reason_names_the_fact() -> void:
	var planner := PlannedBlue.new()
	var state: BoardState = _blues_first_turn()
	planner.decide_build(state, _workshop(state).id)
	var later: BoardState = _on_every_crossing(state)
	later.turn_number += TacticalScenario.FACTIONS

	planner.decide_build(later, _workshop(later).id)

	assert_str(planner.why_planned).contains("stopped running")
	assert_str(planner.why_planned).contains("crossing_open")


func test_it_replans_on_its_cadence_when_nothing_broke() -> void:
	var planner := PlannedBlue.new()
	var state: BoardState = _blues_first_turn()
	planner.decide_build(state, _workshop(state).id)
	var later: BoardState = state.duplicate_state()
	later.turn_number += PlannedBlue.REPLAN_EVERY * TacticalScenario.FACTIONS

	planner.decide_build(later, _workshop(later).id)

	assert_str(planner.why_planned).contains("%d of its turns" % PlannedBlue.REPLAN_EVERY)


func test_a_new_game_on_the_same_turn_number_forgets_the_old_plan() -> void:
	# The measuring scripts hand one controller game after game, and every
	# game's first blue turn has the same number.
	var planner := PlannedBlue.new()
	var state: BoardState = _blues_first_turn()
	planner.begin_turn(state)
	planner.why_planned = "by the test"

	planner.begin_turn(_blues_first_turn())

	assert_str(planner.why_planned).contains("start of the game")


func test_the_scene_swaps_blue_to_the_planner_and_shows_its_plan() -> void:
	var scene: TacticalGame = auto_free((load("res://game/tactical/tactical.tscn") as PackedScene).instantiate())
	add_child(scene)

	scene.swap_controller()
	scene.end_turn()
	scene.end_turn()

	assert_str(scene.blue.controller_name()).is_equal("planner")
	assert_array(scene.decision_overlay().get("plan", [])).is_not_empty()
	scene.swap_controller()
	assert_str(scene.blue.controller_name()).is_equal("learned")
	scene.swap_controller()
	assert_str(scene.blue.controller_name()).is_equal("rules")


func test_funds_banked_means_enough_for_the_forge_and_not_one_less() -> void:
	var state: BoardState = _blues_first_turn()
	state.funds[state.current_faction] = TacticalRules.FORGE_COST - 1
	assert_bool(TacticalPlanBridge.world_of(state).holds("funds_banked")).is_false()

	state.funds[state.current_faction] = TacticalRules.FORGE_COST
	assert_bool(TacticalPlanBridge.world_of(state).holds("funds_banked")).is_true()


func test_once_the_ram_is_bought_the_plan_is_at_the_crossing_and_buys_no_more() -> void:
	# The plan's place is the *latest* step the rest runs from. Taken as the
	# earliest, the forge and the ram are bought over and over -- a review
	# measured that mutation turn 13-7 into 0-20, and nothing else noticed.
	var planner := PlannedBlue.new()
	var state: BoardState = _blues_first_turn()
	planner.begin_turn(state)
	state = _with_a_ram_and_the_forge(state)

	var decision: TacticalDecision = planner.decide_build(state, _workshop(state).id)

	assert_str(planner.plan.steps[planner.next_step].name).is_equal("cross_the_river_ram")
	assert_str(decision.reason).contains("the plan buys nothing more")


func test_a_banking_step_is_skipped_when_the_next_purchase_can_be_paid_now() -> void:
	var planner := PlannedBlue.new()
	var state: BoardState = _blues_first_turn()
	state = planner.decide_build(state, _workshop(state).id).played_on(state)
	state.funds[state.current_faction] = 4

	var decision: TacticalDecision = planner.decide_build(state, _workshop(state).id)

	assert_str(decision.kind()).is_equal("build")
	assert_str(decision.order.unit_type.type_name).is_equal(TacticalRules.RAM)


func test_the_cadence_is_the_forge_and_ram_chain_in_turns_of_income() -> void:
	# The header's reason for the number, as arithmetic: change the prices or
	# the income and the interval has to be argued again.
	var ram: UnitType = TacticalRules.unit_types()[TacticalRules.RAM]
	var turns: int = ceili(float(TacticalRules.FORGE_COST + ram.cost) / TacticalRules.INCOME)

	assert_int(PlannedBlue.REPLAN_EVERY).is_equal(turns)


func test_it_keeps_its_plan_until_the_cadence_comes_round() -> void:
	var planner := PlannedBlue.new()
	var state: BoardState = _blues_first_turn()
	planner.begin_turn(state)
	var first: String = planner.why_planned

	for own_turns: int in range(1, PlannedBlue.REPLAN_EVERY):
		var later: BoardState = state.duplicate_state()
		later.turn_number += own_turns * TacticalScenario.FACTIONS
		planner.begin_turn(later)
		assert_str(planner.why_planned).override_failure_message("after %d turns" % own_turns).is_equal(first)


func test_a_walker_s_walk_is_the_rules_walk_and_only_its_reason_differs() -> void:
	# The header says the plan moves no walker the rules would not; this holds
	# it to that, so a claim that it does would have to change a test.
	var state: BoardState = _with_a_ram_and_the_forge(_blues_first_turn())
	var ram: Unit = state.units_of(state.current_faction).filter(func(unit: Unit) -> bool: return unit.type.type_name == TacticalRules.RAM)[0]

	var planned: TacticalDecision = PlannedBlue.new().decide_move(state, ram.id)
	var ruled: TacticalDecision = RuleBasedBlue.new().decide_move(state, ram.id)

	assert_str(planned.kind()).is_equal(ruled.kind())
	assert_that(planned.target).is_equal(ruled.target)
	assert_str(planned.reason).contains("cross_the_river_ram")


func test_a_partial_plan_is_played_without_a_refusal_and_replaced_when_done() -> void:
	# The game's budget never runs out on this domain, so this one is made to.
	var planner := PlannedBlue.new()
	planner.budget = 2
	var made: Array[String] = []
	var collect: Callable = func(_state: BoardState) -> void: made.append(planner.why_planned)

	var game: Dictionary = TacticalMatch.play(RuleBasedBlue.new(), planner, 0, collect)

	assert_array(game["refused"]).is_empty()
	assert_bool(made.any(func(why: String) -> bool: return why.contains("partial plan's steps were done"))).is_true()


func test_not_one_of_its_decisions_is_refused_from_either_seat() -> void:
	for dice: int in range(SEEDS):
		var as_blue: Dictionary = TacticalMatch.play(RuleBasedBlue.new(), PlannedBlue.new(), dice)
		var as_red: Dictionary = TacticalMatch.play(PlannedBlue.new(), RuleBasedBlue.new(), dice)
		assert_array(as_blue["refused"]).override_failure_message("seed %d, blue" % dice).is_empty()
		assert_array(as_red["refused"]).override_failure_message("seed %d, red" % dice).is_empty()


func test_the_plan_is_printed_and_marked_on_the_board() -> void:
	var planner := PlannedBlue.new()
	var state: BoardState = _blues_first_turn()
	planner.decide_build(state, _workshop(state).id)

	assert_str("\n".join(planner.plan_lines())).contains("buy_the_forge")
	assert_str(planner.plan_marks(state).get(_workshop(state).cell, "")).is_equal("1")


# --- helpers -------------------------------------------------------------------

func _blues_first_turn() -> BoardState:
	return TurnStart.open(TacticalScenario.build())[0]


func _workshop(state: BoardState) -> Unit:
	for unit: Unit in state.units_of(state.current_faction):
		if unit.type.type_name == TacticalRules.WORKSHOP:
			return unit
	return null


# `state` with the forge owned, a ram of the side to move's at home beside
# its workshop, and no funds to buy anything more.
func _with_a_ram_and_the_forge(state: BoardState) -> BoardState:
	var next: BoardState = state.buy(TacticalRules.forge())
	next.funds[next.current_faction] = 10
	var ram: UnitType = TacticalRules.unit_types()[TacticalRules.RAM]
	next = next.produce(ProductionOrder.new(_workshop(next).id, ram, TacticalRules.free_cell_beside(next, _workshop(next), ram)))
	next.funds[next.current_faction] = 0
	return next


# `state` with a red runner on one cell of every crossing.
func _on_every_crossing(state: BoardState) -> BoardState:
	var units: Array[Unit] = state.units.duplicate()
	var runner: UnitType = TacticalRules.unit_types()[TacticalRules.RUNNER]
	for crossing: Array in TacticalPlanBridge.crossings():
		units.append(Unit.new(200 + units.size(), TacticalScenario.RED, crossing[0], 10, runner.movement, runner))
	var shut := BoardState.new(state.graph, units, state.current_faction, state.turn_number)
	shut.movement_graphs = state.movement_graphs
	shut.funds = state.funds.duplicate()
	return shut


# `state` with unit `unit_id` set down on `cell` -- a board
# arranged for a test, not a walk.
func _moved(state: BoardState, unit_id: int, cell: Vector2i) -> BoardState:
	var next: BoardState = state.duplicate_state()
	next.unit_by_id(unit_id).cell = cell
	return next.duplicate_state()
