# Falling back weighed (T65), one promise at a time: where it goes, what it
# weighs, the waves it keeps to, and what the gate counts. What it does to a
# match is botmatch_effects.gd's.
extends GdUnitTestSuite

var _locale_before: String


func before() -> void:
	_locale_before = TranslationServer.get_locale()
	TranslationServer.set_locale("en")


func after() -> void:
	TranslationServer.set_locale(_locale_before)


func _world() -> BotMatch:
	var rules := MatchRules.new()
	return BotMatch.new(1, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)


# Every bot but the ones in `keep` out of the match, so nobody else counts.
static func _only(world: BotMatch, keep: Array[int]) -> void:
	for bot: MatchBot in world.bots:
		if not (bot.id in keep):
			bot.respawn_left = INF


func test_the_chance_of_dying_is_read_from_the_measured_table() -> void:
	var rules := MatchRules.new()
	assert_bool(rules.dying.has("commit")).is_true()
	var chances: Array = rules.dying["chances"]
	assert_int(chances.size()).is_equal(MatchFallBacks.HEALTH_BANDS)
	assert_float(FallBackFacts.chance_of_dying(rules, 0.35, 1.0)).is_equal(float(chances[3][2]))
	assert_float(FallBackFacts.chance_of_dying(rules, 1.0, 0.0)).is_equal(float(chances[9][0]))
	assert_float(FallBackFacts.chance_of_dying(rules, 0.0, 0.4)).is_equal(float(chances[0][1]))
	rules.dying = {}
	assert_float(FallBackFacts.chance_of_dying(rules, 0.35, 1.0)).is_equal(0.0)


func test_the_bands_are_health_tenths_and_three_exposures() -> void:
	assert_int(MatchFallBacks.band(0.0, 0.0)).is_equal(0)
	assert_int(MatchFallBacks.band(0.99, 1.0)).is_equal(9 * 3 + 2)
	assert_int(MatchFallBacks.band(1.0, 0.5)).is_equal(9 * 3 + 1)
	assert_int(MatchFallBacks.band(0.25, 0.2)).is_equal(2 * 3)


func test_the_last_holder_near_an_enemy_prices_the_point_and_a_second_holder_does_not() -> void:
	var world: BotMatch = _world()
	var team: MatchTeam = world.teams[0]
	var point: int = 0
	var place: Vector2 = world.arena.point_places[point]
	_only(world, [0, 1])
	world.bots[0].position = place + Vector2(1.0, 0.0)
	world.point_progress[point] = 1.0
	world.point_owner[point] = 0
	team.remember(6, place + Vector2(8.0, 0.0), 0.0)
	assert_float(FallBackFacts.point_given_up(world, team, world.bots[0], point)).is_equal_approx(8.0, 1e-6)
	world.bots[1].respawn_left = 0.0
	world.bots[1].position = place + Vector2(-1.0, 0.0)
	assert_float(FallBackFacts.point_given_up(world, team, world.bots[0], point)).is_equal(0.0)
	# The second holder falling back leaves the first the last.
	world.bots[1].errand = ErrandChoice.FALL_BACK
	assert_float(FallBackFacts.point_given_up(world, team, world.bots[0], point)).is_equal_approx(8.0, 1e-6)


func test_nothing_is_given_up_with_no_enemy_near_or_from_afar() -> void:
	var world: BotMatch = _world()
	var team: MatchTeam = world.teams[0]
	var place: Vector2 = world.arena.point_places[0]
	_only(world, [0])
	world.point_progress[0] = 0.5
	world.bots[0].position = place
	assert_float(FallBackFacts.point_given_up(world, team, world.bots[0], 0)).is_equal(0.0)
	team.remember(6, place + Vector2(5.0, 0.0), 0.0)
	assert_float(FallBackFacts.point_given_up(world, team, world.bots[0], 0)).is_equal_approx(6.0, 1e-6)
	world.bots[0].position = place + Vector2(world.rules.area_radius + 1.0, 0.0)
	assert_float(FallBackFacts.point_given_up(world, team, world.bots[0], 0)).is_equal(0.0)


func test_a_team_that_does_not_retreat_weighs_no_fall_back() -> void:
	var world: BotMatch = _world()
	var team: MatchTeam = world.teams[0]
	team.may_retreat = false
	team.remember(6, world.bots[0].position + Vector2(5.0, 0.0), 0.0)
	world.bots[0].hurt_at = world.time
	world.bots[0].health = 40
	world.supply.think(world, team)
	assert_bool(world.bots[0].errand_weighing.has(ErrandChoice.FALL_BACK)).is_false()
	team.may_retreat = true
	team.bot_points[0] = 0
	world.supply.think(world, team)
	assert_bool(world.bots[0].errand_weighing.has(ErrandChoice.FALL_BACK)).is_true()


func test_a_squad_that_all_wants_to_fall_back_leaves_one_covering() -> void:
	var world: BotMatch = _world()
	var team: MatchTeam = world.teams[0]
	for bot_id: int in team.squads[0]:
		world.bots[bot_id].errand = ErrandChoice.FALL_BACK
	TeamTactics._keep_to_waves(world, team, 0, world.time)
	var falling: Array = team.squads[0].filter(func(bot_id: int) -> bool:
		return TeamTactics.moving_in_retreat(world, team, world.bots[bot_id]))
	assert_int(falling.size()).is_equal(1)
	var covering: int = team.squads[0][0] if falling[0] != team.squads[0][0] else team.squads[0][1]
	assert_bool(TeamTactics.covering_a_retreat(world, team, world.bots[covering])).is_true()
	# Planted: in one wave, nobody is left covering.
	for bot_id: int in team.squads[0]:
		world.bots[bot_id].errand = ErrandChoice.FALL_BACK
	team.retreat_in_one_wave = true
	TeamTactics._keep_to_waves(world, team, 0, world.time)
	assert_bool(team.squads[0].all(func(bot_id: int) -> bool:
		return TeamTactics.moving_in_retreat(world, team, world.bots[bot_id]))).is_true()


