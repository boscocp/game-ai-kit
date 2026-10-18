# T30: the tactical game against the computer. Red's turns as Advance Wars
# plays them -- spent units, the next unit picked for you, undo, a confirmed
# end of turn -- and blue played by rules, every decision shown before it is
# played and every one legal, over many games.
extends GdUnitTestSuite

const RED: int = TacticalScenario.RED
const BLUE: int = TacticalScenario.BLUE
const RED_WORKSHOP := Vector2i(1, 7)
const BLUE_WORKSHOP := Vector2i(12, 1)


# --- red's turn --------------------------------------------------------------

func test_a_spent_unit_cannot_move_again_this_turn() -> void:
	var scene: TacticalGame = _mounted_scene()
	var runner: Unit = _first_of(scene.state, RED, TacticalRules.RUNNER)
	var first: Vector2i = runner.cell + Vector2i(-1, 0)
	scene.click_cell(first)
	assert_vector(scene.state.unit_by_id(runner.id).cell).is_equal(first)

	scene.click_cell(runner.cell + Vector2i(-1, 0))   # pick it up again
	scene.click_cell(first + Vector2i(-1, 0))         # and try one more step

	assert_vector(scene.state.unit_by_id(runner.id).cell).is_equal(first)
	assert_str(_status_of(scene)).contains("has moved this turn")


func test_a_spent_unit_offers_no_reach() -> void:
	var scene: TacticalGame = _mounted_scene()
	var runner: Unit = _first_of(scene.state, RED, TacticalRules.RUNNER)
	scene.click_cell(runner.cell + Vector2i(-1, 0))

	scene.click_cell(runner.cell + Vector2i(-1, 0))

	assert_array(scene._steps_in_reach()).is_empty()


func test_moving_selects_the_next_unspent_unit() -> void:
	var scene: TacticalGame = _mounted_scene()
	var runner: Unit = _first_of(scene.state, RED, TacticalRules.RUNNER)
	var shield: Unit = _first_of(scene.state, RED, TacticalRules.SHIELD)
	assert_int(scene._selected_id).is_equal(runner.id)

	scene.click_cell(runner.cell + Vector2i(-1, 0))

	assert_int(scene._selected_id).is_equal(shield.id)


func test_once_every_unit_has_moved_nothing_is_in_hand_and_the_screen_says_so() -> void:
	var scene: TacticalGame = _mounted_scene()
	var runner: Unit = _first_of(scene.state, RED, TacticalRules.RUNNER)
	var shield: Unit = _first_of(scene.state, RED, TacticalRules.SHIELD)
	scene.click_cell(runner.cell + Vector2i(-1, 0))
	scene.wait()   # the shield, in hand already

	assert_int(scene._selected_id).is_equal(-1)
	assert_str(_status_of(scene)).contains("every unit has moved")


func test_units_can_be_moved_in_any_order() -> void:
	var scene: TacticalGame = _mounted_scene()
	var runner: Unit = _first_of(scene.state, RED, TacticalRules.RUNNER)
	var shield: Unit = _first_of(scene.state, RED, TacticalRules.SHIELD)
	scene.click_cell(shield.cell)
	var target: Vector2i = shield.cell + Vector2i(1, 0)

	scene.click_cell(target)

	assert_vector(scene.state.unit_by_id(shield.id).cell).is_equal(target)
	assert_int(scene._selected_id).is_equal(runner.id)


func test_w_has_the_unit_in_hand_wait() -> void:
	var scene: TacticalGame = _mounted_scene()
	var runner: Unit = _first_of(scene.state, RED, TacticalRules.RUNNER)

	scene._press(KEY_W)

	assert_bool(scene._turn.is_spent(runner.id)).is_true()
	assert_vector(scene.state.unit_by_id(runner.id).cell).is_equal(runner.cell)


func test_clicking_the_unit_already_in_hand_does_not_spend_it() -> void:
	# The review: the turn starts with the runner in hand, and a click meant
	# to pick it up made it wait.
	var scene: TacticalGame = _mounted_scene()
	var runner: Unit = _first_of(scene.state, RED, TacticalRules.RUNNER)

	scene.click_cell(runner.cell)

	assert_bool(scene._turn.is_spent(runner.id)).is_false()


