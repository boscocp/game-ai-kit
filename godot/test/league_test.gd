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
