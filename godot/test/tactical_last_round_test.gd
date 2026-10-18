# T47: the last round decides, and the side moving second has its counter.
extends GdUnitTestSuite

const RED: int = TacticalScenario.RED
const BLUE: int = TacticalScenario.BLUE


func test_an_equal_position_at_the_limit_is_still_a_draw() -> void:
	# The planted case: the opening, mirrored -- without the shield blue is
	# given for moving second -- carried to the limit untouched. Every score
	# is equal, so nothing may be called a win.
	var state: BoardState = _at_the_limit(_mirrored())

	assert_int(TacticalVictory.winner(state)).is_equal(TacticalVictory.DRAW)
	assert_str(TacticalVictory.announcement(TacticalVictory.winner(state), state)).contains("the scores are equal")


func test_the_healthier_workshop_wins_at_the_limit() -> void:
	var state: BoardState = _at_the_limit(_mirrored())
	_workshop(state, RED).health -= 1

	assert_int(TacticalVictory.winner(state)).is_equal(BLUE)
	assert_str(TacticalVictory.announcement(BLUE, state)).contains("wins on score")


func test_turns_holding_points_decide_between_equal_workshops() -> void:
	var state: BoardState = _at_the_limit(_mirrored())
	state.tally[ControlPoints.POINT_TURNS] = {RED: 3, BLUE: 2}

	assert_int(TacticalVictory.winner(state)).is_equal(RED)


func test_workshop_health_outranks_point_turns() -> void:
	# The order is the rule: red holds more point-turns, blue has the
	# healthier workshop, and the workshop decides.
	var state: BoardState = _at_the_limit(_mirrored())
	_workshop(state, RED).health -= 1
	state.tally[ControlPoints.POINT_TURNS] = {RED: 9, BLUE: 0}

	assert_int(TacticalVictory.winner(state)).is_equal(BLUE)


func test_point_turns_outrank_what_is_left_standing() -> void:
	var state: BoardState = _mirrored()
	var units: Array[Unit] = state.units.duplicate()
	units.append(Unit.new(99, BLUE, Vector2i(9, 0), 10, 3, TacticalRules.unit_types()[TacticalRules.SHIELD]))
	var more := BoardState.new(state.graph, units, RED)
	more.movement_graphs = state.movement_graphs
	var later: BoardState = _at_the_limit(more)
	later.tally[ControlPoints.POINT_TURNS] = {RED: 1, BLUE: 0}

	assert_int(TacticalVictory.winner(later)).is_equal(RED)


func test_point_turns_are_counted_across_real_turns() -> void:
	# Through `TurnStart`, as a game opens every turn: a red runner on a point
	# for two of red's turns is two, and blue's turns between them take
	# nothing away. Two points held for one turn would count two.
	var state: BoardState = _mirrored()
	var units: Array[Unit] = state.units.duplicate()
	units.append(Unit.new(99, RED, TacticalScenario.POINTS[0], 10, 6, TacticalRules.unit_types()[TacticalRules.RUNNER]))
	var holding := BoardState.new(state.graph, units, RED)
	holding.movement_graphs = state.movement_graphs
	holding.funds = state.funds.duplicate()

	for turn: int in range(4):
		holding = TurnStart.open(holding)[0]

	assert_int(holding.tally[ControlPoints.POINT_TURNS][RED]).is_equal(2)


func test_two_points_held_for_one_turn_are_two_point_turns() -> void:
	var state: BoardState = _mirrored()
	var units: Array[Unit] = state.units.duplicate()
	var runner: UnitType = TacticalRules.unit_types()[TacticalRules.RUNNER]
	units.append(Unit.new(98, RED, TacticalScenario.POINTS[0], 10, 6, runner))
	units.append(Unit.new(99, RED, TacticalScenario.POINTS[1], 10, 6, runner))
	var holding := BoardState.new(state.graph, units, RED)

	assert_int(ControlPoints.pay(holding)[0].tally[ControlPoints.POINT_TURNS][RED]).is_equal(2)


func test_what_is_left_standing_decides_last() -> void:
	var state: BoardState = _mirrored()
	var units: Array[Unit] = state.units.duplicate()
	units.append(Unit.new(99, BLUE, Vector2i(9, 0), 10, 3, TacticalRules.unit_types()[TacticalRules.SHIELD]))
	var more := BoardState.new(state.graph, units, RED)
	more.movement_graphs = state.movement_graphs

	assert_int(TacticalVictory.winner(_at_the_limit(more))).is_equal(BLUE)


func test_a_held_point_is_counted_at_its_holder_s_turn() -> void:
	var state: BoardState = TacticalScenario.build()
	var units: Array[Unit] = state.units.duplicate()
	units.append(Unit.new(99, RED, TacticalScenario.POINTS[0], 10, 6, TacticalRules.unit_types()[TacticalRules.RUNNER]))
	var holding := BoardState.new(state.graph, units, RED)

	var paid: BoardState = ControlPoints.pay(holding)[0]
	var twice: BoardState = ControlPoints.pay(paid)[0]

	assert_int(twice.tally[ControlPoints.POINT_TURNS][RED]).is_equal(2)
	assert_bool(holding.tally.is_empty()).is_true()


func test_a_tally_is_copied_with_the_state_not_shared() -> void:
	var state: BoardState = TacticalScenario.build()
	state.tally[ControlPoints.POINT_TURNS] = {RED: 1}
	var copy: BoardState = state.duplicate_state()
	copy.tally[ControlPoints.POINT_TURNS][RED] = 5

	assert_int(state.tally[ControlPoints.POINT_TURNS][RED]).is_equal(1)


func test_a_workshop_destroyed_still_wins_outright_at_the_limit() -> void:
	var state: BoardState = _at_the_limit(TacticalScenario.build())
	var without: Array[Unit] = []
	for unit: Unit in state.units:
		if unit.id != _workshop(state, BLUE).id:
			without.append(unit)
	var fallen := BoardState.new(state.graph, without, RED, state.turn_number)

	assert_int(TacticalVictory.winner(fallen)).is_equal(RED)
	assert_bool(TacticalVictory.at_the_limit(fallen)).is_false()


func test_blue_moving_second_starts_with_a_shield_beside_its_workshop() -> void:
	var standing: Unit = TacticalScenario.build().unit_at(TacticalScenario.SECOND_PLAYER_SHIELD_CELL)

	assert_bool(TacticalRules.SECOND_PLAYER_SHIELD).is_true()
	assert_int(standing.faction).is_equal(BLUE)
	assert_str(standing.type.type_name).is_equal(TacticalRules.SHIELD)


# The opening without the second player's counter: the same turned half round.
func _mirrored() -> BoardState:
	var state: BoardState = TacticalScenario.build()
	var units: Array[Unit] = []
	for unit: Unit in state.units:
		if unit.cell != TacticalScenario.SECOND_PLAYER_SHIELD_CELL:
			units.append(unit)
	var mirrored := BoardState.new(state.graph, units, RED)
	mirrored.movement_graphs = state.movement_graphs
	mirrored.funds = state.funds.duplicate()
	return mirrored


func _at_the_limit(state: BoardState) -> BoardState:
	var later: BoardState = state.duplicate_state()
	later.turn_number = TacticalVictory.ROUND_LIMIT * TacticalScenario.FACTIONS
	return later


func _workshop(state: BoardState, side: int) -> Unit:
	for unit: Unit in state.units_of(side):
		if unit.type.type_name == TacticalRules.WORKSHOP:
			return unit
	return null
