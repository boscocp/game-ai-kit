# What the effects gate counts of falling back (T65), one promise at a
# time, and a place a teammate claimed is not claimed over. The counts are
# printed by botmatch_effects.gd and never claimed.
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


# Bot 0 alone, in the moving wave of its squad's retreat, at `place`.
static func _falling_back_at(world: BotMatch, place: Vector2) -> void:
	_only(world, [0])
	world.bots[0].position = place
	world.teams[0].squad_states[0] = SquadConfidence.RETREAT


func test_the_bands_are_health_tenths_and_three_exposures() -> void:
	assert_int(MatchFallBacks.band(0.0, 0.0)).is_equal(0)
	assert_int(MatchFallBacks.band(0.99, 1.0)).is_equal(9 * 3 + 2)
	assert_int(MatchFallBacks.band(1.0, 0.5)).is_equal(9 * 3 + 1)
	assert_int(MatchFallBacks.band(0.25, 0.2)).is_equal(2 * 3)


func test_a_fall_back_from_a_held_point_counts_when_the_point_is_lost_soon_after() -> void:
	var world: BotMatch = _world()
	world.point_owner[1] = 0
	_falling_back_at(world, world.arena.point_places[1] + Vector2(2.0, 0.0))
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
	world.point_owner[1] = 0
	_falling_back_at(world, world.arena.point_places[1])
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


func test_a_hiding_place_a_teammate_claimed_is_not_claimed_over() -> void:
	var world: BotMatch = _world()
	var team: MatchTeam = world.teams[0]
	team.claim(1, 0)
	var bot: MatchBot = world.bots[0]
	bot.errand = ErrandChoice.HIDE
	bot.hide_spot = 0
	bot.hide_place = world.place_position(0)
	TeamTactics._run_errand(world, team, bot)
	assert_str(bot.errand).is_equal(ErrandChoice.NONE)
	assert_int(int(team.claims[0])).is_equal(1)
	# Without claims, sharing a place is what the team does.
	team.use_claims = false
	bot.errand = ErrandChoice.HIDE
	TeamTactics._run_errand(world, team, bot)
	assert_int(int(team.claims[0])).is_equal(0)
