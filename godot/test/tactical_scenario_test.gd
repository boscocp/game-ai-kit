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
	var waded: Unit = state.apply(_step(state, Vector2i(6, 0))).unit_by_id(99)
	assert_vector(waded.cell).is_equal(Vector2i(6, 0))
	# Billed on its own map: one point. Billed on the board's, water is
	# BLOCKED (-1), and a wader would *gain* a point for every step it waded.
	assert_int(waded.movement_points).is_equal(state.unit_by_id(99).movement_points - 1)


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


func test_every_buildable_type_is_answered_by_another_buildable_type() -> void:
	# The other half of rock-paper-scissors, and what makes it a cycle rather
	# than a ladder: no buildable type sits on top. Answered by something you
	# can *build* -- the first version counted the bolt tower, and a ladder
	# with the runner on top passed because a tower beats runners.
	var types: Dictionary = TacticalRules.unit_types()
	for name: String in TacticalRules.BUILDABLE:
		var answers: Array = TacticalRules.BUILDABLE.filter(func(other: String) -> bool: return types[other].beats(types[name]))
		assert_array(types[name].strong_against).override_failure_message(name + " beats nothing").is_not_empty()
		assert_array(answers).override_failure_message(name + " has no buildable answer").is_not_empty()


func test_every_name_the_counter_table_uses_is_a_type() -> void:
	var types: Dictionary = TacticalRules.unit_types()
	for kind: UnitType in types.values():
		for name: String in kind.strong_against + kind.produces:
			assert_bool(types.has(name)).override_failure_message(kind.type_name + " names " + name).is_true()


func test_a_runner_can_cross_the_river_only_by_the_bridge() -> void:
	# Two halves. With the bridge the far bank is reachable -- the first draft
	# of the map put the bridge where it touched only one bank. Without it the
	# far bank is not, which is what "only" means; one shortest route over the
	# bridge would not have shown that.
	var state: BoardState = TacticalScenario.build()
	var start: Vector2i = _first_of(state, RED, TacticalRules.WORKSHOP).cell + Vector2i.RIGHT
	var goal: Vector2i = _first_of(state, BLUE, TacticalRules.WORKSHOP).cell + Vector2i.LEFT
	var no_bridge: GridGraph = state.graph.duplicate_graph()
	for cell: Vector2i in TacticalRules.cells_of(TacticalScenario.MAP, TacticalRules.BRIDGE):
		no_bridge.block(cell)

	assert_bool(AStarSearch.new().search(state.graph, start, goal).reached).is_true()
	assert_bool(AStarSearch.new().search(no_bridge, start, goal).reached).is_false()


func test_the_map_is_the_same_turned_half_round() -> void:
	# So neither side starts nearer the bridge.
	var rows: Array[String] = TacticalScenario.MAP
	for y: int in range(rows.size()):
		for x: int in range(rows[y].length()):
			assert_str(rows[y][x]).is_equal(rows[rows.size() - 1 - y][rows[y].length() - 1 - x])


func test_the_placements_are_the_same_turned_half_round() -> void:
	# The terrain is mirrored; so must be who stands where, or one side starts
	# nearer the bridge after all.
	var state: BoardState = TacticalScenario.build()
	var corner := Vector2i(state.graph.width - 1, state.graph.height - 1)
	for unit: Unit in state.units_of(RED):
		var mirror: Unit = state.unit_at(corner - unit.cell)
		assert_object(mirror).override_failure_message("nothing faces %s" % unit.cell).is_not_null()
		assert_int(mirror.faction).is_equal(BLUE)
		assert_str(mirror.type.type_name).is_equal(unit.type.type_name)


func test_ending_the_turn_pays_the_next_side_and_hands_it_a_piece() -> void:
	var scene: TacticalGame = _mounted_scene()

	scene.end_turn()

	assert_str(_status_of(scene)).contains("blue to move")
	assert_str(_status_of(scene)).contains("funds %d" % (TacticalRules.STARTING_FUNDS + TacticalRules.INCOME))
	assert_str(_status_of(scene)).contains("in hand: runner")


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


