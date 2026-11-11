# The valley as a game (T165): the deeds it offers and keeps, the villagers
# who plan their day over the world's facts, and the three people whose
# manner reads the player's standing.
#
# What the task's decisions say a test holds:
#
#   * a deed that changes nothing is not offered and not kept: shutting
#     the gate that starts shut is refused, again and again, and the
#     standing does not move (T164's review, finding 4);
#   * a villager's decision receives the world's facts and nothing else --
#     its signature says so -- and decides the same beside any neighbours;
#   * the chain the screen shows: the bridge pulled down, the market out
#     of reach from the east, the bread baked at home instead, and A*'s
#     search to the barn; and the well that draws the west village;
#   * a manner sets only the consequences standing.json lists, and the
#     ferryman's price doubles at the fear the deeds sum to.
#
# Every save is the test's own, under user://tmp/.
extends GdUnitTestSuite

const SCRATCH: String = "user://tmp/valley_game_test/deeds.json"

var _rules: ValleyRules


func before_test() -> void:
	_rules = ValleyRules.new()
	ValleySave.new(SCRATCH).erase()


func after_test() -> void:
	ValleySave.new(SCRATCH).erase()


func test_shutting_the_shut_gate_is_neither_offered_nor_kept() -> void:
	var game := _game()
	var before: Dictionary = game.standing_now()
	assert_bool(game.world.fact("gate.open")).is_false()
	assert_array(ValleyShown.offered_shown(game)).not_contains(["close_gate gate"])
	for _farmed: int in range(5):
		assert_str(game.act("close_gate", "gate")).contains("changes nothing")
		game.next_day()
	assert_dict(game.standing_now()).is_equal(before)
	assert_int(game.record.size()).is_equal(0)
	assert_bool(FileAccess.file_exists(SCRATCH)).is_false()


func test_every_deed_offered_changes_a_fact_and_every_other_does_not() -> void:
	var game := _game()
	var offered: Array[Dictionary] = game.offered()
	assert_int(offered.size()).is_greater(3)
	for verb: String in _rules.verbs:
		for place: String in _rules.verbs[verb]:
			var deed: Dictionary = DeedLog.make(game.today, verb, place)
			assert_bool(deed in offered).is_equal(game.changes(deed))


func test_one_deed_a_day() -> void:
	var game := _game()
	assert_str(game.act("dig_well", "square")).is_empty()
	assert_array(game.offered()).is_empty()
	assert_str(game.act("burn", "barn")).contains("one deed a day")
	game.next_day()
	assert_str(game.act("burn", "barn")).is_empty()
	assert_int(game.record.size()).is_equal(2)


func test_a_villager_decides_from_the_facts_and_nothing_else() -> void:
	var villager: ValleyVillager = ValleyVillager.everyone()[0]
	for method_name: String in ["decide", "step"]:
		var found: Array = villager.get_method_list().filter(
			func(method: Dictionary) -> bool: return method["name"] == method_name)
		assert_int(found.size()).is_equal(1)
		var arguments: Array = found[0]["args"]
		assert_int(arguments.size()).is_equal(1)
		assert_str(arguments[0]["name"]).is_equal("facts")
		assert_int(arguments[0]["type"]).is_equal(TYPE_DICTIONARY)


func test_a_villager_decides_the_same_alone_or_among_others() -> void:
	var game := _game()
	var alone: ValleyVillager = ValleyVillager.everyone()[2]
	alone.decide(game.world.facts)
	var among: ValleyVillager = game.villagers[2]
	assert_str(alone.goal).is_equal(among.goal)
	assert_array(alone.plan).is_equal(among.plan)
	assert_array(alone.route).is_equal(among.route)


