# The boss's promises over seeded headless fights (T156): every telegraph
# at least the table's minimum, no attack three times in a row in a phase,
# the phases entered in order and each once, a heavy attack with no minion
# striking, and the same seed giving the same fight. Each check is also
# shown a planted case it must reject: an attack with a zero telegraph, a
# phase whose health condition is never met, and a brain that forgot the
# "not a third time" filter.
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

	var _random := RandomNumberGenerator.new()
	var _distance: float = 6.0
	var _facing: float = 1.0
	var _fixed_distance: float = -1.0
	var _minion_since: Dictionary[String, float] = {}


	## The pool's numbers: timeouts longer than any attack, so a token never
	## runs out mid-swing.
	static func pools() -> Dictionary[String, int]:
		return {"melee": 2, "ranged": 1}


	static func token_config() -> AttackTokens.Config:
		var config := AttackTokens.Config.new()
		config.pools = pools()
		config.delays = {"melee": 0.3, "ranged": 1.0}
		config.timeouts = {"melee": 6.0, "ranged": 6.0}
		return config


	## A fight against `table`, seeded with `seed_value`; `brain_script` lets a
	## test plant a broken brain. A `fixed_distance` of 0 or more pins the player.
	func _init(table: BossTable, seed_value: int, brain_script: GDScript = BossBrain, fixed_distance: float = -1.0) -> void:
		_random.seed = seed_value
		_fixed_distance = fixed_distance
		tokens = AttackTokens.new(token_config())
		boss = brain_script.new(table, tokens, pools())


	## Fight until the boss falls or `seconds` pass; true when it fell.
	func run(seconds: float = LONGEST_FIGHT) -> bool:
		var now: float = 0.0
		while now < seconds and boss.state != BossBrain.DEFEATED:
			_move_player()
			boss.decide(now, _distance, _facing)
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


	func _watch_heavy(now: float) -> void:
		if not boss.heavy_underway():
			return
		var holders: PackedStringArray = tokens.holders("melee")
		if holders != PackedStringArray([BossBrain.ID]):
			heavy_overlaps.append({"at": now, "holders": holders})


	func _player_hits() -> void:
		if boss.state == BossBrain.RECOVERY and _random.randf() < 0.3:
			boss.take_damage(0.02)
		elif _random.randf() < 0.05:
			boss.take_damage(0.01)


# A brain without the filter the real one adds to every attack.
class ForgetsTheFilter:
	extends BossBrain

	func _init(table: BossTable, tokens: AttackTokens, pools: Dictionary[String, int]) -> void:
		super(table, tokens, pools)

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


func test_the_shipped_table_is_sound() -> void:
	var table: BossTable = _shipped()
	assert_str(table.refusal).is_empty()
	assert_int(table.phases.size()).is_greater_equal(2)
	for kind: String in Sim.token_config().timeouts:
		assert_float(Sim.token_config().timeouts[kind]).is_greater(table.longest_attack())


func test_every_seeded_fight_keeps_the_promises() -> void:
	var table: BossTable = _shipped()
	for seed_value: int in SEEDS:
		var sim: Sim = Sim.new(table, seed_value)
		assert_bool(sim.run()).override_failure_message("seed %d: the boss never fell" % seed_value).is_true()
		assert_int(sim.attacks().size()).is_greater(len(table.phases) * 2)
		assert_str(_why_short_telegraph(sim, table.minimum_telegraph)).is_empty()
		assert_str(_why_third_in_a_row(sim)).is_empty()
		assert_str(_why_phases_wrong(sim, table)).is_empty()
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


func test_a_hit_past_two_thresholds_still_enters_every_phase() -> void:
	var table: BossTable = _shipped()
	var sim: Sim = Sim.new(table, 3)
	sim.boss.decide(0.0, 3.0, 1.0)
	sim.boss.take_damage(0.9)
	for tick: int in range(1, 4):
		sim.boss.decide(tick * 0.1, 3.0, 1.0)
	sim.boss.take_damage(1.0)
	sim.boss.decide(0.5, 3.0, 1.0)
	assert_str(_why_phases_wrong(sim, table)).is_empty()
	assert_str(sim.boss.state).is_equal(BossBrain.DEFEATED)


func test_a_heavy_attack_takes_the_whole_melee_pool() -> void:
	var table: BossTable = _shipped()
	var sim: Sim = Sim.new(table, 2)
	sim.run()
	var heavies: int = 0
	for event: Dictionary in sim.attacks():
		if table.attacks[event["attack"]].heavy:
			heavies += 1
	assert_int(heavies).override_failure_message("no heavy attack was ever used").is_greater(0)
	assert_array(sim.heavy_overlaps).is_empty()


func test_the_panel_shows_the_decision() -> void:
	var table: BossTable = _shipped()
	var sim: Sim = Sim.new(table, 1, BossBrain, 1.0)
	var now: float = 0.0
	while sim.boss.state != BossBrain.TELEGRAPH and now < 5.0:
		sim.boss.decide(now, 1.0, 1.0)
		sim.tokens.step(now, "normal")
		now += 0.1
	var panel: BossPanel = auto_free(BossPanel.new())
	panel.show_boss(sim.boss.shown(now))
	assert_str(panel.heading.text).contains("stone").contains(sim.boss.attack)
	assert_int(panel.reasons.text.split("\n").size()).is_equal(table.phases[0].attacks.size())
	assert_str(panel.reasons.text).contains("repeats:" + sim.boss.attack)
	assert_str(" ".join(sim.boss.tree.trail)).contains("attack underway: success")


# --- the planted cases ------------------------------------------------------

func test_a_zero_telegraph_is_refused() -> void:
	var data: Dictionary = _shipped_data()
	data["attacks"]["swipe"]["telegraph"] = 0.0
	assert_str(BossTable.from_data(data).refusal).contains("swipe").contains("telegraph")
	# Shorter than the minimum only in the fastest phase is refused too.
	data = _shipped_data()
	data["attacks"]["sweep"]["telegraph"] = 0.5
	assert_str(BossTable.from_data(data).refusal).contains("molten").contains("sweep")


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