func test_a_wait_can_be_taken_back() -> void:
	var scene: TacticalGame = _mounted_scene()
	var runner: Unit = _first_of(scene.state, RED, TacticalRules.RUNNER)
	scene.wait()

	scene.undo()

	assert_bool(scene._turn.is_spent(runner.id)).is_false()
	assert_int(scene._selected_id).is_equal(runner.id)


func test_undo_restores_the_unit_and_its_spent_state() -> void:
	var scene: TacticalGame = _mounted_scene()
	var runner: Unit = _first_of(scene.state, RED, TacticalRules.RUNNER)
	scene.click_cell(runner.cell + Vector2i(-1, 0))

	scene.undo()

	var back: Unit = scene.state.unit_by_id(runner.id)
	assert_vector(back.cell).is_equal(runner.cell)
	assert_int(back.movement_points).is_equal(runner.movement_points)
	assert_bool(scene._turn.is_spent(runner.id)).is_false()


func test_undo_takes_back_a_build_and_the_money() -> void:
	var scene: TacticalGame = _mounted_scene()
	scene.click_cell(RED_WORKSHOP)
	scene.build(TacticalRules.BUILDABLE.find(TacticalRules.RUNNER))
	assert_int(scene.state.units_of(RED).size()).is_equal(6)

	scene.undo()

	assert_int(scene.state.units_of(RED).size()).is_equal(5)
	assert_int(scene.state.funds_of(RED)).is_equal(TacticalRules.STARTING_FUNDS)
	assert_bool(scene._turn.is_spent(scene.state.unit_at(RED_WORKSHOP).id)).is_false()


func test_undo_goes_back_as_far_as_the_start_of_the_turn_and_no_further() -> void:
	var scene: TacticalGame = _mounted_scene()
	var start: BoardState = scene.state
	var runner: Unit = _first_of(scene.state, RED, TacticalRules.RUNNER)
	scene.click_cell(runner.cell + Vector2i(-1, 0))
	scene.wait()

	scene.undo()
	scene.undo()
	scene.undo()

	assert_object(scene.state).is_same(start)
	assert_str(_status_of(scene)).contains("nothing to take back")


func test_a_workshop_builds_once_a_turn() -> void:
	var scene: TacticalGame = _mounted_scene()
	scene.click_cell(RED_WORKSHOP)
	scene.build(TacticalRules.BUILDABLE.find(TacticalRules.RUNNER))

	scene.build(TacticalRules.BUILDABLE.find(TacticalRules.RUNNER))

	assert_int(scene.state.units_of(RED).size()).is_equal(6)
	assert_str(_status_of(scene)).contains("already built this turn")


func test_ending_the_turn_with_units_unspent_asks_first() -> void:
	var scene: TacticalGame = _mounted_scene()

	scene.end_turn()

	assert_int(scene.state.current_faction).is_equal(RED)
	assert_str(_status_of(scene)).contains("2 unit(s) have not moved")


func test_any_other_action_cancels_the_question() -> void:
	var scene: TacticalGame = _mounted_scene()
	scene.end_turn()
	scene.click_cell(_first_of(scene.state, RED, TacticalRules.RUNNER).cell + Vector2i(-1, 0))

	scene.end_turn()

	assert_int(scene.state.current_faction).is_equal(RED)


func test_ending_the_turn_with_every_unit_spent_does_not_ask() -> void:
	var scene: TacticalGame = _mounted_scene()
	scene.wait()
	scene.wait()

	scene.end_turn()

	assert_int(scene.state.current_faction).is_equal(BLUE)


func test_the_end_turn_button_ends_the_turn() -> void:
	var scene: TacticalGame = _mounted_scene()
	var button: Button = scene.get_node("Interface/EndTurn")

	button.pressed.emit()
	button.pressed.emit()

	assert_int(scene.state.current_faction).is_equal(BLUE)
	assert_bool(button.disabled).is_true()


func test_the_undo_button_takes_back_a_move() -> void:
	var scene: TacticalGame = _mounted_scene()
	var button: Button = scene.get_node("Interface/Undo")
	var runner: Unit = _first_of(scene.state, RED, TacticalRules.RUNNER)
	assert_bool(button.disabled).is_true()
	scene.click_cell(runner.cell + Vector2i(-1, 0))
	assert_bool(button.disabled).is_false()

	button.pressed.emit()

	assert_vector(scene.state.unit_by_id(runner.id).cell).is_equal(runner.cell)


