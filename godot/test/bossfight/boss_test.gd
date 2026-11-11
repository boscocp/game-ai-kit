# The boss's promises over seeded headless fights (T156): every telegraph
# at least the table's minimum, no attack three times in a row in a phase,
# the phases entered in order and each once, a heavy attack with no minion
# striking, and the same seed giving the same fight; and what the brain
# promises besides: the three windows in order, faster tells per phase, the
# boss served first, a lost token calling the attack off, the fall giving
# the token back. Each check is also shown a planted case it must reject:
# a zero telegraph, active or recovery window, a phase whose health
# condition is never met or that does not start at full health, and a
# brain that forgot the "not a third time" filter.
extends GdUnitTestSuite

const SEEDS: Array[int] = [1, 2, 3, 5, 8, 13, 21, 34]


# A seeded, headless boss fight with a scripted player and two minions that
# keep asking for melee tokens. No scene: the brain, the token pool and the
# numbers a test reads. The player wanders, turns, and hits the boss now
# and then -- harder in the boss's recovery, the opening the windows give.
class Sim:
	extends RefCounted
	const STEP: float = 0.1
	const LONGEST_FIGHT: float = 600.0
	const MINIONS: Array[String] = ["minion_a", "minion_b"]
	const MINION_SWING: float = 1.0

	## The boss fought.
	var boss: BossBrain
	## The target's token pool, shared by the boss and the minions.
	var tokens: AttackTokens
	## Each moment a heavy attack ran while a minion held a melee token: {at, holders}.
	var heavy_overlaps: Array[Dictionary] = []
	## Seconds the fight lasted.
	var lasted: float = 0.0
	## The boss's state each time it changed, in order: the windows a test reads.
	var states: Array[String] = []
	## Steps in which the boss hurt.
	var hurting_steps: int = 0

	var _random := RandomNumberGenerator.new()
	var _distance: float = 6.0
	var _facing: float = 1.0
	var _fixed_distance: float = -1.0
	var _minion_since: Dictionary[String, float] = {}
	var _melee_pool: int = 2


	## The pool's numbers: timeouts longer than any attack, so a token never
	## runs out mid-swing.
	static func token_config(melee_pool: int = 2) -> AttackTokens.Config:
		var config := AttackTokens.Config.new()
		config.pools = {"melee": melee_pool, "ranged": 1}
		config.delays = {"melee": 0.3, "ranged": 1.0}
		config.timeouts = {"melee": 6.0, "ranged": 6.0}
		return config


	## A fight against `table`, seeded with `seed_value`; `brain_script` lets a
	## test plant a broken brain. A `fixed_distance` of 0 or more pins the player.
	func _init(table: BossTable, seed_value: int, brain_script: GDScript = BossBrain,
			fixed_distance: float = -1.0, melee_pool: int = 2) -> void:
		_random.seed = seed_value
		_fixed_distance = fixed_distance
		_melee_pool = melee_pool
		tokens = AttackTokens.new(token_config(melee_pool))
		boss = brain_script.new(table, tokens)


	## Fight until the boss falls or `seconds` pass; true when it fell.
	func run(seconds: float = LONGEST_FIGHT) -> bool:
		var now: float = 0.0
		while now < seconds and boss.state != BossBrain.DEFEATED:
			_move_player()
			boss.decide(now, _distance, _facing)
			_watch_windows()
			_minions_ask(now)
			tokens.step(now, "normal")
			_watch_heavy(now)
			_player_hits()
			now += STEP
		lasted = now
		return boss.state == BossBrain.DEFEATED


	## The attack events, in order.
	func attacks() -> Array[Dictionary]:
		var found: Array[Dictionary] = []
		for event: Dictionary in boss.events:
			if event["what"] == "attack":
				found.append(event)
		return found


	func _move_player() -> void:
		if _fixed_distance >= 0.0:
			_distance = _fixed_distance
			return
		_distance = clampf(_distance + _random.randf_range(-0.6, 0.6), 0.8, 12.0)
		if boss.state == BossBrain.CLOSING:
			_distance = maxf(0.8, _distance - 0.3)
		if _random.randf() < 0.1:
			_facing = _random.randf_range(-1.0, 1.0)


	# Each minion asks for a melee token, swings for MINION_SWING once granted,
	# and gives it back.
	func _minions_ask(now: float) -> void:
		for id: String in MINIONS:
			if not (id in tokens.holders("melee")):
				tokens.request(id, "melee", 1, 0, 2.0, now)
				continue
			_minion_since[id] = _minion_since.get(id, now)
			if now - _minion_since[id] >= MINION_SWING:
				tokens.release(id, AttackTokens.ENDED, now)
				_minion_since.erase(id)


	func _watch_windows() -> void:
		if states.is_empty() or states[-1] != boss.state:
			states.append(boss.state)
		if boss.hurts():
			hurting_steps += 1


	# A heavy attack must hold the whole melee pool, alone.
	func _watch_heavy(now: float) -> void:
		if not boss.heavy_underway():
			return
		var holders: PackedStringArray = tokens.holders("melee")
		if holders != PackedStringArray([BossBrain.ID]) or tokens.held("melee") != _melee_pool:
			heavy_overlaps.append({"at": now, "holders": holders, "held": tokens.held("melee")})


	func _player_hits() -> void:
		if boss.state == BossBrain.RECOVERY and _random.randf() < 0.3:
			boss.take_damage(0.02)
		elif _random.randf() < 0.05:
			boss.take_damage(0.01)


