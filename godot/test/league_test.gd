# T25: the league's pieces. The four teams from T15's techniques, each held
# to the claim its header makes -- and to the places they are documented to
# differ, since four teams that could never disagree would teach nothing;
# then the schedule, the rating and the meter.
extends GdUnitTestSuite


func test_the_state_machine_stays_a_defender_until_home_is_clear() -> void:
	var team := MachineTeam.new()
	var walker: Unit = _red_runner(TacticalScenario.build())

	assert_str(team.decide(walker, _facts({"home_threatened": true}))).is_equal(TechniqueTeam.DEFEND)
	# Home no longer threatened, but not yet clear, and a piece it beats in
	# reach: the machine waits for its arrow.
	assert_str(team.decide(walker, _facts({"prey_in_reach": true}))).is_equal(TechniqueTeam.DEFEND)
	assert_str(team.decide(walker, _facts({"home_clear": true, "prey_in_reach": true}))).is_equal(TechniqueTeam.SIEGE)
	assert_str(team.thinking(walker.id)).contains("defend -> advance: home is clear")


func test_the_tree_turns_hunter_the_moment_home_is_not_threatened() -> void:
	var team := TreeTeam.new()
	var walker: Unit = _red_runner(TacticalScenario.build())

	assert_str(team.decide(walker, _facts({"home_threatened": true}))).is_equal(TechniqueTeam.DEFEND)
	assert_str(team.decide(walker, _facts({"prey_in_reach": true}))).is_equal(TechniqueTeam.HUNT)


func test_the_htn_keeps_its_defend_step_until_its_effect_shows() -> void:
	var team := HtnTeam.new()
	var walker: Unit = _red_runner(TacticalScenario.build())

	assert_str(team.decide(walker, _facts({"home_threatened": true}))).is_equal(TechniqueTeam.DEFEND)
	assert_str(team.decide(walker, _facts({"prey_in_reach": true}))).is_equal(TechniqueTeam.DEFEND)
	# Home clear is defend's effect: the plan is done, and it plans again --
	# in one decision, where the machine took an arrow to advance first.
	assert_str(team.decide(walker, _facts({"home_clear": true, "prey_in_reach": true}))).is_equal(TechniqueTeam.HUNT)
	assert_str(team.thinking(walker.id)).contains("because the plan was done")


func test_the_htn_drops_its_plan_for_a_better_method_and_says_which() -> void:
	var team := HtnTeam.new()
	var walker: Unit = _red_runner(TacticalScenario.build())

	assert_str(team.decide(walker, _facts({"point_free": true}))).is_equal(TechniqueTeam.TAKE_POINT)
	assert_str(team.decide(walker, _facts({"point_free": true, "in_danger": true, "wounded": true}))).is_equal(TechniqueTeam.FALL_BACK)
	assert_str(team.thinking(walker.id)).contains("because save itself became possible")
	assert_int(team.replans()).is_equal(2)


func test_goap_takes_the_nearer_of_a_siege_and_a_point_where_the_tree_always_takes_the_point() -> void:
	var state: BoardState = TacticalScenario.build()
	var walker: Unit = _red_runner(state)
	# Three cells below blue's workshop at (12, 1), across the board from the
	# points: the siege is the cheaper pressure.
	walker.cell = Vector2i(12, 4)
	var near_their_workshop: TeamFacts = _facts_on(state, walker)
	assert_bool(near_their_workshop.facts["point_free"]).is_true()

	var goap := GoapTeam.new()
	goap.begin_turn(state)
	assert_str(goap.decide_move(state, walker.id).reason).starts_with(TechniqueTeam.SIEGE + " -- ")
	assert_str(TreeTeam.new().decide(walker, near_their_workshop)).is_equal(TechniqueTeam.TAKE_POINT)

	# Beside a point, the point is the cheaper, and GOAP and the tree agree.
	walker.cell = Vector2i(5, 1)
	goap.begin_turn(state)
	assert_str(goap.decide_move(state, walker.id).reason).starts_with(TechniqueTeam.TAKE_POINT + " -- ")


