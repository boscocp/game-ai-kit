# T12's levels on the tactical board: each decision is one the board
# accepts, none depends on the dice the board will roll, the noise is the
# level's own, and the person can take either side. That the levels are
# ordered is `difficulty_matches.gd`'s, and that they never cheat is
# `difficulty_knobs.gd`'s; these are the claims a single board can hold.
extends GdUnitTestSuite


# The header these tests read is the screen's, in the language on it: the
# engine starts in the system's locale, so the suite pins English. The
# reasons they read need no pin, being kept in English (T104). The locale
# found is put back.
var _locale_before: String


func before() -> void:
	_locale_before = TranslationServer.get_locale()
	TranslationServer.set_locale("en")


func after() -> void:
	TranslationServer.set_locale(_locale_before)


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
	assert_str(decision.english()).is_equal(RuleBasedBlue.new().decide_build(state, workshop.id).english() + " (the plan buys nothing more: the rules decide)")


func test_a_search_that_chose_no_attack_is_not_overruled_after_the_walk() -> void:
	var state: BoardState = TacticalScenario.build()
	var shield: Unit = _red(state, TacticalRules.SHIELD)
	var runner: Unit = _blue(state, TacticalRules.RUNNER)
	runner.cell = shield.cell + Vector2i.RIGHT
	var level := LeveledBlue.new(Difficulty.named("hard"), 1)
	level.begin_turn(state)

	# Asked with nothing chosen, it takes the fight a shield wins against a runner...
	assert_object(level.decide_attack(state, shield.id)).is_not_null()
	# ...and asked after a search that chose none, it keeps to that.
	level._strike[shield.id] = LeveledBlue.CHOSE_NOT_TO
	assert_object(level.decide_attack(state, shield.id)).is_null()


func test_a_walker_that_leaves_the_rules_walk_leaves_their_goals_unclaimed() -> void:
	var state: BoardState = _the_middle_of_a_game()
	var left_the_rules: int = 0
	for unit: Unit in state.units_of(state.current_faction):
		if not unit.type.mobile:
			continue
		var level := LeveledBlue.new(Difficulty.named("hard"), 1)
		level.begin_turn(state)
		var rules := RuleBasedBlue.new()
		var by_the_rules: TacticalDecision = rules.decide_move(state, unit.id)
		var chosen: TacticalDecision = level.decide_move(state, unit.id)
		if chosen.target != by_the_rules.target:
			left_the_rules += 1
			assert_dict(level._claims).is_empty()
	assert_int(left_the_rules).is_greater(0)


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


func test_the_computer_playing_red_never_calls_the_persons_side_red() -> void:
	var scene: TacticalGame = auto_free((load("res://game/tactical/tactical.tscn") as PackedScene).instantiate())
	add_child(scene)
	scene.swap_sides()

	assert_str(scene._header.text).contains("you play blue; red is played by")
	while scene._computer_thinking():
		var said: String = scene._computer_turn.next.english()
		assert_str(said).not_contains("red piece")
		assert_str(said).not_contains("red's workshop")
		scene.step_decision()


func test_the_person_on_blue_can_take_back_a_build_and_end_the_turn() -> void:
	var scene: TacticalGame = auto_free((load("res://game/tactical/tactical.tscn") as PackedScene).instantiate())
	add_child(scene)
	scene.swap_sides()
	scene.play_rest_of_computer_turn()
	var workshop: Unit = scene.state.units_of(TacticalScenario.BLUE).filter(func(unit: Unit) -> bool: return not unit.type.produces.is_empty())[0]
	var funds: int = scene.state.funds_of(TacticalScenario.BLUE)

	scene.click_cell(workshop.cell)
	scene.build(0)
	assert_int(scene.state.funds_of(TacticalScenario.BLUE)).is_less(funds)
	scene.undo()
	assert_int(scene.state.funds_of(TacticalScenario.BLUE)).is_equal(funds)
	scene.end_turn()
	scene.end_turn()
	assert_int(scene.state.current_faction).is_equal(TacticalScenario.RED)
	assert_bool(scene._computer_thinking()).is_true()


func test_a_new_game_the_computer_opens_does_not_show_the_last_games_news() -> void:
	var scene: TacticalGame = auto_free((load("res://game/tactical/tactical.tscn") as PackedScene).instantiate())
	add_child(scene)
	scene.swap_sides()
	scene._last_event.assign([Sentence.of("the red runner destroyed the blue workshop")])

	scene.new_game()

	assert_str(scene._status.text).not_contains("destroyed the blue workshop")


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
			said.append("%s %s %s" % [decision.kind(), decision.target, decision.english()])
	return said


static func _red(state: BoardState, type_name: String) -> Unit:
	return state.units_of(TacticalScenario.RED).filter(func(unit: Unit) -> bool: return unit.type.type_name == type_name)[0]


static func _blue(state: BoardState, type_name: String) -> Unit:
	return state.units_of(TacticalScenario.BLUE).filter(func(unit: Unit) -> bool: return unit.type.type_name == type_name)[0]