# A brain without the filter the real one adds to every attack.
class ForgetsTheFilter:
	extends BossBrain

	func _init(table: BossTable, tokens: AttackTokens) -> void:
		super(table, tokens)

	func _moveset_of(attack_names: PackedStringArray) -> Array[ActionChoice.Action]:
		var data: Array = []
		for attack_name: String in attack_names:
			var attack_data: BossTable.Blow = _table.attacks[attack_name]
			var entry: Dictionary = {"name": attack_name, "weight": attack_data.weight}
			entry["considerations"] = attack_data.considerations
			data.append(entry)
		return ActionChoice.actions_from(data)


func _shipped() -> BossTable:
	return BossTable.from_file()


func _shipped_data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(BossTable.FILE))


# The first telegraph under `minimum`, or "".
func _why_short_telegraph(sim: Sim, minimum: float) -> String:
	for event: Dictionary in sim.attacks():
		if event["telegraph"] < minimum - 1e-9:
			return "%s at %.1f s telegraphed for %.2f s" % [event["attack"], event["at"], event["telegraph"]]
	return ""


# The first attack used a third time in a row within one phase, or "".
func _why_third_in_a_row(sim: Sim) -> String:
	var run: int = 0
	var previous_key: String = ""
	for event: Dictionary in sim.attacks():
		var key: String = "%s in %s" % [event["attack"], event["phase"]]
		run = run + 1 if key == previous_key else 1
		previous_key = key
		if run > BossBrain.MOST_IN_A_ROW:
			return "%s a third time in a row in %s at %.1f s" % [event["attack"], event["phase"], event["at"]]
	return ""


# Whether the phases were entered in the table's order, each once: "" or why not.
func _why_phases_wrong(sim: Sim, table: BossTable) -> String:
	var entered: PackedStringArray = []
	for event: Dictionary in sim.boss.events:
		if event["what"] == "phase":
			entered.append(event["phase"])
	var expected: PackedStringArray = []
	for phase_data: BossTable.Phase in table.phases:
		expected.append(phase_data.name)
	return "" if entered == expected else "entered %s, expected %s" % [entered, expected]



# Whether every attack ran telegraph, active, recovery, in that order: "" or
# the first window out of place. A fall may cut an attack short.
func _why_windows_wrong(sim: Sim) -> String:
	var allowed: Dictionary = {
		BossBrain.TELEGRAPH: [BossBrain.ACTIVE, BossBrain.DEFEATED],
		BossBrain.ACTIVE: [BossBrain.RECOVERY, BossBrain.DEFEATED],
		BossBrain.RECOVERY: [BossBrain.TELEGRAPH, BossBrain.DEFEATED],
	}
	var windows: Array[String] = []
	for state: String in sim.states:
		if state in BossBrain.WINDOW_STATES or state == BossBrain.DEFEATED:
			windows.append(state)
	for index: int in range(windows.size() - 1):
		if windows[index] in allowed and not (windows[index + 1] in allowed[windows[index]]):
			return "%s followed by %s" % [windows[index], windows[index + 1]]
	return ""