func test_spent_units_are_drawn_greyed() -> void:
	var scene: TacticalGame = _mounted_scene()
	var runner: Unit = _first_of(scene.state, RED, TacticalRules.RUNNER)
	var view: UnitView = scene.get_node("UnitView")
	var fresh: Color = view.colour_for(scene.state.unit_by_id(runner.id))
	scene.wait()

	assert_array(view.spent).contains([runner.id])
	assert_that(view.colour_for(scene.state.unit_by_id(runner.id))).is_not_equal(fresh)


# --- blue ------------------------------------------------------------------

func test_blue_shows_its_decision_before_playing_it() -> void:
	var scene: TacticalGame = _mounted_scene()
	scene.step_decision()   # red's turn ends
	var shown: TacticalDecision = scene._blue_turn.next
	var before: BoardState = scene.state
	assert_object(shown).is_not_null()
	assert_str(scene.decision_overlay()["next"]["why"]).is_equal(shown.reason)
	assert_object(scene.state).is_same(before)

	scene.step_decision()

	assert_object(scene._blue_turn.played.back()).is_same(shown)


func test_blue_s_next_walk_is_drawn() -> void:
	var scene: TacticalGame = _mounted_scene()
	scene.step_decision()
	scene.step_decision()   # the workshop's decision is played; a walk is next
	var intent: IntentView = scene.get_node("IntentView")

	assert_str(scene._blue_turn.next.kind()).is_equal("move")
	assert_object(intent._decision).is_same(scene._blue_turn.next)


func test_blue_builds_what_beats_the_most_red_pieces() -> void:
	# Red has a runner and a shield on the move, and three buildings. A shield
	# beats the runner; a mortar beats the shield; a ram would beat all three
	# buildings but needs the forge. Shield and mortar tie at one, and the tie
	# goes to the earlier type.
	var state: BoardState = _blue_to_move(TacticalScenario.build())
	var decision: TacticalDecision = RuleBasedBlue.new().decide_build(state, state.unit_at(BLUE_WORKSHOP).id)

	assert_str(decision.kind()).is_equal("build")
	assert_str(decision.order.unit_type.type_name).is_equal(TacticalRules.SHIELD)
	assert_str(decision.reason).contains("it beats 1 red piece(s), runner")


func test_blue_builds_the_counter_to_whatever_red_has_most_of() -> void:
	var state: BoardState = _blue_to_move(TacticalScenario.build())
	var shield: UnitType = TacticalRules.unit_types()[TacticalRules.SHIELD]
	for cell: Vector2i in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]:
		state.units.append(Unit.new(state.next_id, RED, cell, 10, 3, shield))
		state.next_id += 1

	var decision: TacticalDecision = RuleBasedBlue.new().decide_build(state, state.unit_at(BLUE_WORKSHOP).id)

	assert_str(decision.order.unit_type.type_name).is_equal(TacticalRules.MORTAR)


func test_blue_builds_nothing_it_cannot_pay_for() -> void:
	var state: BoardState = _blue_to_move(TacticalScenario.build())
	state.funds[BLUE] = 0

	var decision: TacticalDecision = RuleBasedBlue.new().decide_build(state, state.unit_at(BLUE_WORKSHOP).id)

	assert_str(decision.kind()).is_equal("hold")
	assert_str(decision.reason).contains("has 0")


func test_blue_walks_at_red_s_workshop_and_makes_for_a_crossing() -> void:
	var state: BoardState = _blue_to_move(TacticalScenario.build())
	var runner: Unit = _first_of(state, BLUE, TacticalRules.RUNNER)
	var routes: Dictionary = TacticalReach.route_costs(state.graph_for(runner), RED_WORKSHOP)

	var decision: TacticalDecision = RuleBasedBlue.new().decide_move(state, runner.id)

	assert_int(routes[decision.target]).is_less(routes[runner.cell])
	assert_str(decision.reason).contains("the workshop at %s" % RED_WORKSHOP)
	assert_str(decision.reason).contains("making for a crossing")


