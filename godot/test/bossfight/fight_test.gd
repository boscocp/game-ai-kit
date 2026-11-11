# The boss fight's promises over seeded, headless, scripted 60 s runs (T157):
# at most the pool's melee attackers at any step, every waiting minion gets
# a turn, no ranged minion fires while melee pressure is on, and the fight
# ends; and the fight's own: no ranged grant under pressure or inside the
# hold after it, no kind above its cap across waves, and an
# overlay that names real holders, queues and claims. Each is first shown a
# planted case it must reject: a fight that forgets to take the ranged
# token back, one whose hold is cut to nothing, one whose waves pile on,
# a minion that strikes without a token, a minion left waiting, an overlay
# that only ever says "none", and a fight nobody can finish. And: a fallen
# token holder gives its token back, a minion the rings refuse asks again,
# every overlay field holds something, a refused boss shows why.
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


# A fight that holds the ranged fire for no time at all.
class ShortHold:
	extends BossFight

	func _init(seed_value: int) -> void:
		super(BossFightRules.read(), BossTable.from_file(), seed_value)

	func hold_fire_seconds() -> float:
		return 0.0


# A fight whose waves add a whole wave on top of the living, past the cap.
class PilesOn:
	extends BossFight

	func _init(seed_value: int) -> void:
		super(BossFightRules.read(), BossTable.from_file(), seed_value)

	func _missing(kind: String) -> int:
		return rules.wave.get(kind, 0)


# A fight where nothing hurts the player: with a player that never swings,
# nobody falls.
class NobodyFalls:
	extends BossFight

	func _init(seed_value: int) -> void:
		super(BossFightRules.read(), BossTable.from_file(), seed_value)

	func _hurt_player(_amount: float, _by: String) -> bool:
		return false


func test_the_four_promises_hold_on_every_seed() -> void:
	var seen: Dictionary = {"strikes": 0, "revoked": 0, "fired": 0, "full": 0, "summons": 0, "after_hold": 0}
	for seed_value: int in SEEDS:
		var fight := BossFight.shipped(seed_value)
		var trace: Dictionary = Audit.new(seed_value).run(fight)
		assert_array(Audit.over_the_pool(trace)).override_failure_message("seed %d over the pool" % seed_value).is_empty()
		assert_array(Audit.left_waiting(trace)).override_failure_message("seed %d left waiting" % seed_value).is_empty()
		assert_array(Audit.fired_under_pressure(trace)).override_failure_message("seed %d fired under pressure" % seed_value).is_empty()
		assert_str(trace["ended"]).override_failure_message("seed %d did not end in 60 s" % seed_value).is_not_empty()
		_holds_the_fight_s_own(seed_value, fight, trace)
		_count(fight, trace, seen)
	# Not vacuous: the pool was full, melee struck, ranged fired, a ranged
	# token was taken back, a summon came, and a ranged grant came after a hold.
	for what: String in seen:
		assert_int(seen[what]).override_failure_message("never seen: " + what).is_greater(0)


func _holds_the_fight_s_own(seed_value: int, fight: BossFight, trace: Dictionary) -> void:
	var said: String = "seed %d: " % seed_value
	assert_array(Audit.granted_under_pressure(trace)).override_failure_message(said + "granted under pressure").is_empty()
	assert_array(Audit.granted_while_holding(fight)).override_failure_message(said + "granted in a hold").is_empty()
	assert_array(Audit.above_the_cap(fight, trace)).override_failure_message(said + "above the cap").is_empty()
	assert_array(Audit.never_named(trace)).override_failure_message(said + "overlay named nobody").is_empty()


func test_a_fight_that_cuts_its_hold_is_caught() -> void:
	var caught: int = 0
	for seed_value: int in SEEDS:
		var fight := ShortHold.new(seed_value)
		Audit.new(seed_value).run(fight)
		caught += Audit.granted_while_holding(fight).size()
	assert_int(caught).is_greater(0)


