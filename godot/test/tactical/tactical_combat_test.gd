# T26: combat on the tactical board. Each case below is one line of T26's
# acceptance, or one rule `TacticalCombat` states in its header.
extends GdUnitTestSuite

const RED: int = TacticalScenario.RED
const BLUE: int = TacticalScenario.BLUE
const SEEDS: int = 400


func test_the_game_s_rules_are_the_spec_s_byte_for_byte() -> void:
	var spec: String = ProjectSettings.globalize_path("res://").path_join("../spec/combat/rules.json")
	assert_str(FileAccess.get_file_as_string(TacticalCombat.RULES_PATH)).is_equal(FileAccess.get_file_as_string(spec))


func test_an_attack_out_of_reach_is_refused() -> void:
	var state: BoardState = _duel(TacticalRules.RUNNER, TacticalRules.SHIELD, Vector2i(2, 0))

	assert_str(TacticalCombat.why_refused(state, Attack.new(1, 2))).contains("reaches 1")
	assert_object(TacticalCombat.apply(state, Attack.new(1, 2))).is_null()


func test_the_same_seed_gives_the_same_fight() -> void:
	var state: BoardState = _duel(TacticalRules.RUNNER, TacticalRules.SHIELD, Vector2i(1, 0))
	state.dice_seed = 1234

	var once: BoardState = TacticalCombat.apply(state, Attack.new(1, 2))
	var again: BoardState = TacticalCombat.apply(state, Attack.new(1, 2))

	assert_int(_health_of(once, 1)).is_equal(_health_of(again, 1))
	assert_int(_health_of(once, 2)).is_equal(_health_of(again, 2))
	assert_int(once.dice_seed).is_equal(again.dice_seed)
	assert_int(once.dice_seed).is_not_equal(state.dice_seed)


func test_strong_against_moves_the_odds_the_way_the_table_claims() -> void:
	# T26's manual check, as numbers: a runner sent at a mortar should usually
	# win, and the same runner sent at a shield should usually lose.
	var at_mortar: int = _attacker_wins(TacticalRules.RUNNER, TacticalRules.MORTAR)
	var at_shield: int = _attacker_wins(TacticalRules.RUNNER, TacticalRules.SHIELD)
	var at_runner: int = _attacker_wins(TacticalRules.RUNNER, TacticalRules.RUNNER)

	# Tilted, not decided: at counter_worth 2 it was 400 of 400 both ways.
	# Measured at 1 over these seeds: 122 against a shield; in Python's
	# 4000-fight probe, 94.4% favoured, 65.3% even, 27.7% disfavoured.
	assert_int(at_mortar).is_greater(SEEDS * 17 / 20)
	assert_int(at_mortar).is_less(SEEDS)
	assert_int(at_shield).is_between(SEEDS / 10, SEEDS * 2 / 5)
	assert_int(at_runner).is_between(at_shield, at_mortar)


func test_the_loser_is_removed_and_the_winner_keeps_what_it_has_left() -> void:
	var state: BoardState = _duel(TacticalRules.RUNNER, TacticalRules.MORTAR, Vector2i(1, 0))

	var after: BoardState = TacticalCombat.apply(state, Attack.new(1, 2))

	assert_int(after.units.size()).is_equal(1)
	var survivor: Unit = after.units[0]
	assert_int(survivor.health).is_between(1, 10)
	assert_int(after.unit_by_id(1).movement_points if after.unit_by_id(1) != null else 0).is_equal(0)


func test_a_mortar_firing_from_out_of_the_shield_s_reach_takes_nothing_back() -> void:
	var state: BoardState = _duel(TacticalRules.MORTAR, TacticalRules.SHIELD, Vector2i(3, 0))

	var inputs: Dictionary = TacticalCombat.inputs(state, state.unit_by_id(1), state.unit_by_id(2))

	assert_bool(inputs["defender_hits_back"]).is_false()
	assert_int(_health_of(TacticalCombat.apply(state, Attack.new(1, 2)), 1)).is_equal(10)