func test_building_without_funds_says_so() -> void:
	# The review: out of funds, the scene picked a cell by asking the whole
	# order, heard "cannot afford" about every cell, fell back to the
	# workshop's own cell and reported "not next to unit 1".
	var scene: TacticalGame = _mounted_scene()
	scene.state.funds[RED] = 0
	scene.click_cell(_first_of(scene.state, RED, TacticalRules.WORKSHOP).cell)

	scene.build(TacticalRules.BUILDABLE.find(TacticalRules.RUNNER))

	assert_str(_status_of(scene)).contains("runner costs 1 and the side to move has 0")


func test_the_forge_is_not_offered_once_owned() -> void:
	var scene: TacticalGame = _mounted_scene()
	scene.state.funds[RED] = TacticalRules.FORGE_COST
	scene.click_cell(_first_of(scene.state, RED, TacticalRules.WORKSHOP).cell)

	scene.buy_forge()

	assert_str(_status_of(scene)).contains("forge owned")
	assert_str(_status_of(scene)).not_contains("U buys the forge")


func test_a_runner_lights_up_more_than_its_neighbours_and_walks_there_in_one_click() -> void:
	# The review: every type lit only its four neighbours, so a runner that
	# moves 6 looked exactly like a ram that moves 2.
	var scene: TacticalGame = _mounted_scene()
	var runner: Unit = _first_of(scene.state, RED, TacticalRules.RUNNER)
	var far: Vector2i = runner.cell + Vector2i(0, -4)

	var walks: Dictionary = TacticalReach.walks_for(scene.state, runner)
	assert_bool(walks.has(far)).is_true()
	# Charged for the route the reach found -- round the rock, not through it.
	var cost: int = Move.new(runner.id, walks[far]).cost_on(scene.state.graph)
	scene.click_cell(far)

	assert_vector(scene.state.unit_by_id(runner.id).cell).is_equal(far)
	assert_int(scene.state.unit_by_id(runner.id).movement_points).is_equal(runner.movement_points - cost)


func test_reach_never_offers_a_walk_the_board_refuses() -> void:
	var state: BoardState = TacticalScenario.build()
	for unit: Unit in state.units_of(RED):
		var walks: Dictionary = TacticalReach.walks_for(state, unit)
		for goal: Vector2i in walks:
			assert_str(state.why_refused(Move.new(unit.id, walks[goal]))).is_equal(BoardState.LEGAL)


func test_reach_is_empty_for_a_tower() -> void:
	var state: BoardState = TacticalScenario.build()

	assert_dict(TacticalReach.walks_for(state, _first_of(state, RED, TacticalRules.BOLT_TOWER))).is_empty()


func test_clicking_an_enemy_piece_says_whose_it_is() -> void:
	var scene: TacticalGame = _mounted_scene()

	scene.click_cell(_first_of(scene.state, BLUE, TacticalRules.WORKSHOP).cell)

	assert_str(_status_of(scene)).contains("blue's workshop")


func test_a_refusal_into_water_says_it_is_water() -> void:
	var scene: TacticalGame = _mounted_scene()
	var runner: Unit = _first_of(scene.state, RED, TacticalRules.RUNNER)
	# Set down on the bank, beside the river, rather than walked there.
	scene.state.unit_by_id(runner.id).cell = Vector2i(5, 6)

	scene.click_cell(Vector2i(6, 6))

	assert_str(_status_of(scene)).contains("only waders cross")


func test_the_bridge_is_drawn_as_a_bridge() -> void:
	var scene: TacticalGame = _mounted_scene()
	var board: BoardView = scene.get_node("BoardView")

	assert_vector(board.get_cell_atlas_coords(Vector2i(6, 4))).is_equal(BoardView.BRIDGE)
	assert_vector(board.get_cell_atlas_coords(Vector2i(6, 3))).is_equal(BoardView.WATER)


func _mounted_scene() -> TacticalGame:
	var scene: TacticalGame = auto_free((load("res://game/tactical/tactical.tscn") as PackedScene).instantiate())
	add_child(scene)
	return scene


func _status_of(scene: TacticalGame) -> String:
	return (scene.get_node("Interface/Status") as Label).text


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
