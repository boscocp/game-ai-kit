# The boss fight's promises over seeded, headless, scripted 60 s runs (T157):
# at most the pool's melee attackers at any step, every waiting minion gets
# a turn, no ranged minion fires while melee pressure is on, and the fight
# ends. Each is first shown a planted case it must reject: a fight that
# forgets to take the ranged token back, a minion that strikes without a
# token, a minion left waiting, and a fight nobody can finish. And what the
# overlay promises: every field holds something, a refused boss shows why.
extends GdUnitTestSuite

const Audit: GDScript = preload("res://test/bossfight/fight_audit.gd")
const SEEDS: Array[int] = [1, 2, 3, 5, 8, 13, 21, 34]


# Takes the ranged token back from nobody: the planted fight the
# "never fires under pressure" check must catch.
class ForgetsToHoldFire:
	extends BossFight

	func _init(seed_value: int) -> void:
		super(BossFightRules.read(), BossTable.from_file(), seed_value)

	func _hold_fire() -> void:
		pressed = minions.any(func(minion: BossMinion) -> bool: return minion.state in BossMinion.PRESSING)


# A minion that believes it always holds a token.
class Tokenless:
	extends BossMinion

	func holds_token(_tokens: AttackTokens) -> bool:
		return true


# A fight whose melee minions strike without a token.
class StrikesWithoutToken:
	extends BossFight

	func _init(seed_value: int) -> void:
		super(BossFightRules.read(), BossTable.from_file(), seed_value)

	func _make_minion(kind: String, serial: int, at: Vector2) -> BossMinion:
		return Tokenless.new(kind, serial, at) if kind == BossMinion.MELEE else BossMinion.new(kind, serial, at)


# A fight where nothing hurts the player: with a player that never swings,
# nobody falls.
class NobodyFalls:
	extends BossFight

	func _init(seed_value: int) -> void:
		super(BossFightRules.read(), BossTable.from_file(), seed_value)

	func _hurt_player(_amount: float, _by: String) -> bool:
		return false


func test_the_four_promises_hold_on_every_seed() -> void:
	var seen: Dictionary = {"strikes": 0, "revoked": 0, "fired": 0, "full": 0}
	for seed_value: int in SEEDS:
		var fight := BossFight.shipped(seed_value)
		var trace: Dictionary = Audit.new(seed_value).run(fight)
		assert_array(Audit.over_the_pool(trace)).override_failure_message("seed %d over the pool" % seed_value).is_empty()
		assert_array(Audit.left_waiting(trace)).override_failure_message("seed %d left waiting" % seed_value).is_empty()
		assert_array(Audit.fired_under_pressure(trace)).override_failure_message("seed %d fired under pressure" % seed_value).is_empty()
		assert_str(trace["ended"]).override_failure_message("seed %d did not end in 60 s" % seed_value).is_not_empty()
		_count(fight, trace, seen)
	# Not vacuous: the pool was full, melee struck, ranged fired, and a
	# ranged token was taken back, somewhere in the runs.
	assert_int(seen["full"]).is_greater(0)
	assert_int(seen["strikes"]).is_greater(0)
	assert_int(seen["fired"]).is_greater(0)
	assert_int(seen["revoked"]).is_greater(0)


func test_a_fight_that_forgets_to_hold_fire_is_caught() -> void:
	var caught: int = 0
	for seed_value: int in SEEDS:
		caught += Audit.fired_under_pressure(Audit.new(seed_value).run(ForgetsToHoldFire.new(seed_value))).size()
	assert_int(caught).is_greater(0)


func test_a_minion_striking_without_a_token_is_caught() -> void:
	var trace: Dictionary = Audit.new(1).run(StrikesWithoutToken.new(1))
	assert_array(Audit.over_the_pool(trace)).is_not_empty()


func test_a_minion_left_waiting_is_caught() -> void:
	var trace: Dictionary = {"waits": {"melee-1": {"longest": 2.0}, "melee-9": {"longest": Audit.LONGEST_WAIT + 1.0}}, "granted": {}}
	var left: PackedStringArray = Audit.left_waiting(trace)
	assert_int(left.size()).is_equal(1)
	assert_str(left[0]).starts_with("melee-9")