func test_the_counter_is_read_from_the_table_both_ways() -> void:
	var types: Dictionary = TacticalRules.unit_types()

	assert_int(TacticalCombat.counter(types[TacticalRules.RUNNER], types[TacticalRules.MORTAR])).is_equal(1)
	assert_int(TacticalCombat.counter(types[TacticalRules.RUNNER], types[TacticalRules.SHIELD])).is_equal(-1)
	assert_int(TacticalCombat.counter(types[TacticalRules.RUNNER], types[TacticalRules.RUNNER])).is_equal(0)


func test_a_bolt_tower_fires_at_the_start_of_its_side_s_turn_at_the_weakest_walker() -> void:
	var state: BoardState = TacticalScenario.build()
	var tower: Unit = _first_of(state, RED, TacticalRules.BOLT_TOWER)
	var near: Unit = _first_of(state, BLUE, TacticalRules.RUNNER)
	var weaker: Unit = _first_of(state, BLUE, TacticalRules.SHIELD)
	state.unit_by_id(near.id).cell = tower.cell + Vector2i(2, 0)
	state.unit_by_id(weaker.id).cell = tower.cell + Vector2i(0, -2)
	state.unit_by_id(weaker.id).health = 3

	var fired: Array = TacticalCombat.towers_fire(state)

	assert_int(fired[1].size()).is_equal(1)
	assert_str(fired[1][0]).contains("red bolt tower")
	assert_str(fired[1][0]).contains("blue shield")


func test_a_tower_does_not_fire_on_the_other_side_s_turn() -> void:
	var state: BoardState = TacticalScenario.build()
	var tower: Unit = _first_of(state, RED, TacticalRules.BOLT_TOWER)
	state.unit_by_id(_first_of(state, BLUE, TacticalRules.RUNNER).id).cell = tower.cell + Vector2i(1, 0)
	state = state.end_turn(TacticalScenario.FACTIONS, 0, TacticalRules.INCOME)

	var fired: Array = TacticalCombat.towers_fire(state)

	assert_array(fired[1]).is_empty()


func test_rule_based_blue_attacks_a_piece_it_beats_and_shows_it_first() -> void:
	var state: BoardState = TacticalScenario.build()
	var shield: Unit = _first_of(state, BLUE, TacticalRules.SHIELD)
	var runner: Unit = _first_of(state, RED, TacticalRules.RUNNER)
	state.unit_by_id(runner.id).cell = shield.cell + Vector2i(-1, 0)
	state = state.end_turn(TacticalScenario.FACTIONS, 0, TacticalRules.INCOME)

	var decision: TacticalDecision = RuleBasedBlue.new().decide_attack(state, shield.id)

	assert_str(decision.kind()).is_equal("attack")
	assert_int(decision.attack.target_id).is_equal(runner.id)
	assert_str(decision.reason).contains("a shield beats a runner")


func test_rule_based_blue_does_not_attack_what_it_does_not_beat() -> void:
	var state: BoardState = TacticalScenario.build()
	var runner: Unit = _first_of(state, BLUE, TacticalRules.RUNNER)
	var shield: Unit = _first_of(state, RED, TacticalRules.SHIELD)
	state.unit_by_id(shield.id).cell = runner.cell + Vector2i(-1, 0)
	state = state.end_turn(TacticalScenario.FACTIONS, 0, TacticalRules.INCOME)

	assert_object(RuleBasedBlue.new().decide_attack(state, runner.id)).is_null()


func test_blue_s_turn_shows_the_attack_before_it_plays_it() -> void:
	# Blue walks first and is asked about attacking from where the walk left
	# it. A runner already beside red's workshop has nowhere nearer to go, so
	# its walk is a hold and its attack is the workshop.
	var state: BoardState = TacticalScenario.build()
	state.unit_by_id(_first_of(state, BLUE, TacticalRules.RUNNER).id).cell = Vector2i(1, 6)
	state.unit_by_id(_first_of(state, RED, TacticalRules.WORKSHOP).id).health = 1
	state = state.end_turn(TacticalScenario.FACTIONS, 0, TacticalRules.INCOME)
	var turn := BlueTurn.new(RuleBasedBlue.new())
	turn.begin(state)

	var shown: Array[String] = []
	while not turn.finished():
		shown.append(turn.next.kind())
		state = turn.play(state)

	assert_array(shown).contains(["attack"])
	assert_array(turn.refused).is_empty()
	assert_int(TacticalVictory.winner(state)).is_equal(BLUE)