func test_goap_has_two_ways_to_a_safe_home_and_strikes_the_intruder_when_it_can() -> void:
	var actions: Array[GoapAction] = GoapTeam.new().actions_for(TacticalScenario.build(), _red_runner(TacticalScenario.build()), _facts({}))
	var facts: Dictionary = _facts({"home_threatened": true, "prey_in_reach": true, "prey_is_intruder": true}).facts
	var plan: BehaviourPlan = GoapPlanner.new().plan(actions, facts, GoapTeam.goal_for(facts))

	assert_array(plan.steps).is_equal([TechniqueTeam.HUNT])
	facts["prey_is_intruder"] = false
	assert_array(GoapPlanner.new().plan(actions, facts, GoapTeam.goal_for(facts)).steps).is_equal([TechniqueTeam.DEFEND])


func test_every_team_s_walk_is_one_the_board_takes() -> void:
	var state: BoardState = TacticalScenario.build()
	var walkers: Array[Unit] = state.units_of(state.current_faction).filter(func(unit: Unit) -> bool: return unit.type.mobile)
	for team: Array in League.roster():
		var controller: BlueController = (team[3] as Callable).call(0)
		controller.begin_turn(state)
		for unit: Unit in walkers:
			var move: Move = controller.choose(state, unit.id)
			var said: String = state.why_refused(move) if not move.path.is_empty() else BoardState.LEGAL
			assert_str(said).override_failure_message("%s's walk for unit %d: %s" % [team[0], unit.id, said]).is_equal(BoardState.LEGAL)


func test_the_schedule_plays_every_pairing_from_both_seats_on_dice_of_their_own() -> void:
	var games: Array[Array] = League.schedule(3, 2)

	assert_int(games.size()).is_equal(3 * 2 * 2)
	assert_bool(games.has([0, 1, 0]) and games.has([1, 0, League.SEAT_OFFSET])).is_true()
	assert_bool(games.has([2, 1, 1 + League.SEAT_OFFSET])).is_true()


func test_a_rating_ranks_by_results_and_keeps_a_clean_sweep_finite() -> void:
	var games: Array[Array] = []
	# 0 and 1 draw each other and both lose every game to 2: equal, by
	# symmetry, and 2 swept them.
	for _game: int in range(6):
		games.append([0, 1, 0.5])
		games.append([2, 0, 1.0])
		games.append([1, 2, 0.0])
	var ratings: Array[float] = LeagueRating.fit(games, 3)

	assert_float(ratings[0]).is_equal(0.0)
	assert_float(absf(ratings[1])).is_less(1.0)
	assert_float(ratings[2]).is_greater(100.0)
	assert_bool(is_finite(ratings[2])).is_true()


func test_a_rating_s_interval_holds_its_fit_and_is_the_same_every_time() -> void:
	var games: Array[Array] = []
	for game: int in range(10):
		games.append([0, 1, 1.0 if game % 3 != 0 else 0.0])
	var fitted: float = LeagueRating.fit(games, 2)[1]
	var interval: Array = LeagueRating.intervals(games, 2)[1]

	assert_float(fitted).is_between(interval[0], interval[1])
	assert_float(interval[1] - interval[0]).is_greater(0.0)
	assert_array(LeagueRating.intervals(games, 2)[1]).is_equal(interval)


func test_the_meter_charges_the_turn_s_planning_to_its_first_decision() -> void:
	var state: BoardState = TacticalScenario.build()
	var metered := MeteredTeam.new(PlannedBlue.new())
	metered.begin_turn(state)
	var workshop: Unit = TeamFacts.own_workshop(state, state.current_faction)
	metered.decide_build(state, workshop.id)
	metered.decide_move(state, _red_runner(state).id)

	assert_int(metered.decisions.size()).is_equal(2)
	assert_int(metered.decisions[0]["work"]).is_equal(metered.inner().work_done())
	assert_bool(metered.decisions[0]["replanned"]).is_true()
	assert_int(metered.decisions[1]["work"]).is_equal(0)
	assert_bool(metered.decisions[1]["replanned"]).is_false()