func test_the_bridge_down_sends_the_east_to_bake_its_own_bread() -> void:
	var game := _game()
	var ana: ValleyVillager = game.villagers[0]
	assert_array(ana.plans["bread"]).is_equal(["buy_bread"])
	assert_str(game.act("pull_down", "bridge")).is_empty()
	game.next_day()
	ana = game.villagers[0]
	assert_array(ana.plans["bread"]).is_equal(["take_wheat", "grind_wheat", "bake_bread"])
	assert_str(ana.heading).is_equal("barn")
	assert_bool(ana.search.reached).is_true()
	var links: Array[Dictionary] = ValleyShown.chain(game, ana)
	var kinds: Array = links.map(func(link: Dictionary) -> String: return str(link["link"]))
	assert_array(kinds).contains_exactly(["fact", "reach", "plan", "search"])
	assert_str(str(links[0]["fact"])).is_equal("bridge.standing")
	assert_str(str(links[0]["why"])).contains("pull_down the bridge")
	assert_array(links[1]["places"]).contains(["market"])


func test_a_new_well_draws_the_west_village() -> void:
	var game := _game()
	var elisa: ValleyVillager = game.villagers[4]
	assert_array(elisa.plans["water"]).is_equal(["draw_from_river"])
	assert_str(game.act("dig_well", "square")).is_empty()
	game.next_day()
	elisa = game.villagers[4]
	assert_array(elisa.plans["water"]).is_equal(["draw_from_well"])


func test_the_bridge_pulled_down_under_a_villager_strands_it_where_it_stands() -> void:
	var game := _game()
	var stranded: ValleyVillager = _east_villager_across(game)
	assert_object(stranded).override_failure_message("no east villager crossed the bridge on day 1").is_not_null()
	var crossing: Vector2i = ValleyMap.authored().cells_of("bridge")[0]
	assert_str(game.act("pull_down", "bridge")).is_empty()
	for _turn: int in range(game.day_turns - game.turn):
		game.step_turn()
		_assert_nobody_walks_the_gone_bridge(game, crossing)
	assert_int(stranded.cell.x).is_less(crossing.x)
	assert_int(int(stranded.walks[ValleyVillager.HOME])).is_equal(SearchResult.NO_ROUTE)


func test_the_walk_decides_who_bakes_and_who_buys() -> void:
	var game := _game()
	assert_str(game.act("build_footbridge", "ford")).is_empty()
	game.next_day()
	assert_str(game.act("pull_down", "bridge")).is_empty()
	game.next_day()
	var ana: ValleyVillager = game.villagers[0]
	var clara: ValleyVillager = game.villagers[2]
	assert_array(ana.plans["bread"]).is_equal(["take_wheat", "grind_wheat", "bake_bread"])
	assert_array(clara.plans["bread"]).is_equal(["buy_bread"])
	assert_int(ana.plan_cost(ana.plans["bread"])).is_less(ana.plan_cost(["buy_bread"] as Array[String]))
	assert_int(clara.plan_cost(clara.plans["bread"])).is_less(
		clara.plan_cost(["take_wheat", "grind_wheat", "bake_bread"] as Array[String]))


func test_the_dearer_plan_scores_less() -> void:
	var game := _game()
	var davi: ValleyVillager = game.villagers[3]
	var near: float = davi.scores["bread"]
	assert_str(game.act("pull_down", "bridge")).is_empty()
	var ana: ValleyVillager = game.villagers[0]
	assert_float(float(ana.scores["bread"])).is_less(near)
	assert_int(ana.plan_cost(ana.plans["bread"])).is_greater(davi.plan_cost(davi.plans["bread"]))


func test_the_keys_can_do_every_deed_the_valley_can_offer() -> void:
	# At most one deed a place can change anything: every two verbs on a
	# place set one of its facts to opposite values. So no day offers more
	# deeds than there are places, and there are keys for them all.
	var places: Array = []
	for verb: String in _rules.verbs:
		places.append_array((_rules.verbs[verb] as Dictionary).keys().filter(
			func(place: String) -> bool: return not place in places))
	assert_int(places.size()).is_less_equal(ValleyDemo.DEED_KEYS.size())
	for place: String in places:
		_assert_one_verb_at_a_time_changes(place)


