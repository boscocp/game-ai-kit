# T10's game, held where it is not a matter of taste: the rules a planner will
# reason over in T11 have to be the rules the board enforces, or the plan is a
# plan for a different game.
#
# The cases T10 names: a unit that cannot enter water and one that can; a
# tower that cannot move; a build refused for cost and accepted after income;
# and the counter table being what it claims. The rest hold the scenario
# itself -- that the river can be crossed at all, which the first draft of the
# map got wrong and nothing but a person tracing it noticed.
extends GdUnitTestSuite

const RED: int = TacticalScenario.RED
const BLUE: int = TacticalScenario.BLUE


func test_a_runner_cannot_step_into_water() -> void:
	var state: BoardState = _state_with(TacticalRules.RUNNER, Vector2i(5, 0))

	var refusal: String = state.why_refused(_step(state, Vector2i(6, 0)))

	assert_str(refusal).contains("blocked")


func test_a_wader_can_step_into_water() -> void:
	var state: BoardState = _state_with(TacticalRules.WADER, Vector2i(5, 0))

	assert_str(state.why_refused(_step(state, Vector2i(6, 0)))).is_equal(BoardState.LEGAL)
	assert_vector(state.apply(_step(state, Vector2i(6, 0))).unit_by_id(99).cell).is_equal(Vector2i(6, 0))


func test_a_tower_cannot_move() -> void:
	var state: BoardState = TacticalScenario.build()
	var tower: Unit = _first_of(state, RED, TacticalRules.BOLT_TOWER)

	var refusal: String = state.why_refused(Move.new(tower.id, [tower.cell + Vector2i.UP] as Array[Vector2i]))

	assert_str(refusal).contains("cannot move")


func test_a_build_refused_for_cost_is_accepted_after_income() -> void:
	var state: BoardState = TacticalScenario.build()
	var workshop: Unit = _first_of(state, RED, TacticalRules.WORKSHOP)
	var mortar: UnitType = TacticalRules.unit_types()[TacticalRules.MORTAR]
	state.funds[RED] = mortar.cost - 1
	var order := ProductionOrder.new(workshop.id, mortar, workshop.cell + Vector2i.UP)

	assert_str(state.why_production_refused(order)).contains("costs %d" % mortar.cost)

	var later: BoardState = state.end_turn(2, 0, TacticalRules.INCOME).end_turn(2, 0, TacticalRules.INCOME)
	assert_int(later.funds_of(RED)).is_equal(mortar.cost - 1 + TacticalRules.INCOME)
	var built: BoardState = later.produce(order)
	assert_object(built).is_not_null()
	assert_int(built.funds_of(RED)).is_equal(TacticalRules.INCOME - 1)
	assert_str(built.unit_at(order.cell).type.type_name).is_equal(TacticalRules.MORTAR)


func test_a_new_unit_waits_for_its_side_s_next_turn() -> void:
	var state: BoardState = TacticalScenario.build()
	var workshop: Unit = _first_of(state, RED, TacticalRules.WORKSHOP)
	var runner: UnitType = TacticalRules.unit_types()[TacticalRules.RUNNER]

	var built: BoardState = state.produce(ProductionOrder.new(workshop.id, runner, workshop.cell + Vector2i.UP))

	var fresh: Unit = built.unit_at(workshop.cell + Vector2i.UP)
	assert_int(fresh.movement_points).is_equal(0)
	assert_object(state.unit_by_id(fresh.id)).is_null()


func test_the_ram_needs_the_forge() -> void:
	var state: BoardState = TacticalScenario.build()
	var workshop: Unit = _first_of(state, RED, TacticalRules.WORKSHOP)
	var ram: UnitType = TacticalRules.unit_types()[TacticalRules.RAM]
	state.funds[RED] = TacticalRules.FORGE_COST + ram.cost
	var order := ProductionOrder.new(workshop.id, ram, workshop.cell + Vector2i.UP)

	assert_str(state.why_production_refused(order)).contains("forge")

	var forged: BoardState = state.buy(TacticalRules.forge())
	assert_bool(forged.owns(RED, TacticalRules.FORGE)).is_true()
	assert_bool(state.owns(RED, TacticalRules.FORGE)).is_false()
	assert_str(forged.why_production_refused(order)).is_equal(BoardState.LEGAL)