# The first attack whose telegraph is not its phase's: the attack's own
# wind-up times the phase's scale, the "faster tells". "" when none.
func _why_tell_not_scaled(sim: Sim, table: BossTable) -> String:
	var index_of: Dictionary = {}
	for index: int in range(table.phases.size()):
		index_of[table.phases[index].name] = index
	for event: Dictionary in sim.attacks():
		var expected: float = table.telegraph_of(event["attack"], index_of[event["phase"]])
		if absf(event["telegraph"] - expected) > 1e-6:
			return "%s in %s: %.3f s, expected %.3f s" % [event["attack"], event["phase"], event["telegraph"], expected]
	return ""


# Phases with fewer than `fewest` attacks, by name; empty when none.
func _thin_phases(sim: Sim, table: BossTable, fewest: int) -> PackedStringArray:
	var counts: Dictionary = {}
	for event: Dictionary in sim.attacks():
		counts[event["phase"]] = counts.get(event["phase"], 0) + 1
	var thin: PackedStringArray = []
	for phase_data: BossTable.Phase in table.phases:
		if counts.get(phase_data.name, 0) < fewest:
			thin.append(phase_data.name)
	return thin


# The boss decides, then the pool steps, from `start` every 0.1 s for
# `ticks` ticks: the order a game runs them in.
func _step_fight(sim: Sim, start: float, ticks: int) -> float:
	var now: float = start
	for tick: int in range(ticks):
		sim.boss.decide(now, 1.0, 1.0)
		sim.tokens.step(now, "normal")
		now += 0.1
	return now


# The boss in its telegraph, at the time returned.
func _into_telegraph(sim: Sim) -> float:
	var now: float = 0.0
	while sim.boss.state != BossBrain.TELEGRAPH and now < 5.0:
		now = _step_fight(sim, now, 1)
	return now


func test_the_shipped_table_is_sound() -> void:
	var table: BossTable = _shipped()
	assert_str(table.refusal).is_empty()
	assert_int(table.phases.size()).is_greater_equal(2)
	for kind: String in Sim.token_config().timeouts:
		assert_float(Sim.token_config().timeouts[kind]).is_greater(table.longest_attack())


# Three attacks a phase at least, so "never three in a row" is a promise
# each phase had the chance to break.
func test_every_seeded_fight_keeps_the_promises() -> void:
	var table: BossTable = _shipped()
	for seed_value: int in SEEDS:
		var sim: Sim = Sim.new(table, seed_value)
		assert_bool(sim.run()).override_failure_message("seed %d: the boss never fell" % seed_value).is_true()
		assert_array(_thin_phases(sim, table, 3)).override_failure_message("seed %d" % seed_value).is_empty()
		assert_str(_why_short_telegraph(sim, table.minimum_telegraph)).is_empty()
		assert_str(_why_tell_not_scaled(sim, table)).is_empty()
		assert_str(_why_third_in_a_row(sim)).is_empty()
		assert_str(_why_phases_wrong(sim, table)).is_empty()
		assert_str(_why_windows_wrong(sim)).is_empty()
		assert_int(sim.hurting_steps).is_greater(0)
		assert_array(sim.heavy_overlaps).is_empty()


func test_the_same_seed_gives_the_same_fight() -> void:
	var table: BossTable = _shipped()
	var first: Sim = Sim.new(table, 7)
	var second: Sim = Sim.new(table, 7)
	var other: Sim = Sim.new(table, 8)
	first.run()
	second.run()
	other.run()
	assert_array(second.boss.events).is_equal(first.boss.events)
	# Not a comparison that could never fail: another seed is another fight.
	assert_array(other.boss.events).is_not_equal(first.boss.events)


# A hit to 10% during a stone swing, the pool stepped between decisions as
# a game does: the swing finishes, then cracked and molten are entered on
# consecutive decisions, with no attack in cracked between them.
func test_a_hit_past_two_thresholds_still_enters_every_phase() -> void:
	var table: BossTable = _shipped()
	var sim: Sim = Sim.new(table, 3)
	var now: float = _into_telegraph(sim)
	sim.boss.take_damage(0.9)
	now = _step_fight(sim, now, 50)
	assert_str(_why_phases_wrong(sim, table)).is_empty()
	var phases: Array[Dictionary] = []
	var between: Array[String] = []
	for event: Dictionary in sim.boss.events:
		if event["what"] == "phase":
			phases.append(event)
		elif phases.size() == 2:
			between.append(str(event))
	assert_float(phases[2]["at"] - phases[1]["at"]).is_equal_approx(0.1, 1e-6)
	assert_array(between).is_empty()
	# The stone swing under way when the hit landed ran to its end first.
	var swing: Dictionary = sim.attacks()[0]
	var blow: BossTable.Blow = table.attacks[swing["attack"]]
	assert_float(phases[1]["at"]).is_greater_equal(swing["at"] + swing["telegraph"] + blow.active + blow.recovery - 1e-6)
	sim.boss.take_damage(1.0)
	_step_fight(sim, now, 1)
	assert_str(sim.boss.state).is_equal(BossBrain.DEFEATED)


