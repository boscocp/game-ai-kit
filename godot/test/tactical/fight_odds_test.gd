# T12's odds: what an attack is likely to do, worked out from the rules and
# the die. Held to the dice the board really rolls, and to never reading the
# board's next roll -- the cheat a lookahead falls into first.
extends GdUnitTestSuite

const SAMPLES: int = 20000
## How far the rolled share may sit from the worked-out chance: four times
## the standard error of 20000 samples at even odds, about 0.014.
const TOLERANCE: float = 0.015


func test_a_fight_between_walkers_wins_as_often_as_rolled_dice_do() -> void:
	for inputs: Dictionary in _fights():
		var worked_out: Array[float] = FightOdds.of(inputs, false)
		var rolled: Array[float] = _rolled(inputs, false)
		assert_float(worked_out[0]).is_equal_approx(rolled[0], TOLERANCE)
		assert_float(worked_out[1]).is_equal_approx(rolled[1], 10 * TOLERANCE)
		assert_float(worked_out[2]).is_equal_approx(rolled[2], 10 * TOLERANCE)


func test_a_siege_goes_as_rolled_dice_go() -> void:
	for inputs: Dictionary in _fights():
		var worked_out: Array[float] = FightOdds.of(inputs, true)
		var rolled: Array[float] = _rolled(inputs, true)
		assert_float(worked_out[0]).is_equal_approx(rolled[0], TOLERANCE)
		assert_float(worked_out[1]).is_equal_approx(rolled[1], 10 * TOLERANCE)
		assert_float(worked_out[2]).is_equal_approx(rolled[2], 10 * TOLERANCE)


func test_a_defender_that_cannot_hurt_and_dies_in_one_blow_is_a_certain_win() -> void:
	var inputs: Dictionary = _fights()[0].duplicate()
	inputs["defender_health"] = 1
	inputs["defender_hits_back"] = false

	assert_array(FightOdds.of(inputs, false)).is_equal([1.0, 10.0, 0.0])


func test_the_odds_of_an_attack_do_not_depend_on_the_boards_next_roll() -> void:
	var state: BoardState = TacticalScenario.build()
	var attacker: Unit = state.units_of(TacticalScenario.RED).filter(func(unit: Unit) -> bool: return unit.type.mobile)[0]
	var defender: Unit = state.units_of(TacticalScenario.BLUE).filter(func(unit: Unit) -> bool: return unit.type.mobile)[0]
	state.dice_seed = 1
	var one: Array[float] = FightOdds.of_attack(state, attacker, defender)
	state.dice_seed = 987654321

	assert_array(FightOdds.of_attack(state, attacker, defender)).is_equal(one)


# Four fights the board can produce: even, the attacker outnumbered in
# cover with a friend coming, the defender strong against it, and a mortar
# firing from out of the defender's reach, which takes rounds to win.
static func _fights() -> Array[Dictionary]:
	return [
		{"attacker_health": 10, "defender_health": 10, "numeric_advantage": 0, "defender_terrain": 1,
			"reinforcement_distance": 15, "counter": 0, "defender_hits_back": true},
		{"attacker_health": 6, "defender_health": 10, "numeric_advantage": -1, "defender_terrain": 3,
			"reinforcement_distance": 2, "counter": 1, "defender_hits_back": true},
		{"attacker_health": 10, "defender_health": 7, "numeric_advantage": 2, "defender_terrain": 1,
			"reinforcement_distance": 15, "counter": -1, "defender_hits_back": true},
		{"attacker_health": 4, "defender_health": 10, "numeric_advantage": 0, "defender_terrain": 2,
			"reinforcement_distance": 3, "counter": 0, "defender_hits_back": false},
	]


# [share won, attacker left on average, defender left on average] over
# `SAMPLES` fights rolled by `TacticalCombat` itself, with its own dice.
static func _rolled(inputs: Dictionary, siege: bool) -> Array[float]:
	var dice := RandomNumberGenerator.new()
	dice.seed = 12
	var die: Dictionary = TacticalCombat.rules()["die"]
	var roll: Callable = func() -> int: return dice.randi_range(die["lowest"], die["highest"])
	var total: Array[float] = [0.0, 0.0, 0.0]
	for sample: int in range(SAMPLES):
		var outcome: Dictionary = TacticalCombat.siege(inputs, roll) if siege else TacticalCombat.fight(inputs, roll)
		total[0] += 1.0 if outcome["attacker_won"] else 0.0
		total[1] += outcome["attacker_left"]
		total[2] += outcome["defender_left"]
	return [total[0] / SAMPLES, total[1] / SAMPLES, total[2] / SAMPLES]
