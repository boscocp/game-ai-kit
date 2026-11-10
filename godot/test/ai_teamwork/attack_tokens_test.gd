# AttackTokens' promises over random fights, and the planted pools each
# check must reject: one that leaks, one whose tokens never time out, one
# that breaks a tie by the order a dictionary stored the requests in, and
# one with no patience, that starves the low.
extends GdUnitTestSuite

const TRIALS: int = 60
const STEPS: int = 80
const FIGHTERS: int = 6


# A pool that grants without counting: the free count never goes down.
class LeakyTokens:
	extends AttackTokens

	func _init(config: AttackTokens.Config) -> void:
		super(config)

	func _take(_kind: String, _cost: int) -> void:
		pass


# A pool whose safety net is gone: a holder that forgets keeps its token.
class NeverTimesOut:
	extends AttackTokens

	func _init(config: AttackTokens.Config) -> void:
		super(config)

	func _time_out(_now: float) -> void:
		pass


# A pool that breaks a tie by the order it stored the requests in.
class DictionaryOrder:
	extends AttackTokens

	func _init(config: AttackTokens.Config) -> void:
		super(config)

	func _tie(id: String) -> int:
		return _waiting.keys().find(id)


func _config(patience: int = 3, tie_seed: int = 7) -> AttackTokens.Config:
	var config := AttackTokens.Config.new()
	config.pools = {"melee": 2, "ranged": 1}
	config.delays = {"melee": 0.5, "ranged": 2.0}
	config.timeouts = {"melee": 4.0, "ranged": 6.0}
	config.multipliers = {"busy": {"ranged": 2.0}, "idle": {"melee": 0.5, "ranged": 0.5}}
	config.patience = patience
	config.tie_seed = tie_seed
	return config


# Why `pool` broke its pool, or "": what is held, counted from the holders,
# plus what is free must be the pool, and never more than it.
func _why_broken(pool: AttackTokens, config: AttackTokens.Config) -> String:
	for kind: String in config.pools:
		var held: int = pool.held(kind)
		if held > config.pools[kind] or held + pool.free_tokens(kind) != config.pools[kind]:
			return "%s: %d held, %d free, pool %d" % [kind, held, pool.free_tokens(kind), config.pools[kind]]
	return ""


# A random fight of FIGHTERS against one target, STEPS steps of 0.25 s:
# each asks, ends, dies or forgets at random. The first broken promise,
# or "". `served` gets, per grant, how many grants of its kind went to
# others while it waited -- counted here, from the grants, not by the pool.
func _fight(pool: AttackTokens, config: AttackTokens.Config, seed_value: int, served: Array[int]) -> String:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var passes: Dictionary = {}
	for tick: int in range(STEPS):
		var now: float = tick * 0.25
		_act_at_random(pool, random, now, passes)
		var state: String = ["busy", "idle", "normal"][random.randi_range(0, 2)]
		for id: String in pool.step(now, state):
			_count_a_grant(pool, id, passes, served)
		var why: String = _why_broken(pool, config)
		if why != "":
			return "step %d: %s" % [tick, why]
	return ""


func _act_at_random(pool: AttackTokens, random: RandomNumberGenerator, now: float, passes: Dictionary) -> void:
	for fighter: int in range(FIGHTERS):
		var id: String = "f%d" % fighter
		var kind: String = "ranged" if fighter >= 4 else "melee"
		var roll: float = random.randf()
		if roll < 0.3 and _ask(pool, random, id, kind, now):
			passes[id] = passes.get(id, 0)
		elif roll < 0.4:
			pool.release(id, AttackTokens.ENDED, now)
		elif roll < 0.42:
			pool.release(id, AttackTokens.DIED, now)
			passes.erase(id)


# `id` asks at a random cost, priority and distance; whether it now waits.
func _ask(pool: AttackTokens, random: RandomNumberGenerator, id: String, kind: String, now: float) -> bool:
	var cost: int = random.randi_range(1, 2) if kind == "melee" else 1
	var priority: int = random.randi_range(0, 3)
	var distance: float = random.randf_range(1.0, 20.0)
	return pool.request(id, kind, cost, priority, distance, now) == AttackTokens.WAITING


# `id` was granted: its own count is done, and every other waiter of its
# kind was passed over once more.
func _count_a_grant(pool: AttackTokens, id: String, passes: Dictionary, served: Array[int]) -> void:
	served.append(passes.get(id, 0))
	passes.erase(id)
	var kind: String = "ranged" if int(id.substr(1)) >= 4 else "melee"
	for other: String in pool.waiting(kind):
		passes[other] = passes.get(other, 0) + 1


func test_never_more_held_than_the_pool_over_random_fights() -> void:
	for trial: int in range(TRIALS):
		var config: AttackTokens.Config = _config()
		var served: Array[int] = []
		assert_str(_fight(AttackTokens.new(config), config, trial, served)).is_equal("")


func test_a_pool_that_leaks_is_caught() -> void:
	var config: AttackTokens.Config = _config()
	var served: Array[int] = []
	assert_str(_fight(LeakyTokens.new(config), config, 1, served)).is_not_equal("")