# Every turn: no villager stands on a shut cell but the bridge it was on,
# and no route goes over the bridge that is gone.
func _assert_nobody_walks_the_gone_bridge(game: ValleyGame, crossing: Vector2i) -> void:
	for villager: ValleyVillager in game.villagers:
		var on_open_ground: bool = ValleyMap.authored().is_open(villager.cell, game.world.facts) or villager.cell == crossing
		assert_bool(on_open_ground).override_failure_message("%s walked onto %s" % [villager.name, villager.cell]).is_true()
		assert_bool(villager.route.has(crossing)).is_false()


# Any two verbs acting on `place` set one of its facts to opposite values.
func _assert_one_verb_at_a_time_changes(place: String) -> void:
	var acting: Array = _rules.verbs.keys().filter(func(verb: String) -> bool: return _rules.verbs[verb].has(place))
	for first: String in acting:
		for second: String in acting.filter(func(other: String) -> bool: return other != first):
			var opposed: bool = _opposed(_rules.verbs[first][place]["sets"], _rules.verbs[second][place]["sets"])
			assert_bool(opposed).override_failure_message("%s and %s both change the %s" % [first, second, place]).is_true()


func test_a_burnt_barn_leaves_nobody_a_plan_for_bread() -> void:
	var game := _game()
	assert_str(game.act("burn", "barn")).is_empty()
	game.next_day()
	for villager: ValleyVillager in game.villagers:
		assert_array(villager.plans["bread"]).is_empty()
		assert_str(villager.goal).is_not_equal("bread")


func test_a_manner_sets_only_the_consequences_standing_lists() -> void:
	var allowed: Array = Standing.new().consequences
	for manner: VillagerManner in VillagerManner.everyone():
		assert_array(allowed).contains([manner.consequence])
		assert_array(allowed).contains([VillagerManner.GREETING])
		var met: Dictionary = manner.meets({"care": 0, "fear": 0}, _rules.start)
		for key: String in met:
			assert_bool(key == "rule" or key in allowed).is_true()


func test_fear_doubles_the_ferrymans_price_and_names_its_deeds() -> void:
	var game := _game()
	assert_dict(_ferryman(game)).contains_key_value("sets", 4)
	assert_str(game.act("pull_down", "bridge")).is_empty()
	game.next_day()
	assert_str(game.act("burn", "barn")).is_empty()
	assert_int(int(game.standing_now()["fear"])).is_greater_equal(5)
	var ferryman: Dictionary = _ferryman(game)
	assert_int(int(ferryman["sets"])).is_equal(2 * int(ferryman["usual"]))
	assert_str(str(ferryman["virtue"])).is_equal("fear")
	assert_array(ferryman["deeds"]).is_equal([1, 2])


# A session on the test's own save, from the first day.
func _game() -> ValleyGame:
	return ValleyGame.new(ValleySave.new(SCRATCH))


# Turns of day 1 until a villager of the east village stands west of the
# bridge; that villager, or null when none did.
func _east_villager_across(game: ValleyGame) -> ValleyVillager:
	var crossing: int = ValleyMap.authored().cells_of("bridge")[0].x
	while game.turn < game.day_turns - 1:
		game.step_turn()
		var across: Array = game.villagers.filter(
			func(villager: ValleyVillager) -> bool: return villager.home.x > crossing and villager.cell.x < crossing)
		if not across.is_empty():
			return across[0]
	return null


# Whether two verbs' facts on one place disagree on some fact.
func _opposed(first: Dictionary, second: Dictionary) -> bool:
	for fact: String in first:
		if second.has(fact) and bool(second[fact]) != bool(first[fact]):
			return true
	return false


func _ferryman(game: ValleyGame) -> Dictionary:
	return ValleyShown.manners_shown(game, game.standing_now())[0]