# How many heavy attacks the fight saw.
func _heavies(sim: Sim, table: BossTable) -> int:
	var count: int = 0
	for event: Dictionary in sim.attacks():
		if table.attacks[event["attack"]].heavy:
			count += 1
	return count


func test_a_heavy_attack_takes_the_whole_melee_pool() -> void:
	var table: BossTable = _shipped()
	# The pool's size is read from the pool: a bigger pool, a bigger cost.
	for melee_pool: int in [2, 3]:
		var sim: Sim = Sim.new(table, 2, BossBrain, -1.0, melee_pool)
		sim.run()
		assert_int(_heavies(sim, table)).override_failure_message("no heavy attack was ever used").is_greater(0)
		assert_array(sim.heavy_overlaps).is_empty()


func test_the_boss_is_served_before_a_waiting_minion() -> void:
	var sim: Sim = Sim.new(_shipped(), 1)
	sim.tokens.request("minion_a", "melee", 1, 0, 2.0, 0.0)
	sim.tokens.request("minion_b", "melee", 1, 0, 2.0, 0.0)
	sim.tokens.step(0.0, "normal")
	sim.tokens.step(0.3, "normal")
	sim.tokens.request("minion_c", "melee", 1, 0, 2.0, 0.4)
	sim.boss.decide(0.5, 1.0, 1.0)
	assert_str(sim.boss.state).is_equal(BossBrain.WAITING)
	sim.tokens.release("minion_a", AttackTokens.ENDED, 0.6)
	assert_array(Array(sim.tokens.step(0.6, "normal"))).is_equal([BossBrain.ID])


func test_a_lost_token_calls_the_attack_off() -> void:
	var sim: Sim = Sim.new(_shipped(), 1)
	var now: float = _into_telegraph(sim)
	sim.tokens.revoke_kind("melee", now)
	sim.boss.decide(now, 1.0, 1.0)
	assert_str(sim.boss.events[-1]["what"]).is_equal("called_off")
	assert_bool(sim.boss.hurts()).is_false()


func test_the_fall_gives_the_token_back() -> void:
	var sim: Sim = Sim.new(_shipped(), 1)
	var now: float = _into_telegraph(sim)
	sim.boss.take_damage(1.0)
	sim.boss.decide(now, 1.0, 1.0)
	assert_int(sim.tokens.held("melee")).is_equal(0)
	# Waiting, not holding: the fall leaves the queue too.
	var waiting: Sim = Sim.new(_shipped(), 1)
	waiting.tokens.request("minion_a", "melee", 2, 0, 2.0, 0.0)
	waiting.tokens.step(0.0, "normal")
	waiting.boss.decide(0.1, 1.0, 1.0)
	assert_array(Array(waiting.tokens.waiting("melee"))).contains([BossBrain.ID])
	waiting.boss.take_damage(1.0)
	waiting.boss.decide(0.2, 1.0, 1.0)
	assert_array(Array(waiting.tokens.waiting("melee"))).not_contains([BossBrain.ID])


func test_the_panel_shows_the_decision() -> void:
	var table: BossTable = _shipped()
	var sim: Sim = Sim.new(table, 1, BossBrain, 1.0)
	var now: float = _into_telegraph(sim)
	var panel: BossPanel = auto_free(BossPanel.new())
	panel.show_boss(sim.boss.shown(now))
	assert_str(panel.heading.text).contains("stone").contains(sim.boss.attack)
	assert_int(panel.reasons.text.split("\n").size()).is_equal(table.phases[0].attacks.size())
	assert_str(panel.reasons.text).contains("repeats:" + sim.boss.attack)
	assert_str(" ".join(sim.boss.tree.trail)).contains("attack underway: success")


