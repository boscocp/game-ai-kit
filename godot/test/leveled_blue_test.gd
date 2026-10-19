# T12's levels on the tactical board: each decision is one the board
# accepts, none depends on the dice the board will roll, the noise is the
# level's own, and the person can take either side. That the levels are
# ordered is `difficulty_matches.gd`'s, and that they never cheat is
# `difficulty_knobs.gd`'s; these are the claims a single board can hold.
extends GdUnitTestSuite


func test_every_level_plays_a_game_the_board_accepts_every_decision_of() -> void:
	for level: Difficulty in Difficulty.presets():
		var result: Dictionary = TacticalMatch.play(LeveledBlue.new(level, 1), RuleBasedBlue.new(), 3)

		assert_array(result["refused"]).is_empty()
		assert_int(result["winner"]).is_not_equal(TacticalVictory.NOBODY)


func test_a_level_decides_the_same_whatever_the_board_will_roll_next() -> void:
	var state: BoardState = _the_middle_of_a_game()
	for level: Difficulty in Difficulty.presets():
		var rolled_one_way: Array[String] = _decisions(LeveledBlue.new(level, 5), state, 11)
		var rolled_another: Array[String] = _decisions(LeveledBlue.new(level, 5), state, 999999)

		assert_array(rolled_another).is_equal(rolled_one_way)


func test_the_noise_is_drawn_from_the_seed_the_level_was_given() -> void:
	var state: BoardState = _the_middle_of_a_game()
	var noisy: Difficulty = Difficulty.named("easy")

	assert_array(_decisions(LeveledBlue.new(noisy, 5), state, 11)).is_equal(_decisions(LeveledBlue.new(noisy, 5), state, 11))
	assert_array(_decisions(LeveledBlue.new(noisy, 6), state, 11)).is_not_equal(_decisions(LeveledBlue.new(noisy, 5), state, 11))


func test_a_horizon_of_no_actions_makes_no_plan_and_buys_by_the_rules() -> void:
	var state: BoardState = TacticalScenario.build()
	var level := LeveledBlue.new(Difficulty.new("no plan", 0, 1, 0.0), 1)
	var workshop: Unit = state.units_of(TacticalScenario.RED).filter(func(unit: Unit) -> bool: return not unit.type.produces.is_empty())[0]

	var decision: TacticalDecision = level.decide_build(state, workshop.id)

	assert_object(level.plan).is_null()
	assert_str(decision.reason).is_equal(RuleBasedBlue.new().decide_build(state, workshop.id).reason + " (the plan buys nothing more: the rules decide)")


func test_the_person_can_take_blue_and_the_computer_plays_red_first() -> void:
	var scene: TacticalGame = auto_free((load("res://game/tactical/tactical.tscn") as PackedScene).instantiate())
	scene.computer = LeveledBlue.new(Difficulty.named("hard"), 1)
	add_child(scene)

	scene.swap_sides()

	assert_int(scene.person_side).is_equal(TacticalScenario.BLUE)
	assert_str(scene.decision_overlay()["to_move"]).is_equal("red")
	assert_dict(scene.decision_overlay()).contains_keys(["next"])
	scene.play_rest_of_computer_turn()
	assert_int(scene.state.current_faction).is_equal(TacticalScenario.BLUE)
	assert_bool(scene._persons_turn()).is_true()


func test_swapping_sides_keeps_the_level_the_computer_plays_at() -> void:
	var scene: TacticalGame = auto_free((load("res://game/tactical/tactical.tscn") as PackedScene).instantiate())
	scene.computer = LeveledBlue.new(Difficulty.named("normal"), 1)
	add_child(scene)

	scene.swap_sides()
	scene.swap_sides()

	assert_int(scene.person_side).is_equal(TacticalScenario.RED)
	assert_str(scene.computer.controller_name()).is_equal("normal")


# The board at the start of red's twelfth turn of a rules mirror: enough
# pieces out that a level has choices to make.
static func _the_middle_of_a_game() -> BoardState:
	var kept: Array = [null]
	TacticalMatch.play(RuleBasedBlue.new(), RuleBasedBlue.new(), 2, func(state: BoardState) -> void:
		if state.turn_number == 22:
			kept[0] = state.duplicate_state())
	return kept[0]


# What `controller` decides for each of the side to move's walkers on
# `state` with the board's dice seeded `dice_seed`, as words -- a walk, its
# cell and its reason.
static func _decisions(controller: LeveledBlue, state: BoardState, dice_seed: int) -> Array[String]:
	var board: BoardState = state.duplicate_state()
	board.dice_seed = dice_seed
	controller.begin_turn(board)
	var said: Array[String] = []
	for unit: Unit in board.units_of(board.current_faction):
		if unit.type.mobile:
			var decision: TacticalDecision = controller.decide_move(board, unit.id)
			said.append("%s %s %s" % [decision.kind(), decision.target, decision.reason])
	return said