func test_a_unit_already_over_the_river_says_nothing_of_the_bridge() -> void:
	var state: BoardState = _blue_to_move(TacticalScenario.build())
	var runner: Unit = _first_of(state, BLUE, TacticalRules.RUNNER)
	state.unit_by_id(runner.id).cell = Vector2i(4, 3)

	var decision: TacticalDecision = RuleBasedBlue.new().decide_move(state, runner.id)

	assert_str(decision.reason).not_contains("bridge")


func test_blue_s_policy_answers_as_a_decision_policy() -> void:
	# The entry point T11 and T12 call: a Move, legal, for the unit asked.
	var state: BoardState = _blue_to_move(TacticalScenario.build())
	var runner: Unit = _first_of(state, BLUE, TacticalRules.RUNNER)
	var policy: DecisionPolicy = RuleBasedBlue.new()

	var move: Move = policy.choose(state, runner.id)

	assert_int(move.unit_id).is_equal(runner.id)
	assert_bool(move.path.is_empty()).is_false()
	assert_str(state.why_refused(move)).is_equal(BoardState.LEGAL)


func test_a_boxed_in_workshop_says_there_is_no_room() -> void:
	var state: BoardState = _blue_to_move(TacticalScenario.build())
	var shield: UnitType = TacticalRules.unit_types()[TacticalRules.SHIELD]
	for step: Vector2i in GridGraph.DIRECTIONS:
		if state.unit_at(BLUE_WORKSHOP + step) == null and not state.graph.is_blocked(BLUE_WORKSHOP + step):
			state.units.append(Unit.new(state.next_id, BLUE, BLUE_WORKSHOP + step, 10, 3, shield))
			state.next_id += 1

	var decision: TacticalDecision = RuleBasedBlue.new().decide_build(state, state.unit_at(BLUE_WORKSHOP).id)

	assert_str(decision.kind()).is_equal("hold")
	assert_str(decision.reason).not_contains("beats")


func test_blue_s_workshop_decides_before_anyone_walks() -> void:
	# So what it builds is on the board, and in the way, before a unit plans
	# a route through that cell.
	# The workshop is moved to the end of the unit list, so that being asked
	# first is the rule's doing and not the list's.
	var state: BoardState = _blue_to_move(TacticalScenario.build())
	var workshop: Unit = state.unit_at(BLUE_WORKSHOP)
	state.units.erase(workshop)
	state.units.append(workshop)
	var turn := BlueTurn.new(RuleBasedBlue.new())

	turn.begin(state)

	assert_int(turn.next.unit_id).is_equal(state.unit_at(BLUE_WORKSHOP).id)


func test_route_costs_are_the_cheapest_walks_dijkstra_finds() -> void:
	# Held against `ai_search`'s Dijkstra, which shares no code with it, from
	# both workshops' doors, to every cell either can reach -- trees and all.
	var state: BoardState = TacticalScenario.build()
	for from: Vector2i in [RED_WORKSHOP + Vector2i(1, 0), BLUE_WORKSHOP + Vector2i(-1, 0)]:
		var costs: Dictionary = TacticalReach.route_costs(state.graph, from)
		for cell: Vector2i in costs:
			assert_int(costs[cell]).is_equal(DijkstraSearch.new().search(state.graph, from, cell).cost)


func test_blue_s_turn_is_legal_on_every_decision_over_many_seeded_games() -> void:
	# Red plays at random -- walks, waits, builds -- so blue meets boards
	# nobody wrote by hand. Every blue decision is put to the board before it
	# is played.
	var decisions: int = 0
	for seed_number: int in range(25):
		decisions += _play_seeded_game(seed_number, 12)
	# At least one decision a round on average. It was two, until T26 let blue
	# destroy red's workshop and end some of these games early: measured, 520
	# decisions over the 25 seeds.
	assert_int(decisions).is_greater(25 * 12)


func test_blue_is_whichever_controller_the_scene_was_given() -> void:
	var scene: TacticalGame = (load("res://game/tactical/tactical.tscn") as PackedScene).instantiate()
	scene.blue = _HoldingBlue.new()
	add_child(scene)
	auto_free(scene)

	scene.step_decision()

	assert_str(scene.decision_overlay()["controller"]).is_equal("holds")
	assert_str((scene.get_node("Interface/Header") as Label).text).contains("never moves")