func test_a_wave_that_piles_on_is_caught() -> void:
	var caught: int = 0
	for seed_value: int in SEEDS:
		var fight := PilesOn.new(seed_value)
		caught += Audit.above_the_cap(fight, Audit.new(seed_value).run(fight)).size()
	assert_int(caught).is_greater(0)


func test_an_overlay_that_names_nobody_is_caught() -> void:
	assert_array(Audit.never_named({"shown": {}})).contains_exactly(["holders", "queue", "claims"])
	assert_array(Audit.never_named({"shown": {"holders": true, "queue": true}})).contains_exactly(["claims"])


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
	var revoked_in_all: int = 0
	for seed_value: int in SEEDS:
		var fight := BossFight.shipped(seed_value)
		Audit.new(seed_value).run(fight)
		var revoked: Array = fight.events.filter(func(event: Dictionary) -> bool: return event["what"] == "revoked")
		revoked_in_all += revoked.size()
		for event: Dictionary in revoked:
			assert_bool(str(event["who"]).begins_with(BossMinion.RANGED)).is_true()
			assert_array(_token_events(fight, event)).has_size(1)
	assert_int(revoked_in_all).is_greater(0)


# The pool's REVOKED events matching the fight's `event`, by who and when.
func _token_events(fight: BossFight, event: Dictionary) -> Array:
	return fight.tokens.events.filter(func(token_event: Dictionary) -> bool:
		return token_event["id"] == event["who"] and token_event["at"] == event["at"] and token_event["what"] == AttackTokens.REVOKED)


func test_a_minion_the_rings_refuse_asks_again_next_decision() -> void:
	var config := EngagementRings.Config.new()
	var ring := EngagementRings.Ring.new()
	ring.name = EngagementRings.WAITING
	ring.radius = 5.0
	ring.count = 1
	config.rings.append(ring)
	var rings := EngagementRings.new(config)
	var tokens := AttackTokens.new(BossFightRules.read().token_config())
	var minion := BossMinion.new(BossMinion.MELEE, 1, Vector2(0, 8))
	rings.choose(99, EngagementRings.WAITING, Vector2(0, 9), Vector2(0, -6), Vector2.DOWN)
	minion.decide(tokens, rings, Vector2(0, -6), Vector2.DOWN, 0.0)
	assert_int(minion.point).is_equal(-1)
	rings.release(99)
	minion.decide(tokens, rings, Vector2(0, -6), Vector2.DOWN, 0.25)
	assert_int(minion.point).is_equal(0)


func test_a_fallen_token_holder_gives_its_token_back() -> void:
	var fight := BossFight.shipped(1)
	var audit: RefCounted = Audit.new(1)
	var holder: BossMinion = null
	while fight.time < 30.0 and holder == null:
		fight.step(audit.intent_for(fight))
		holder = _melee_holder(fight)
	assert_object(holder).is_not_null()
	var held_before: int = fight.tokens.held(BossMinion.MELEE)
	assert_bool(holder.hurt(1.0, fight.tokens, fight.rings, fight.time)).is_true()
	assert_bool(holder.holds_token(fight.tokens)).is_false()
	assert_int(fight.tokens.held(BossMinion.MELEE)).is_equal(held_before - 1)
	assert_bool(holder.id in fight.tokens.waiting(BossMinion.MELEE)).is_false()
	assert_int(fight.rings.claim_of(holder.number)).is_equal(-1)


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
	seen["summons"] += trace["summons"]
	var hold: float = fight.tokens.delay_for(BossMinion.RANGED, BossFightRules.PRESSED)
	var grants: Array = Audit.ranged_grants(fight)
	for held: Dictionary in fight.events.filter(func(event: Dictionary) -> bool: return event["what"] == "held_fire"):
		seen["after_hold"] += grants.filter(func(grant: Dictionary) -> bool: return grant["at"] >= held["at"] + hold).size()


# A melee minion standing and holding a token, or null.
func _melee_holder(fight: BossFight) -> BossMinion:
	for minion: BossMinion in fight.minions:
		if minion.alive() and minion.kind == BossMinion.MELEE and minion.holds_token(fight.tokens):
			return minion
	return null


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
