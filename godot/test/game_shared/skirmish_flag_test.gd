# T41: "I stand on the white flag and the AI stays at the top, and nothing
# happens." Reproduced headless before the change: red's unit on the node at
# (2, 6), red ending every turn, and for as long as anyone cared to press
# space blue's two units stood where they were -- one beside red's other unit
# "attacking" (the skirmish has no attack that does anything), one "retreating". No rule gave a
# node any meaning, and the policy's models were never told who stands where.
#
# Decided with the owner: holding a node ends the game (`SkirmishVictory`),
# and a blue unit with no fight to weigh walks at a node an enemy stands on.
# The policy's own cases for that rule are in `learned_policy_test.gd`.
extends GdUnitTestSuite

const RED: int = BoardGame.RED
const BLUE: int = BoardGame.BLUE
const FLAG := Vector2i(2, 6)


func test_three_turn_starts_on_a_node_win() -> void:
	var victory := SkirmishVictory.new([FLAG] as Array[Vector2i])
	var state: BoardState = _board_with([[RED, FLAG]], RED)

	for turn: int in range(SkirmishVictory.HOLD_TURNS - 1):
		victory.turn_started(state)
	assert_int(victory.winner).is_equal(SkirmishVictory.NOBODY)
	victory.turn_started(state)

	assert_int(victory.winner).is_equal(RED)


func test_an_enemy_beside_the_node_breaks_the_hold_and_the_count_starts_again() -> void:
	var victory := SkirmishVictory.new([FLAG] as Array[Vector2i])
	victory.turn_started(_board_with([[RED, FLAG]], RED))
	victory.turn_started(_board_with([[RED, FLAG]], RED))

	victory.turn_started(_board_with([[RED, FLAG], [BLUE, FLAG + Vector2i.RIGHT]], RED))
	victory.turn_started(_board_with([[RED, FLAG]], RED))
	victory.turn_started(_board_with([[RED, FLAG]], RED))

	assert_int(victory.winner).is_equal(SkirmishVictory.NOBODY)
	assert_str(victory.progress(_board_with([[RED, FLAG]], RED), BoardGame.SIDE_NAMES)).contains("2 of %d" % SkirmishVictory.HOLD_TURNS)


func test_the_owner_s_game_ends_red_holding_the_flag_wins() -> void:
	# Red stands on the flag and only ends its turns. Red's other unit is
	# beside blue, so both blue units have a fight to weigh and none comes
	# to the flag: three turn starts later red has won, and the screen says so.
	var game: BoardGame = _mounted_scene()
	game._state.unit_by_id(1).cell = FLAG

	_press_until_over(game)

	assert_int(game._victory.winner).is_equal(RED)
	assert_str(game._status.text).contains("red wins")


func test_once_the_game_is_won_nothing_moves() -> void:
	var game: BoardGame = _mounted_scene()
	game._state.unit_by_id(1).cell = FLAG
	_press_until_over(game)
	var turn: int = game._state.turn_number

	game.step_decision()
	game._click_cell(FLAG + Vector2i.UP)

	assert_int(game._state.turn_number).is_equal(turn)
	assert_object(game._state.unit_at(FLAG)).is_not_null()


func test_blue_with_no_fight_to_weigh_comes_to_the_flag_and_breaks_the_hold() -> void:
	# Red's other unit is sent to the far corner, so blue has nothing to fight
	# and the contest rule is what moves it.
	var game: BoardGame = _mounted_scene()
	game._state.unit_by_id(1).cell = FLAG
	game._state.unit_by_id(2).cell = Vector2i(0, 0)

	var contested: bool = false
	for press: int in range(60):
		game.step_decision()
		contested = contested or SkirmishVictory.holder_of(game._state, FLAG) == SkirmishVictory.NOBODY
		if contested or game._victory.winner != SkirmishVictory.NOBODY:
			break

	assert_bool(contested).override_failure_message("blue never came to the flag").is_true()


func test_a_held_count_is_shown_only_while_the_hold_lasts() -> void:
	# The review: with blue already beside the flag the screen still said
	# "red holds the node at (2, 6): 2 of 3 turns".
	var victory := SkirmishVictory.new([FLAG] as Array[Vector2i])
	victory.turn_started(_board_with([[RED, FLAG]], RED))
	var broken: BoardState = _board_with([[RED, FLAG], [BLUE, FLAG + Vector2i.RIGHT]], BLUE)

	assert_str(victory.progress(broken, BoardGame.SIDE_NAMES)).is_empty()


func _press_until_over(game: BoardGame) -> void:
	for press: int in range(60):
		if game._victory.winner != SkirmishVictory.NOBODY:
			return
		game.step_decision()


func _board_with(placed: Array, to_move: int) -> BoardState:
	var units: Array[Unit] = []
	for entry: Array in placed:
		units.append(Unit.new(units.size() + 1, entry[0], entry[1], 10, BoardGame.POINTS_PER_TURN))
	return BoardState.new(GridGraph.new(BoardGame.COLUMNS, BoardGame.ROWS), units, to_move)


func _mounted_scene() -> BoardGame:
	var game: BoardGame = auto_free((load("res://game/main.tscn") as PackedScene).instantiate())
	add_child(game)
	return game


func test_a_game_nobody_wins_is_a_draw_at_the_round_limit() -> void:
	var victory := SkirmishVictory.new([FLAG] as Array[Vector2i], 2)
	var state: BoardState = _board_with([[RED, Vector2i(0, 0)]], RED)
	state.turn_number = SkirmishVictory.ROUND_LIMIT * 2

	victory.turn_started(state)

	assert_int(victory.winner).is_equal(SkirmishVictory.DRAW)
	assert_str(SkirmishVictory.announcement(victory.winner, BoardGame.SIDE_NAMES)).contains("a draw")