func test_home_is_threatened_inside_its_radius_and_clear_only_past_the_margin() -> void:
	var state: BoardState = TacticalScenario.build()
	var defender: Unit = _red_runner(state)
	var intruder: Unit = _first_of(state, TacticalScenario.BLUE, TacticalRules.RUNNER)
	var home := Vector2i(1, 7)
	intruder.cell = home + Vector2i(TeamFacts.HOME_RADIUS, 0)
	assert_bool(_facts_on(state, defender).facts["home_threatened"]).is_true()

	intruder.cell = home + Vector2i(TeamFacts.HOME_RADIUS + 1, 0)
	var between: TeamFacts = _facts_on(state, defender)
	assert_bool(between.facts["home_threatened"] or between.facts["home_clear"]).is_false()

	intruder.cell = home + Vector2i(TeamFacts.HOME_RADIUS + TeamFacts.CALM_MARGIN + 1, 0)
	assert_bool(_facts_on(state, defender).facts["home_clear"]).is_true()


func test_the_prey_is_the_weakest_piece_it_beats_in_reach() -> void:
	var state: BoardState = TacticalScenario.build()
	var hunter: Unit = _red_runner(state)
	hunter.cell = Vector2i(9, 4)
	var types: Dictionary = TacticalRules.unit_types()
	var strong := Unit.new(90, TacticalScenario.BLUE, Vector2i(10, 4), 8, 2, types[TacticalRules.MORTAR])
	var weak := Unit.new(91, TacticalScenario.BLUE, Vector2i(9, 5), 3, 2, types[TacticalRules.MORTAR])
	state.units.append_array([strong, weak])

	assert_int(_facts_on(state, hunter).prey.id).is_equal(weak.id)


func test_a_point_taken_by_anyone_else_or_claimed_is_not_free() -> void:
	var state: BoardState = TacticalScenario.build()
	var walker: Unit = _red_runner(state)
	walker.cell = Vector2i(5, 1)
	assert_vector(_facts_on(state, walker).point).is_equal(TacticalScenario.POINTS[0])

	var claimed: TeamFacts = TeamFacts.of(state, walker, {}, {TacticalScenario.POINTS[0]: 1}, true)
	assert_vector(claimed.point).is_equal(TacticalScenario.POINTS[1])
	_first_of(state, TacticalScenario.BLUE, TacticalRules.RUNNER).cell = TacticalScenario.POINTS[0]
	assert_vector(_facts_on(state, walker).point).is_equal(TacticalScenario.POINTS[1])


func test_a_walker_beside_an_enemy_held_point_is_not_left_standing() -> void:
	var state: BoardState = TacticalScenario.build()
	var walker: Unit = _red_runner(state)
	walker.cell = Vector2i(8, 7)
	state.units = state.units.filter(func(unit: Unit) -> bool: return unit.cell != TacticalScenario.POINTS[1])
	_first_of(state, TacticalScenario.BLUE, TacticalRules.RUNNER).cell = TacticalScenario.POINTS[1]
	for team: TechniqueTeam in [MachineTeam.new(), TreeTeam.new(), HtnTeam.new()]:
		team.begin_turn(state)
		var decision: TacticalDecision = team.decide_move(state, walker.id)
		assert_str(decision.kind()).override_failure_message(team.controller_name() + ": " + decision.reason).is_equal("move")


func test_the_tree_sieges_a_workshop_in_reach_before_it_hunts() -> void:
	var walker: Unit = _red_runner(TacticalScenario.build())
	var facts: TeamFacts = _facts({"at_their_workshop": true, "prey_in_reach": true, "point_free": true})

	assert_str(TreeTeam.new().decide(walker, facts)).is_equal(TechniqueTeam.SIEGE)