func test_the_screen_says_what_game_this_is_and_who_plays_blue() -> void:
	var scene: TacticalGame = _mounted_scene()
	var header: String = (scene.get_node("Interface/Header") as Label).text

	assert_str(header).contains("in the style of Advance Wars")
	assert_str(header).contains("destroy the enemy workshop")
	assert_str(header).contains("rules, not a plan")


# --- the end of a game -----------------------------------------------------

func test_no_side_has_won_at_the_start() -> void:
	var state: BoardState = TacticalScenario.build()

	assert_int(TacticalVictory.winner(state)).is_equal(TacticalVictory.NOBODY)
	assert_int(TacticalVictory.winner(_blue_to_move(state))).is_equal(TacticalVictory.NOBODY)


func test_red_wins_by_destroying_blue_s_workshop() -> void:
	# One blow left in it: a siege takes turns, and this is the last one.
	var scene: TacticalGame = _mounted_scene()
	var runner: Unit = _first_of(scene.state, RED, TacticalRules.RUNNER)
	scene.state.unit_by_id(runner.id).cell = BLUE_WORKSHOP + Vector2i(-1, 0)
	scene.state.unit_at(BLUE_WORKSHOP).health = 1
	scene.click_cell(BLUE_WORKSHOP + Vector2i(-1, 0))

	scene.click_cell(BLUE_WORKSHOP)

	assert_int(scene.winner).is_equal(RED)
	assert_str(_status_of(scene)).contains("red wins")
	assert_str(_status_of(scene)).contains("destroyed")


func test_standing_beside_the_workshop_is_no_longer_a_win() -> void:
	# T26 retired the stand-in: a workshop is taken by attacking it.
	var state: BoardState = TacticalScenario.build()
	state.unit_by_id(_first_of(state, RED, TacticalRules.RUNNER).id).cell = BLUE_WORKSHOP + Vector2i(-1, 0)

	assert_int(TacticalVictory.winner(state)).is_equal(TacticalVictory.NOBODY)
	assert_int(TacticalVictory.winner(_blue_to_move(state))).is_equal(TacticalVictory.NOBODY)


func test_blue_wins_the_same_way() -> void:
	var scene: TacticalGame = _blue_beside_red_s_workshop()

	scene.play_rest_of_blue_turn()

	assert_int(scene.winner).is_equal(BLUE)


func test_a_tower_does_not_fire_when_a_player_tells_it_to() -> void:
	var state: BoardState = TacticalScenario.build()
	var tower: Unit = _first_of(state, RED, TacticalRules.BOLT_TOWER)
	state.unit_by_id(_first_of(state, BLUE, TacticalRules.RUNNER).id).cell = tower.cell + Vector2i(1, 0)
	var shot := Attack.new(tower.id, _first_of(state, BLUE, TacticalRules.RUNNER).id)

	assert_str(TacticalCombat.why_refused(state, shot)).contains("fires by itself")


func test_once_the_game_is_over_nothing_moves_until_r() -> void:
	var scene: TacticalGame = _blue_beside_red_s_workshop()
	scene.play_rest_of_blue_turn()
	var finished: BoardState = scene.state

	scene.step_decision()
	scene.click_cell(Vector2i(5, 5))

	assert_object(scene.state).is_same(finished)
	scene._press(KEY_R)
	assert_int(scene.winner).is_equal(TacticalVictory.NOBODY)
	assert_int(scene.state.current_faction).is_equal(RED)


# --- the pictures (T9) ------------------------------------------------------

# Which picture each piece gets is the point of T9: the board draws exactly
# `pictures()`, and each unit's must be its side's picture of its kind -- its
# sheet, since T33, for a kind that walks on legs.
func test_every_piece_is_drawn_as_its_side_s_picture_of_its_kind() -> void:
	var scene: TacticalGame = _mounted_scene()
	var drawn: Dictionary = (scene.get_node("UnitView") as UnitView).pictures()
	var alive: int = 0
	for unit: Unit in scene.state.units:
		if unit.is_alive():
			alive += 1
			assert_object(drawn[unit.id]).is_same(Art.texture(_expected_picture(unit)))
	assert_int(drawn.size()).is_equal(alive)