func test_a_boss_that_cannot_fight_shows_why() -> void:
	var data: Dictionary = _shipped_data()
	data["attacks"]["swipe"]["active"] = 0.0
	var refused := BossBrain.new(BossTable.from_data(data), AttackTokens.new(Sim.token_config()))
	var seen: Dictionary = refused.shown(0.0)
	assert_str(seen["refusal"]).contains("active")
	var panel: BossPanel = auto_free(BossPanel.new())
	panel.show_boss(seen)
	assert_str(panel.heading.text).contains("active")
	# A pool without a kind the moveset uses is refused by name.
	var config: AttackTokens.Config = Sim.token_config()
	config.pools.erase("ranged")
	var no_ranged := BossBrain.new(_shipped(), AttackTokens.new(config))
	assert_str(no_ranged.refusal).contains("hurl").contains("no token pool")


# --- the planted cases ------------------------------------------------------

func test_a_zero_telegraph_is_refused() -> void:
	var data: Dictionary = _shipped_data()
	data["attacks"]["swipe"]["telegraph"] = 0.0
	assert_str(BossTable.from_data(data).refusal).contains("swipe").contains("telegraph")
	# Shorter than the minimum only in the fastest phase is refused too.
	data = _shipped_data()
	data["attacks"]["sweep"]["telegraph"] = 0.5
	assert_str(BossTable.from_data(data).refusal).contains("molten").contains("sweep")


func test_a_zero_active_or_recovery_window_is_refused() -> void:
	for window: String in ["active", "recovery"]:
		var data: Dictionary = _shipped_data()
		data["attacks"]["slam"][window] = 0.0
		assert_str(BossTable.from_data(data).refusal).contains("slam").contains("%s window" % window)


func test_a_zero_telegraph_slipped_past_the_table_is_caught_in_the_fight() -> void:
	var table: BossTable = _shipped()
	table.attacks["swipe"].telegraph = 0.0
	var sim: Sim = Sim.new(table, 1)
	sim.run()
	assert_str(_why_short_telegraph(sim, table.minimum_telegraph)).contains("swipe")


func test_a_phase_never_met_is_refused() -> void:
	var data: Dictionary = _shipped_data()
	data["phases"][2]["health_at_most"] = 0.0
	assert_str(BossTable.from_data(data).refusal).contains("molten").contains("never met")
	data = _shipped_data()
	data["phases"][2]["health_at_most"] = 0.7
	assert_str(BossTable.from_data(data).refusal).contains("molten").contains("not below")
	data = _shipped_data()
	data["phases"][0]["health_at_most"] = 0.9
	assert_str(BossTable.from_data(data).refusal).contains("stone").contains("full health")


func test_a_phase_never_met_slipped_past_the_table_is_caught_in_the_fight() -> void:
	var table: BossTable = _shipped()
	table.phases[2].health_at_most = 0.0
	var sim: Sim = Sim.new(table, 1)
	sim.run()
	assert_str(_why_phases_wrong(sim, table)).contains("expected")


func test_a_brain_without_the_filter_repeats_three_times() -> void:
	var table: BossTable = _shipped()
	var planted: Sim = Sim.new(table, 1, ForgetsTheFilter, 1.0)
	planted.run(30.0)
	assert_str(_why_third_in_a_row(planted)).contains("third time")
	# The real brain, at the same spot, keeps the rule.
	var kept: Sim = Sim.new(table, 1, BossBrain, 1.0)
	kept.run(30.0)
	assert_str(_why_third_in_a_row(kept)).is_empty()


# Waiting for a token in stone when a hit passes two thresholds: entering
# cracked drops the old request, so no token can arrive later and start a
# stone attack in a phase that has moved on.
func test_a_new_phase_drops_the_old_request() -> void:
	var sim: Sim = Sim.new(_shipped(), 1)
	sim.tokens.request("minion_a", "melee", 2, 0, 2.0, 0.0)
	sim.tokens.step(0.0, "normal")
	sim.boss.decide(0.1, 1.0, 1.0)
	assert_array(Array(sim.tokens.waiting("melee"))).contains([BossBrain.ID])
	sim.boss.take_damage(0.9)
	sim.boss.decide(0.2, 1.0, 1.0)
	assert_str(sim.boss.events[-1]["phase"]).is_equal("cracked")
	assert_array(Array(sim.tokens.waiting("melee"))).not_contains([BossBrain.ID])