func test_every_requester_is_served_within_patience_and_those_ahead() -> void:
	# Before it is patient, `patience` grants go past it; after, only the
	# patient who asked no later than it, at most FIGHTERS - 1 of them.
	for trial: int in range(TRIALS):
		var config: AttackTokens.Config = _config()
		var served: Array[int] = []
		_fight(AttackTokens.new(config), config, 100 + trial, served)
		assert_int(served.size()).is_greater(0)
		assert_int(served.max()).is_less_equal(config.patience + FIGHTERS - 1)


# One melee token, a low requester, and high ones asking one after the
# other: how many grants went past the low one before it was served.
func _passes_before_the_low_one(config: AttackTokens.Config) -> int:
	config.pools = {"melee": 1}
	var pool := AttackTokens.new(config)
	pool.request("low", "melee", 1, 0, 1.0, 0.0)
	for turn: int in range(12):
		var now: float = turn * 1.0
		pool.request("high%d" % turn, "melee", 1, 3, 5.0, now)
		var granted: PackedStringArray = pool.step(now, "normal")
		if "low" in granted:
			return turn
		pool.release(granted[0], AttackTokens.ENDED, now + 0.5)
	return 12


func test_patience_is_what_stops_the_low_from_starving() -> void:
	assert_int(_passes_before_the_low_one(_config(3))).is_equal(3)
	assert_int(_passes_before_the_low_one(_config(1000))).is_greater(3 + FIGHTERS)


func test_a_cost_above_the_pool_is_refused_not_queued() -> void:
	var pool := AttackTokens.new(_config())
	assert_str(pool.request("giant", "melee", 3, 9, 1.0, 0.0)).is_equal(AttackTokens.REFUSED_COST)
	assert_str(pool.request("ghost", "magic", 1, 0, 1.0, 0.0)).is_equal(AttackTokens.REFUSED_KIND)
	assert_array(Array(pool.waiting("melee"))).is_empty()
	assert_array(Array(pool.step(0.0, "normal"))).is_empty()


func test_a_revoked_token_is_free_on_the_same_step() -> void:
	var pool := AttackTokens.new(_config())
	pool.request("archer", "ranged", 1, 0, 20.0, 0.0)
	pool.step(0.0, "normal")
	assert_int(pool.free_tokens("ranged")).is_equal(0)
	assert_array(Array(pool.revoke_kind("ranged", 2.0))).contains_exactly(["archer"])
	assert_int(pool.free_tokens("ranged")).is_equal(1)
	pool.request("other", "ranged", 1, 0, 20.0, 2.0)
	assert_array(Array(pool.step(2.0, "busy"))).contains_exactly(["other"])


func test_a_holder_that_dies_frees_its_token_on_the_same_step() -> void:
	var pool := AttackTokens.new(_config())
	pool.request("m1", "melee", 2, 0, 1.0, 0.0)
	pool.step(0.0, "normal")
	assert_int(pool.free_tokens("melee")).is_equal(0)
	assert_bool(pool.release("m1", AttackTokens.DIED, 0.1)).is_true()
	assert_int(pool.free_tokens("melee")).is_equal(2)


# Whether `pool`'s holder that never releases still holds after its timeout.
func _forgetful_holder_keeps_it(pool: AttackTokens) -> bool:
	pool.request("forgetful", "melee", 1, 0, 1.0, 0.0)
	pool.step(0.0, "normal")
	pool.step(4.0, "normal")
	return "forgetful" in pool.holders("melee")


func test_a_token_never_released_comes_back_by_timeout() -> void:
	assert_bool(_forgetful_holder_keeps_it(AttackTokens.new(_config()))).is_false()
	assert_bool(_forgetful_holder_keeps_it(NeverTimesOut.new(_config()))).is_true()


func test_the_same_seed_gives_the_same_grants() -> void:
	var first := AttackTokens.new(_config())
	var second := AttackTokens.new(_config())
	var served: Array[int] = []
	_fight(first, _config(), 5, served)
	_fight(second, _config(), 5, served)
	assert_int(first.events.size()).is_greater(0)
	assert_str(str(first.events)).is_equal(str(second.events))


# The winner of two requests equal in every fact, asked in `order`.
func _winner(pool: AttackTokens, order: Array[String]) -> String:
	for id: String in order:
		pool.request(id, "melee", 2, 0, 5.0, 0.0)
	return pool.step(0.0, "normal")[0]


func test_a_tie_goes_by_the_seed_not_by_the_order_stored() -> void:
	var winners: Dictionary = {}
	for tie_seed: int in range(8):
		var one: String = _winner(AttackTokens.new(_config(3, tie_seed)), ["left", "right"])
		var other: String = _winner(AttackTokens.new(_config(3, tie_seed)), ["right", "left"])
		assert_str(one).is_equal(other)
		winners[one] = true
	assert_int(winners.size()).is_equal(2)
	var planted_one: String = _winner(DictionaryOrder.new(_config()), ["left", "right"])
	var planted_other: String = _winner(DictionaryOrder.new(_config()), ["right", "left"])
	assert_str(planted_one).is_not_equal(planted_other)


func test_the_hash_is_the_one_python_computes() -> void:
	# FNV-1a's published value for "a", so both languages share one hash.
	assert_int(AttackTokens.fnv1a("a")).is_equal(0xE40C292C)