func test_two_kinds_on_one_side_are_two_pictures() -> void:
	var scene: TacticalGame = _mounted_scene()
	var drawn: Dictionary = (scene.get_node("UnitView") as UnitView).pictures()
	var runner: Unit = _first_of(scene.state, RED, TacticalRules.RUNNER)
	var shield: Unit = _first_of(scene.state, RED, TacticalRules.SHIELD)
	assert_object(drawn[runner.id]).is_not_same(drawn[shield.id])


func test_the_board_draws_trees_water_and_the_bridge_as_themselves() -> void:
	var scene: TacticalGame = _mounted_scene()
	var board: BoardView = scene.get_node("BoardView")
	var kinds: Dictionary = {
		TacticalRules.TREES: BoardView.TREES, TacticalRules.WATER: BoardView.WATER,
		TacticalRules.BRIDGE: BoardView.BRIDGE, TacticalRules.ROCK: BoardView.WALL,
	}
	for letter: String in kinds:
		for cell: Vector2i in TacticalRules.cells_of(TacticalScenario.MAP, letter):
			assert_vector(board.get_cell_atlas_coords(cell)).is_equal(kinds[letter])


func test_the_legend_has_one_line_per_kind_of_piece_with_its_picture() -> void:
	var types: Dictionary = TacticalRules.unit_types()
	var lines: Array[Array] = TacticalLegend.entries(types)
	var described: Dictionary = {}
	for line: Array in lines:
		described[line[1]] = line[0]
	for name: String in types:
		var words: String = TacticalLegend.describe(types[name], types)
		assert_bool(described.has(words)).override_failure_message(name + " has no legend line").is_true()
		_assert_same_picture(described.get(words), UnitView.legend_picture(RED, name))


func test_only_the_ram_is_said_to_beat_every_building() -> void:
	var types: Dictionary = TacticalRules.unit_types()
	assert_str(TacticalLegend.describe(types[TacticalRules.RAM], types)).is_equal("ram: moves 2, beats every building")
	assert_str(TacticalLegend.describe(types[TacticalRules.RUNNER], types)).is_equal("runner: moves 6, beats mortar, ram")
	assert_str(TacticalLegend.describe(types[TacticalRules.WATCHTOWER], types)).is_equal("watchtower: fixed")


# --- helpers ---------------------------------------------------------------

# A controller that never does anything: enough to show the scene asks
# whichever one it was given.
class _HoldingBlue extends BlueController:
	func controller_name() -> String:
		return "holds"

	func describe() -> String:
		return "a controller that never moves"

	func decide_build(state: BoardState, workshop_id: int) -> TacticalDecision:
		return TacticalDecision.hold(workshop_id, "holds", state.unit_by_id(workshop_id).cell)

	func decide_move(state: BoardState, unit_id: int) -> TacticalDecision:
		return TacticalDecision.hold(unit_id, "holds", state.unit_by_id(unit_id).cell)


# One game of `rounds` rounds, red at random, every blue decision checked.
# Returns how many blue decisions were checked.
func _play_seeded_game(seed_number: int, rounds: int) -> int:
	var random := RandomNumberGenerator.new()
	random.seed = seed_number
	var state: BoardState = TacticalScenario.build()
	var turn := BlueTurn.new(RuleBasedBlue.new())
	var checked: int = 0
	for round_number: int in range(rounds):
		state = _random_red_turn(state, random)
		# Since T26 blue can destroy red's workshop, and a game that is over
		# has no red turn left to play.
		if TacticalVictory.winner(state) != TacticalVictory.NOBODY:
			break
		turn.begin(state)
		var label: String = "seed %d, round %d" % [seed_number, round_number]
		while not turn.finished():
			state = _checked_play(state, turn, label)
			checked += 1
		assert_array(turn.refused).is_empty()
		if TacticalVictory.winner(state) != TacticalVictory.NOBODY:
			break
		state = TurnStart.open(state)[0]
	return checked


func _checked_play(state: BoardState, turn: BlueTurn, label: String) -> BoardState:
	assert_str(_why_refused(state, turn.next)).override_failure_message(
		"%s: %s" % [label, turn.next.reason]).is_equal(BoardState.LEGAL)
	return turn.play(state)