func test_no_two_types_are_strong_against_each_other() -> void:
	# The claim the counter table makes is that it is a cycle, not a ladder:
	# being strong against something never comes back the other way.
	var types: Dictionary = TacticalRules.unit_types()
	for attacker: String in types:
		for defender: String in types:
			var both: bool = types[attacker].beats(types[defender]) and types[defender].beats(types[attacker])
			assert_bool(both).override_failure_message("%s and %s beat each other" % [attacker, defender]).is_false()


func test_every_mobile_type_beats_something_and_is_beaten_by_something() -> void:
	# The other half of rock-paper-scissors: no type a plan can ignore, and no
	# type a plan cannot answer.
	var types: Dictionary = TacticalRules.unit_types()
	for name: String in TacticalRules.BUILDABLE:
		var beaten_by: Array = types.values().filter(func(other: UnitType) -> bool: return other.beats(types[name]))
		assert_array(types[name].strong_against).override_failure_message(name + " beats nothing").is_not_empty()
		assert_array(beaten_by).override_failure_message(name + " is beaten by nothing").is_not_empty()


func test_every_name_the_counter_table_uses_is_a_type() -> void:
	var types: Dictionary = TacticalRules.unit_types()
	for kind: UnitType in types.values():
		for name: String in kind.strong_against + kind.produces:
			assert_bool(types.has(name)).override_failure_message(kind.type_name + " names " + name).is_true()


func test_a_runner_can_cross_the_river_only_by_the_bridge() -> void:
	var state: BoardState = TacticalScenario.build()
	var ground: GridGraph = state.graph
	var red_workshop: Unit = _first_of(state, RED, TacticalRules.WORKSHOP)
	var blue_workshop: Unit = _first_of(state, BLUE, TacticalRules.WORKSHOP)
	var goal: Vector2i = blue_workshop.cell + Vector2i.LEFT

	var route: SearchResult = AStarSearch.new().search(ground, red_workshop.cell + Vector2i.RIGHT, goal)

	assert_bool(route.reached).is_true()
	var crossings: Array = route.path.filter(func(cell: Vector2i) -> bool: return cell.x == 6 or cell.x == 7)
	assert_bool(crossings.all(func(cell: Vector2i) -> bool: return cell.y == 4)).is_true()


func test_the_map_is_the_same_turned_half_round() -> void:
	# So neither side starts nearer the bridge.
	var rows: Array[String] = TacticalScenario.MAP
	for y: int in range(rows.size()):
		for x: int in range(rows[y].length()):
			assert_str(rows[y][x]).is_equal(rows[rows.size() - 1 - y][rows[y].length() - 1 - x])


func test_the_scene_comes_up_with_funds_and_a_piece_in_hand() -> void:
	var scene: TacticalGame = auto_free((load("res://game/tactical/tactical.tscn") as PackedScene).instantiate())
	add_child(scene)
	var status: String = (scene.get_node("Interface/Status") as Label).text

	assert_str(status).contains("red to move")
	assert_str(status).contains("funds %d" % TacticalRules.STARTING_FUNDS)
	assert_str(status).contains("in hand: runner")


func test_building_from_the_scene_spends_funds() -> void:
	var scene: TacticalGame = auto_free((load("res://game/tactical/tactical.tscn") as PackedScene).instantiate())
	add_child(scene)
	var workshop: Unit = _first_of(scene.state, RED, TacticalRules.WORKSHOP)

	scene.click_cell(workshop.cell)
	scene.build(TacticalRules.BUILDABLE.find(TacticalRules.RUNNER))

	assert_int(scene.state.funds_of(RED)).is_equal(TacticalRules.STARTING_FUNDS - 1)
	assert_int(scene.state.units_of(RED).size()).is_equal(6)


# The scenario's board with one extra red unit of a type, as unit 99.
func _state_with(type_name: String, cell: Vector2i) -> BoardState:
	var state: BoardState = TacticalScenario.build()
	var kind: UnitType = TacticalRules.unit_types()[type_name]
	var units: Array[Unit] = state.units.duplicate()
	units.append(Unit.new(99, RED, cell, 10, kind.movement, kind))
	var placed := BoardState.new(state.graph, units, RED)
	placed.movement_graphs = state.movement_graphs
	return placed


func _step(state: BoardState, cell: Vector2i) -> Move:
	return Move.new(99, [cell] as Array[Vector2i])


func _first_of(state: BoardState, faction: int, type_name: String) -> Unit:
	for unit: Unit in state.units_of(faction):
		if unit.type.type_name == type_name:
			return unit
	return null