func test_a_red_unit_attacks_once_a_turn() -> void:
	# The target must survive the first attack, or the second has nothing to
	# be refused against -- the review's mutation passed because it did not.
	var scene: TacticalGame = _scene()
	var runner: Unit = _first_of(scene.state, RED, TacticalRules.RUNNER)
	var workshop: Vector2i = _first_of(scene.state, BLUE, TacticalRules.WORKSHOP).cell
	scene.state.unit_by_id(runner.id).cell = workshop + Vector2i(-1, 0)
	scene.click_cell(workshop + Vector2i(-1, 0))
	scene.click_cell(workshop)
	var after_one: int = scene.state.unit_at(workshop).health

	scene.click_cell(workshop + Vector2i(-1, 0))
	scene.click_cell(workshop)

	assert_int(after_one).is_less(TacticalRules.BUILDING_HEALTH)
	assert_int(scene.state.unit_at(workshop).health).is_equal(after_one)
	assert_str(scene._last_refusal).contains("has attacked")


func test_an_attack_cannot_be_taken_back() -> void:
	# Undo after a fight let a player read the dice and choose again.
	var scene: TacticalGame = _scene()
	var runner: Unit = _first_of(scene.state, RED, TacticalRules.RUNNER)
	# Walk one step left, so there is a move to take back, then attack a
	# mortar set down on the open cell beyond.
	var start: Vector2i = runner.cell
	scene.click_cell(start)
	scene.click_cell(start + Vector2i(-1, 0))
	scene.state.units.append(Unit.new(99, BLUE, start + Vector2i(-2, 0), 10, 0, TacticalRules.unit_types()[TacticalRules.MORTAR]))
	assert_bool(scene._turn.can_undo()).is_true()
	scene.click_cell(start + Vector2i(-1, 0))
	scene.click_cell(start + Vector2i(-2, 0))
	assert_str(scene._last_event).contains("runner")
	var fought: BoardState = scene.state

	scene.undo()

	assert_object(scene.state).is_same(fought)
	assert_bool(scene._turn.can_undo()).is_false()


func test_the_game_fires_a_side_s_towers_when_its_turn_starts() -> void:
	# Through the scene, not `towers_fire` alone: switching the call off in
	# the game passed every suite (the review).
	var scene: TacticalGame = _scene()
	var tower: Unit = _first_of(scene.state, BLUE, TacticalRules.BOLT_TOWER)
	var runner: Unit = _first_of(scene.state, RED, TacticalRules.RUNNER)
	scene.state.unit_by_id(runner.id).cell = tower.cell + Vector2i(-1, 0)

	scene.step_decision()

	assert_str(scene._last_event).contains("blue bolt tower")
	var hit: Unit = scene.state.unit_by_id(runner.id)
	assert_int(hit.health if hit != null else 0).is_less(10)


func test_a_tower_s_shot_is_one_exchange_and_never_kills_the_tower() -> void:
	# As a fight to the death, a shot at an adjacent ram killed the tower 81
	# times in 400.
	var destroyed: int = 0
	for dice: int in range(SEEDS):
		var state: BoardState = TacticalScenario.build()
		var tower: Unit = _first_of(state, RED, TacticalRules.BOLT_TOWER)
		var types: Dictionary = TacticalRules.unit_types()
		state.units.append(Unit.new(99, BLUE, tower.cell + Vector2i(1, 0), 10, 0, types[TacticalRules.RAM]))
		state.dice_seed = dice
		if TacticalCombat.towers_fire(state)[0].unit_by_id(tower.id) == null:
			destroyed += 1
	assert_int(destroyed).is_equal(0)


func test_red_reads_blue_s_attacks_when_its_turn_starts() -> void:
	# Enter played blue's attacks without showing them, and red's turn wiped
	# whatever had been shown.
	var scene: TacticalGame = _scene()
	var workshop: Unit = _first_of(scene.state, RED, TacticalRules.WORKSHOP)
	scene.state.unit_by_id(_first_of(scene.state, BLUE, TacticalRules.RUNNER).id).cell = workshop.cell + Vector2i(0, -1)
	scene.step_decision()

	scene.play_rest_of_computer_turn()

	assert_bool(scene._persons_turn()).is_true()
	assert_str((scene.get_node("Interface/Status") as Label).text).contains("blue's attacks:")