func test_the_waves_swap_when_the_movers_arrive_or_their_time_runs_out() -> void:
	var world: BotMatch = _world()
	var team: MatchTeam = world.teams[0]
	var squad: Array = team.squads[0]
	for bot_id: int in squad:
		world.bots[bot_id].errand = ErrandChoice.FALL_BACK
	TeamTactics._keep_to_waves(world, team, 0, 0.0)
	var first: int = squad.filter(func(bot_id: int) -> bool: return world.bots[bot_id].errand != "")[0]
	for bot_id: int in squad:
		world.bots[bot_id].errand = ErrandChoice.FALL_BACK
	TeamTactics._keep_to_waves(world, team, 0, world.rules.wave_timeout + 0.5)
	var second: int = squad.filter(func(bot_id: int) -> bool: return world.bots[bot_id].errand != "")[0]
	assert_int(second).is_not_equal(first)


func test_a_fall_back_from_a_held_point_counts_when_the_point_is_lost_soon_after() -> void:
	var world: BotMatch = _world()
	var place: Vector2 = world.arena.point_places[1]
	world.point_owner[1] = 0
	world.point_progress[1] = 1.0
	_only(world, [0])
	world.bots[0].position = place + Vector2(2.0, 0.0)
	world.bots[0].errand = ErrandChoice.FALL_BACK
	world.fall_back_counts.after_decision(world)
	var stats: MatchStats = world.stats[0]
	assert_int(stats.fall_backs).is_equal(1)
	assert_int(stats.fall_backs_held).is_equal(1)
	world.time += MatchFallBacks.LOST_WITHIN - 1.0
	world.fall_back_counts.neutralised(world, 0, 1)
	assert_int(stats.fall_backs_lost).is_equal(1)
	# Still falling back at the next decision: not a second fall-back.
	world.fall_back_counts.after_decision(world)
	assert_int(stats.fall_backs).is_equal(1)


func test_a_point_lost_long_after_is_not_the_fall_backs() -> void:
	var world: BotMatch = _world()
	var place: Vector2 = world.arena.point_places[1]
	world.point_owner[1] = 0
	_only(world, [0])
	world.bots[0].position = place
	world.bots[0].errand = ErrandChoice.FALL_BACK
	world.fall_back_counts.after_decision(world)
	world.time += MatchFallBacks.LOST_WITHIN + 1.0
	world.fall_back_counts.neutralised(world, 0, 1)
	assert_int(world.stats[0].fall_backs_lost).is_equal(0)


func test_dying_is_counted_in_the_band_the_bot_was_in() -> void:
	var world: BotMatch = _world()
	world.fall_back_counts.samples_dying = true
	_only(world, [0])
	world.bots[0].health = 35
	world.fall_back_counts.after_decision(world)
	var band: int = MatchFallBacks.band(0.35, 0.0)
	assert_float(world.stats[0].dying_samples[band]).is_equal(1.0)
	world.time += MatchFallBacks.DYING_WITHIN - 1.0
	world.killed(world.bots[0], -1)
	assert_float(world.stats[0].dying_deaths[band]).is_equal(1.0)


func test_the_panel_shows_the_fall_back_sum_term_by_term() -> void:
	var world: BotMatch = _world()
	var bot: MatchBot = world.bots[0]
	bot.fall_back_facts.available = true
	bot.fall_back_facts.hurt = 0.5
	bot.fall_back_facts.exposure = 1.0
	bot.errand_weighing[ErrandChoice.FALL_BACK] = PackedFloat64Array([0.6, 10.0, 0.0, 0.4])
	var line: String = BotMatchLines.fall_back_line(world, bot)
	assert_str(line).contains("health 0.50 x 1.00").contains("= 0.40")
	world.teams[0].may_retreat = false
	assert_str(BotMatchLines.fall_back_line(world, bot)).contains("retreat is off")


func test_a_place_a_teammate_claimed_is_not_claimed_over() -> void:
	var world: BotMatch = _world()
	var team: MatchTeam = world.teams[0]
	team.claim(1, 0)
	var bot: MatchBot = world.bots[0]
	bot.errand = ErrandChoice.FALL_BACK
	bot.fall_back_spot = 0
	bot.fall_back_place = world.place_position(0)
	TeamTactics._run_errand(world, team, bot)
	assert_str(bot.errand).is_equal(ErrandChoice.NONE)
	assert_int(int(team.claims[0])).is_equal(1)
	# Without claims, sharing a place is what the team does.
	team.use_claims = false
	bot.errand = ErrandChoice.FALL_BACK
	TeamTactics._run_errand(world, team, bot)
	assert_int(int(team.claims[0])).is_equal(0)


func test_bots_come_back_in_waves_the_wave_after_next() -> void:
	var rules := MatchRules.new()
	assert_float(rules.respawn_wait(13.0)).is_equal_approx(17.0, 1e-6)
	assert_float(rules.respawn_wait(20.0)).is_equal_approx(20.0, 1e-6)
	assert_float(rules.respawn_wait(29.5)).is_equal_approx(10.5, 1e-6)