func _why_refused(state: BoardState, decision: TacticalDecision) -> String:
	match decision.kind():
		"move":
			return state.why_refused(decision.move)
		"build":
			return state.why_production_refused(decision.order)
	return BoardState.LEGAL


# Red's turn played by a coin: a random build if one is affordable, then each
# walker to a random cell it can reach, or nowhere.
func _random_red_turn(state: BoardState, random: RandomNumberGenerator) -> BoardState:
	var workshop: Unit = state.unit_at(RED_WORKSHOP)
	var kind: UnitType = TacticalRules.unit_types()[TacticalRules.BUILDABLE[random.randi_range(0, 3)]]
	var built: BoardState = state.produce(ProductionOrder.new(workshop.id, kind,
		TacticalRules.free_cell_beside(state, workshop, kind)))
	if built != null:
		state = built
	for unit: Unit in state.units_of(RED):
		var walks: Array = TacticalReach.walks_for(state, unit).values()
		if not walks.is_empty():
			var path: Array[Vector2i] = []
			path.assign(walks[random.randi_range(0, walks.size() - 1)])
			state = state.apply(Move.new(unit.id, path))
	return TurnStart.open(state)[0]


func _play_until_red_or_over(scene: TacticalGame) -> void:
	scene.step_decision()
	for guard: int in range(50):
		if scene.winner != TacticalVictory.NOBODY or scene._reds_turn():
			return
		scene.step_decision()


func _blue_to_move(state: BoardState) -> BoardState:
	return TurnStart.open(state)[0]


# A game with blue's runner beside red's workshop, one blow from falling, and
# red's turn ended: blue is about to decide.
func _blue_beside_red_s_workshop() -> TacticalGame:
	var scene: TacticalGame = _mounted_scene()
	scene.state.unit_by_id(_first_of(scene.state, BLUE, TacticalRules.RUNNER).id).cell = RED_WORKSHOP + Vector2i(0, -1)
	scene.state.unit_at(RED_WORKSHOP).health = 1
	scene.step_decision()
	return scene


func _mounted_scene() -> TacticalGame:
	var scene: TacticalGame = auto_free((load("res://game/tactical/tactical.tscn") as PackedScene).instantiate())
	add_child(scene)
	return scene


# Two legend pictures are the same when they are one texture, or two frames
# of one sheet at one place: a frame is built afresh each time it is asked for.
func _assert_same_picture(shown: Variant, expected: Texture2D) -> void:
	if expected is AtlasTexture:
		assert_object((shown as AtlasTexture).atlas).is_same((expected as AtlasTexture).atlas)
		assert_that((shown as AtlasTexture).region).is_equal((expected as AtlasTexture).region)
	else:
		assert_object(shown).is_same(expected)


# The file a unit should be drawn from: its sheet if its kind walks on legs,
# its still picture otherwise.
func _expected_picture(unit: Unit) -> String:
	if Art.sheet_for(unit.faction, unit.type.type_name) != null:
		return Art.sheet_path(unit.faction, unit.type.type_name)
	return Art.unit_path(unit.faction, unit.type.type_name)


func _status_of(scene: TacticalGame) -> String:
	return (scene.get_node("Interface/Status") as Label).text


func _first_of(state: BoardState, faction: int, type_name: String) -> Unit:
	for unit: Unit in state.units_of(faction):
		if unit.type.type_name == type_name:
			return unit
	return null



# --- the wave 29 review ------------------------------------------------------

func test_red_s_units_are_fresh_again_at_red_s_next_turn() -> void:
	var scene: TacticalGame = _mounted_scene()
	var runner: Unit = _first_of(scene.state, RED, TacticalRules.RUNNER)
	scene.wait()
	scene.wait()
	scene.end_turn()

	scene.play_rest_of_blue_turn()

	assert_bool(scene._reds_turn()).is_true()
	assert_bool(scene._turn.is_spent(runner.id)).is_false()
	assert_int(scene._selected_id).is_equal(runner.id)


