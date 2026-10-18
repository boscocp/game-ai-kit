# T48: the threat map. The test the task names first: a cell across the
# river with no crossing in reach carries no threat from a walker that cannot
# wade -- and the planted map that measures by straight line, as the map is
# told not to, gets it wrong.
extends GdUnitTestSuite

const RED: int = TacticalScenario.RED
const BLUE: int = TacticalScenario.BLUE


func test_across_deep_water_a_walker_that_cannot_wade_threatens_nothing() -> void:
	# A red shield at (5, 2) on its own bank; (8, 2) is across two cells of
	# deep water, three steps as the crow flies -- inside its movement and
	# reach -- and the nearest crossing is far beyond them.
	var state: BoardState = _with(RED, TacticalRules.SHIELD, Vector2i(5, 2))
	var shield: Unit = state.unit_at(Vector2i(5, 2))
	var across := Vector2i(8, 2)

	assert_int(TacticalCombat.distance(shield.cell, across)).is_less_equal(shield.type.movement + shield.type.attack_range)
	assert_bool(_straight_line_map(state, RED).has(across)).is_true()
	assert_bool(ThreatMap.of(state, RED).has(across)).is_false()


func test_a_wader_does_threaten_across_the_water() -> void:
	var state: BoardState = _with(RED, TacticalRules.WADER, Vector2i(5, 2))

	assert_bool(ThreatMap.of(state, RED).has(Vector2i(8, 2))).is_true()


func test_a_bolt_tower_threatens_the_ring_of_its_reach_and_no_further() -> void:
	var state: BoardState = TacticalScenario.build()
	var tower: Unit = _first_of(state, RED, TacticalRules.BOLT_TOWER)
	var threat: Dictionary[Vector2i, int] = ThreatMap.of(state, RED)

	assert_bool(threat.has(tower.cell + Vector2i(2, 0))).is_true()
	assert_bool(ThreatMap.strikes(state, tower).has(tower.cell + Vector2i(3, 0))).is_false()


func test_two_pieces_that_reach_one_cell_count_two() -> void:
	var state: BoardState = _with(RED, TacticalRules.SHIELD, Vector2i(2, 2))
	var units: Array[Unit] = state.units.duplicate()
	var shield: UnitType = TacticalRules.unit_types()[TacticalRules.SHIELD]
	units.append(Unit.new(98, RED, Vector2i(2, 0), 10, shield.movement, shield))
	var both := BoardState.new(state.graph, units, BLUE)
	both.movement_graphs = state.movement_graphs

	assert_int(ThreatMap.of(both, RED)[Vector2i(2, 1)]).is_greater_equal(2)


func test_a_workshop_and_a_watchtower_threaten_nothing() -> void:
	var state: BoardState = TacticalScenario.build()

	assert_array(ThreatMap.strikes(state, _first_of(state, RED, TacticalRules.WORKSHOP))).is_empty()
	assert_bool(ThreatMap.of(state, RED).has(_first_of(state, BLUE, TacticalRules.WORKSHOP).cell)).is_false()


# The map the header says not to build: every cell within movement and reach
# as the crow flies. Here so the first test can show it is wrong.
func _straight_line_map(state: BoardState, side: int) -> Dictionary:
	var threat: Dictionary = {}
	for unit: Unit in state.units_of(side).filter(func(piece: Unit) -> bool: return piece.type.mobile):
		var reach: int = unit.type.movement + unit.type.attack_range
		for cell: Vector2i in _every_cell(state).filter(func(at: Vector2i) -> bool: return TacticalCombat.distance(unit.cell, at) <= reach):
			threat[cell] = true
	return threat


func _every_cell(state: BoardState) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for index: int in range(state.graph.width * state.graph.height):
		cells.append(Vector2i(index % state.graph.width, index / state.graph.width))
	return cells


# The scenario's terrain with only one piece on it.
func _with(side: int, type_name: String, cell: Vector2i) -> BoardState:
	var state: BoardState = TacticalScenario.build()
	var kind: UnitType = TacticalRules.unit_types()[type_name]
	var units: Array[Unit] = [Unit.new(1, side, cell, 10, kind.movement, kind)]
	var alone := BoardState.new(state.graph, units, BLUE)
	alone.movement_graphs = state.movement_graphs
	return alone


func _first_of(state: BoardState, side: int, type_name: String) -> Unit:
	for unit: Unit in state.units_of(side):
		if unit.type.type_name == type_name:
			return unit
	return null


func test_the_scene_draws_the_other_side_s_threat_and_reports_it() -> void:
	# The half of invariant 13 a command can hold: the overlay is populated.
	# That a person can read it is the manual check.
	var scene: TacticalGame = auto_free((load("res://game/tactical/tactical.tscn") as PackedScene).instantiate())
	add_child(scene)

	assert_int(scene.decision_overlay()["threatened cells"]).is_greater(0)
	assert_int(scene.threat().size()).is_equal(ThreatMap.of(scene.state, BLUE).size())