func _scene() -> TacticalGame:
	var scene: TacticalGame = auto_free((load("res://game/tactical/tactical.tscn") as PackedScene).instantiate())
	add_child(scene)
	return scene


func test_a_building_starts_with_more_health_than_a_walker() -> void:
	var state: BoardState = TacticalScenario.build()

	assert_int(_first_of(state, RED, TacticalRules.WORKSHOP).health).is_equal(TacticalRules.BUILDING_HEALTH)
	assert_int(_first_of(state, RED, TacticalRules.RUNNER).health).is_less(TacticalRules.BUILDING_HEALTH)


func test_an_attack_on_a_building_is_one_blow_not_a_fight_to_the_death() -> void:
	# The measurement behind it: with a workshop that fell to the first attack,
	# rules against rules ended every game in round 3.
	var state: BoardState = _duel(TacticalRules.RUNNER, TacticalRules.WORKSHOP, Vector2i(1, 0))
	state.unit_by_id(2).health = TacticalRules.BUILDING_HEALTH

	var after: BoardState = TacticalCombat.apply(state, Attack.new(1, 2))

	var left: int = after.unit_by_id(2).health
	assert_int(left).is_between(TacticalRules.BUILDING_HEALTH - 4, TacticalRules.BUILDING_HEALTH - 1)
	assert_int(after.unit_by_id(1).health).is_equal(10)


func test_a_ram_breaks_a_building_faster_than_a_runner() -> void:
	var by_ram: int = _siege_damage(TacticalRules.RAM)
	var by_runner: int = _siege_damage(TacticalRules.RUNNER)

	# The same dice, plus the counter's worth on every blow.
	assert_int(by_ram - by_runner).is_equal(SEEDS * int(TacticalCombat.rules()["counter_worth"]))


func test_a_siege_is_told_as_a_strike_not_a_kill() -> void:
	var state: BoardState = _duel(TacticalRules.RUNNER, TacticalRules.WORKSHOP, Vector2i(1, 0))
	state.unit_by_id(2).health = TacticalRules.BUILDING_HEALTH

	var told: String = TacticalCombat.told(state, Attack.new(1, 2), TacticalCombat.apply(state, Attack.new(1, 2)))

	assert_str(told).contains("struck")


# Damage dealt to a building over `SEEDS` single attacks by `attacker`.
func _siege_damage(attacker: String) -> int:
	var total: int = 0
	for dice: int in range(SEEDS):
		var state: BoardState = _duel(attacker, TacticalRules.WORKSHOP, Vector2i(1, 0))
		state.unit_by_id(2).health = 100
		state.dice_seed = dice
		total += 100 - TacticalCombat.apply(state, Attack.new(1, 2)).unit_by_id(2).health
	return total


# How many of `SEEDS` fights the attacker won, side by side on open ground.
func _attacker_wins(attacker: String, defender: String) -> int:
	var won: int = 0
	for dice: int in range(SEEDS):
		var state: BoardState = _duel(attacker, defender, Vector2i(1, 0))
		state.dice_seed = dice
		if TacticalCombat.apply(state, Attack.new(1, 2)).unit_by_id(2) == null:
			won += 1
	return won


# Red's `attacker` at (3, 3) and blue's `defender` at (3, 3) + `apart`, on open
# ground, red to move, nobody else on the board.
func _duel(attacker: String, defender: String, apart: Vector2i) -> BoardState:
	var types: Dictionary = TacticalRules.unit_types()
	var units: Array[Unit] = [
		Unit.new(1, RED, Vector2i(3, 3), 10, types[attacker].movement, types[attacker]),
		Unit.new(2, BLUE, Vector2i(3, 3) + apart, 10, types[defender].movement, types[defender]),
	]
	return BoardState.new(GridGraph.new(10, 8), units, RED)


func _health_of(state: BoardState, unit_id: int) -> int:
	var unit: Unit = state.unit_by_id(unit_id)
	return unit.health if unit != null else 0


func _first_of(state: BoardState, faction: int, type_name: String) -> Unit:
	for unit: Unit in state.units_of(faction):
		if unit.type.type_name == type_name:
			return unit
	return null
