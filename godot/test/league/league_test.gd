# T25: the league's own pieces -- the schedule, the rating and the meter. The
# teams it fields are the tactical board's controllers, tested beside them in
# test/tactical/ (T63).
extends GdUnitTestSuite


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


func test_a_rating_fits_the_known_answer_for_two_teams() -> void:
	# 3 wins in 4, and the imaginary draw: 3.5 to 1.5, so the second is
	# 400 log10(1.5 / 3.5) from the first.
	var games: Array[Array] = [[0, 1, 1.0], [0, 1, 1.0], [1, 0, 0.0], [1, 0, 1.0]]

	assert_float(LeagueRating.fit(games, 2)[1]).is_equal_approx(400.0 * log(1.5 / 3.5) / log(10.0), 0.01)


func test_the_league_fields_the_board_s_controllers_with_only_the_hardest_level() -> void:
	# The league reads `TacticalRoster`, the table C cycles, rather than a
	# list of its own; a level plays at its strongest, as every team does.
	assert_array(League.names()).is_equal(["rules", "planner", "learned", "hard",
		"state machine", "behaviour tree", "GOAP", "HTN"])


static func _red_runner(state: BoardState) -> Unit:
	for unit: Unit in state.units_of(TacticalScenario.RED):
		if unit.type.type_name == TacticalRules.RUNNER:
			return unit
	return null