func test_rule_based_blue_wins_against_a_red_that_only_waits() -> void:
	# The review: aimed at the nearest red piece, blue piled up round a bolt
	# tower for sixty rounds and never won. A game must end, and the reflex
	# opponent must be able to end it.
	var scene: TacticalGame = _mounted_scene()

	for guard: int in range(TacticalVictory.ROUND_LIMIT):
		if scene.winner != TacticalVictory.NOBODY:
			break
		scene.end_turn()
		scene.end_turn()
		scene.play_rest_of_blue_turn()

	assert_int(scene.winner).is_equal(BLUE)
	assert_int(scene.state.turn_number).is_less(10 * TacticalScenario.FACTIONS)


func test_the_round_limit_goes_to_the_higher_score() -> void:
	# Since T47. Untouched, the opening favours blue only by the shield it is
	# given for moving second, which is worth its cost in what is standing.
	var state: BoardState = TacticalScenario.build()
	state.turn_number = TacticalVictory.ROUND_LIMIT * TacticalScenario.FACTIONS

	assert_int(TacticalVictory.winner(state)).is_equal(BLUE)
	assert_str(TacticalVictory.announcement(BLUE, state)).contains("wins on score")


func test_destroying_the_workshop_on_the_last_turn_still_wins() -> void:
	var state: BoardState = TacticalScenario.build()
	state.turn_number = TacticalVictory.ROUND_LIMIT * TacticalScenario.FACTIONS
	state.units.erase(state.unit_at(BLUE_WORKSHOP))

	assert_int(TacticalVictory.winner(state)).is_equal(RED)


func test_a_game_that_is_over_shows_no_next_move() -> void:
	var scene: TacticalGame = _blue_beside_red_s_workshop()

	scene.play_rest_of_blue_turn()

	var intent: IntentView = scene.get_node("IntentView")
	assert_object(intent._decision).is_null()
	assert_bool(scene.decision_overlay().has("next")).is_false()


func test_the_win_rule_is_on_screen_before_anyone_has_won() -> void:
	var scene: TacticalGame = _mounted_scene()
	var header: String = (scene.get_node("Interface/Header") as Label).text

	assert_str(header).contains("destroy the enemy workshop")
	assert_str(header).contains("the higher score wins")


func test_building_with_a_walker_in_hand_does_not_blame_the_workshop() -> void:
	var scene: TacticalGame = _mounted_scene()
	var runner: Unit = _first_of(scene.state, RED, TacticalRules.RUNNER)
	scene.wait()
	scene.click_cell(runner.cell)   # the spent runner, back in hand

	scene.build(0)

	assert_str(_status_of(scene)).not_contains("already built")
	assert_str(_status_of(scene)).contains("does not produce")


func test_enter_plays_the_rest_of_blue_s_turn_and_hands_back() -> void:
	var scene: TacticalGame = _mounted_scene()
	scene.step_decision()

	scene._press(KEY_ENTER)

	assert_bool(scene._reds_turn()).is_true()
	assert_int(scene._blue_turn.played.size()).is_greater(1)


func test_build_undo_and_the_forge_each_cancel_the_end_turn_question() -> void:
	for action: String in ["build", "undo", "buy_forge"]:
		var scene: TacticalGame = _mounted_scene()
		scene.click_cell(RED_WORKSHOP)
		scene.end_turn()
		scene.state.funds[RED] = 20

		if action == "build":
			scene.build(0)
		else:
			scene.call(action)
		scene.end_turn()

		assert_int(scene.state.current_faction).override_failure_message(action).is_equal(RED)


func test_undo_picks_up_a_unit_again_when_the_one_in_hand_is_gone() -> void:
	# The unit in hand is the one just built; taking the build back removes
	# it, and something real must be in hand afterwards.
	var scene: TacticalGame = _mounted_scene()
	scene.click_cell(RED_WORKSHOP)
	scene.build(0)
	scene._selected_id = scene.state.units_of(RED).back().id

	scene.undo()

	assert_object(scene.state.unit_by_id(scene._selected_id)).is_not_null()


func test_the_overlay_and_the_status_carry_what_blue_did_and_why() -> void:
	var scene: TacticalGame = _mounted_scene()
	scene.step_decision()
	var shown: TacticalDecision = scene._blue_turn.next
	assert_str(_status_of(scene)).contains(shown.reason)

	scene.step_decision()

	assert_str(scene.decision_overlay()["played"][0]["why"]).is_equal(shown.reason)
