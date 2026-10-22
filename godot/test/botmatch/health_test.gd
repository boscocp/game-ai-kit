# Health that comes back, and healing weighed (T68), one promise at a time.
# What it does to a match is botmatch_effects.gd's.
extends GdUnitTestSuite


func _world() -> BotMatch:
	var rules := MatchRules.new()
	return BotMatch.new(1, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)


# Health of `bot` at each whole second after a hit at 0, for `seconds`.
static func _trace(rules: MatchRules, bot: MatchBot, seconds: int) -> Array[int]:
	var trace: Array[int] = []
	var now: float = 0.0
	for second: int in range(seconds):
		for step: int in range(roundi(1.0 / rules.step)):
			MatchHealth.regenerate(rules, bot, now, rules.step)
			now += rules.step
		trace.append(bot.health)
	return trace


func test_nothing_comes_back_before_the_delay_then_twenty_a_second_to_full() -> void:
	var world: BotMatch = _world()
	var bot: MatchBot = world.bots[0]
	bot.health = 30
	# Hit half a step before the clock starts, so no step falls on the
	# delay's edge and a float's last bit cannot move it.
	bot.hurt_at = -world.rules.step / 2.0
	var trace: Array[int] = _trace(world.rules, bot, 16)
	for second: int in range(10):
		assert_int(trace[second]).override_failure_message("at %d s" % (second + 1)).is_equal(30)
	assert_int(trace[10]).is_equal(50)
	assert_int(trace[11]).is_equal(70)
	assert_int(trace[15]).is_equal(world.rules.health)


func test_regeneration_never_passes_the_cap_nor_the_whole_health() -> void:
	var world: BotMatch = _world()
	var rules: MatchRules = world.rules
	var bot: MatchBot = world.bots[0]
	bot.health = 90
	bot.hurt_at = -100.0
	rules.regeneration_to = 95
	assert_int(_trace(rules, bot, 3).max()).is_equal(95)
	rules.regeneration_to = 500
	assert_int(_trace(rules, bot, 3).max()).is_equal(rules.health)


func test_a_hit_starts_the_clock_again_and_throws_the_fraction_away() -> void:
	var world: BotMatch = _world()
	var bot: MatchBot = world.bots[0]
	var enemy: MatchBot = world.bots[6]
	bot.health = 50
	bot.regeneration_carry = 0.7
	world.time = 30.0
	world.record_shot(enemy, bot.id, true, Vector3.ZERO, MatchRules.TORSO)
	assert_float(bot.hurt_at).is_equal(30.0)
	assert_float(bot.regeneration_carry).is_equal(0.0)
	assert_float(MatchHealth.delay_left(world.rules, bot, 34.0)).is_equal_approx(6.0, 1e-6)
	assert_float(MatchHealth.delay_left(world.rules, bot, 45.0)).is_equal(0.0)


func test_the_base_heals_whole_at_once_and_going_back_counts_the_health() -> void:
	var world: BotMatch = _world()
	var team: MatchTeam = world.teams[0]
	var bot: MatchBot = world.bots[0]
	bot.health = 25
	var facts: ErrandChoice.Resupply = world.supply.resupply_facts(world, team, bot)
	assert_float(facts.hurt).is_equal_approx(0.75, 1e-9)
	bot.hurt_at = world.time
	bot.position = world.arena.resupply["blue"]
	world.supply.touch(world, bot)
	assert_int(bot.health).is_equal(world.rules.health)
	assert_int(world.stats[0].healed_at_base).is_equal(75)