func test_a_fight_nobody_can_finish_is_caught() -> void:
	var audit: RefCounted = Audit.new(1)
	audit.swings = false
	var trace: Dictionary = audit.run(NobodyFalls.new(1))
	assert_str(trace["ended"]).is_empty()
	assert_float(trace["lasted"]).is_greater_equal(Audit.SECONDS)


func test_the_same_seed_is_the_same_fight() -> void:
	var first: Dictionary = Audit.new(5).run(BossFight.shipped(5))
	var second: Dictionary = Audit.new(5).run(BossFight.shipped(5))
	assert_float(first["lasted"]).is_equal(second["lasted"])
	assert_str(first["ended"]).is_equal(second["ended"])
	assert_int(first["fired"]).is_equal(second["fired"])


func test_melee_on_the_player_takes_the_ranged_token_back() -> void:
	var fight := BossFight.shipped(3)
	Audit.new(3).run(fight)
	var revoked: Array = fight.events.filter(func(event: Dictionary) -> bool: return event["what"] == "revoked")
	assert_array(revoked).is_not_empty()
	for event: Dictionary in revoked:
		assert_bool(str(event["who"]).begins_with(BossMinion.MELEE)).is_false()
		var taken: Array = fight.tokens.events.filter(func(token_event: Dictionary) -> bool:
			return token_event["id"] == event["who"] and token_event["at"] == event["at"] and token_event["what"] == AttackTokens.REVOKED)
		assert_array(taken).has_size(1)


func test_the_overlay_holds_something_in_every_field() -> void:
	var fight := BossFight.shipped(2)
	var audit: RefCounted = Audit.new(2)
	for count: int in range(90):
		fight.step(audit.intent_for(fight))
	var shown: Dictionary = BossFightShown.overlay(fight)
	assert_array(_empty_fields(shown, "overlay")).is_empty()
	assert_int(shown["tokens"]["melee"]["pool"]).is_equal(2)
	assert_int(shown["rings"].size()).is_equal(3)
	assert_bool(shown["boss"].has("telegraph")).is_true()


func test_a_refused_boss_fights_no_one_and_says_why() -> void:
	var fight := BossFight.new(BossFightRules.read(), BossTable.from_data({}), 1)
	fight.step(BossFightIntent.new())
	assert_str(fight.refusal()).is_not_empty()
	assert_float(fight.time).is_equal(0.0)
	assert_str(BossFightShown.boss(fight)["phase"]).is_equal(BossFightShown.NONE)


func test_a_dead_minion_gives_back_its_token_and_its_point() -> void:
	var fight := BossFight.shipped(1)
	var audit: RefCounted = Audit.new(1)
	while fight.time < 30.0 and fight.events.filter(func(event: Dictionary) -> bool: return event["what"] == "down").is_empty():
		fight.step(audit.intent_for(fight))
	for minion: BossMinion in fight.minions:
		if not minion.alive():
			assert_bool(minion.holds_token(fight.tokens)).is_false()
			assert_int(fight.rings.claim_of(minion.number)).is_equal(-1)


func _count(fight: BossFight, trace: Dictionary, seen: Dictionary) -> void:
	for event: Dictionary in fight.events:
		if event["what"] == "struck":
			seen["strikes"] += 1
		elif event["what"] == "revoked":
			seen["revoked"] += 1
	seen["fired"] += trace["fired"]
	for sample: Dictionary in trace["loads"]:
		if sample["load"] == trace["pool"]:
			seen["full"] += 1


# Every path in `value` that holds nothing: an empty list, word or table.
func _empty_fields(value: Variant, path: String) -> PackedStringArray:
	var found := PackedStringArray()
	if value is Dictionary:
		if (value as Dictionary).is_empty():
			found.append(path)
		for key: Variant in value:
			found.append_array(_empty_fields(value[key], "%s.%s" % [path, key]))
	elif value is Array or value is PackedStringArray:
		if value.is_empty():
			found.append(path)
		for item: Variant in value:
			found.append_array(_empty_fields(item, path + "[]"))
	elif value is String and (value as String).is_empty():
		found.append(path)
	return found