func test_falling_back_walks_where_the_fewest_that_beat_it_can_strike() -> void:
	var state: BoardState = TacticalScenario.build()
	var walker: Unit = _red_runner(state)
	walker.cell = Vector2i(9, 2)
	walker.health = 3
	var team := TreeTeam.new()
	team.begin_turn(state)
	var known: TeamFacts = _facts_on(state, walker)
	var decision: TacticalDecision = team._fall_back(state, walker, known)
	var chosen: int = team._strikers(state, walker, decision.target)

	for cell: Vector2i in known.walks:
		assert_int(chosen).override_failure_message("%s is struck by fewer" % cell).is_less_equal(team._strikers(state, walker, cell))
	assert_int(chosen).is_less(team._strikers(state, walker, walker.cell))


func test_beside_a_point_goap_prices_the_point_below_the_siege() -> void:
	var state: BoardState = TacticalScenario.build()
	var walker: Unit = _red_runner(state)
	walker.cell = Vector2i(5, 1)
	var prices: Dictionary = _prices(state, walker, _facts_on(state, walker))

	assert_int(prices[TechniqueTeam.TAKE_POINT]).is_less(prices[TechniqueTeam.SIEGE])


func test_at_equal_turns_goap_takes_the_point_over_the_siege() -> void:
	# A siege and a point carry the same fixed price, so where the walks are
	# as long the point wins the tie -- found by looking, not placed by hand.
	assert_int(GoapTeam.SIEGE_COST).is_equal(GoapTeam.POINT_COST)
	var state: BoardState = TacticalScenario.build()
	var walker: Unit = _red_runner(state)
	var tied: int = 0
	for cell: Vector2i in TacticalReach.route_costs(state.graph, walker.cell):
		if state.unit_at(cell) != null:
			continue
		walker.cell = cell
		var known: TeamFacts = _facts_on(state, walker)
		var prices: Dictionary = _prices(state, walker, known)
		if known.facts["point_free"] and not known.facts["prey_in_reach"] and prices[TechniqueTeam.TAKE_POINT] == prices[TechniqueTeam.SIEGE]:
			tied += 1
			var plan: BehaviourPlan = GoapPlanner.new().plan(GoapTeam.new().actions_for(state, walker, known), known.facts, {"pressure": true})
			assert_array(plan.steps).override_failure_message("at %s" % cell).is_equal([TechniqueTeam.TAKE_POINT])
	assert_int(tied).is_greater(0)


func test_a_rating_fits_the_known_answer_for_two_teams() -> void:
	# 3 wins in 4, and the imaginary draw: 3.5 to 1.5, so the second is
	# 400 log10(1.5 / 3.5) from the first.
	var games: Array[Array] = [[0, 1, 1.0], [0, 1, 1.0], [1, 0, 0.0], [1, 0, 1.0]]

	assert_float(LeagueRating.fit(games, 2)[1]).is_equal_approx(400.0 * log(1.5 / 3.5) / log(10.0), 0.01)


# Each deed's cheapest GOAP price for `walker`, by name.
static func _prices(state: BoardState, walker: Unit, known: TeamFacts) -> Dictionary:
	var prices: Dictionary = {}
	for action: GoapAction in GoapTeam.new().actions_for(state, walker, known):
		prices[action.name] = mini(prices.get(action.name, 1 << 30), action.cost)
	return prices


# Every fact false, then `given`.
static func _facts(given: Dictionary) -> TeamFacts:
	var known := TeamFacts.new()
	for name: String in ["home_threatened", "home_clear", "at_their_workshop", "way_to_their_workshop",
			"prey_in_reach", "in_danger", "wounded", "prey_is_intruder", "point_free"]:
		known.facts[name] = given.get(name, false)
	known.facts["way_to_their_workshop"] = given.get("way_to_their_workshop", true)
	return known


static func _facts_on(state: BoardState, unit: Unit) -> TeamFacts:
	return TeamFacts.of(state, unit, TeamFacts.enemy_strikes(state), {}, true)


static func _red_runner(state: BoardState) -> Unit:
	for unit: Unit in state.units_of(TacticalScenario.RED):
		if unit.type.type_name == TacticalRules.RUNNER:
			return unit
	return null


static func _first_of(state: BoardState, side: int, type_name: String) -> Unit:
	for unit: Unit in state.units_of(side):
		if unit.type.type_name == type_name:
			return unit
	return null
