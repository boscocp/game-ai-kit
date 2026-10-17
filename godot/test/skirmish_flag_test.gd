# T41: "I stand on the white flag and the AI stays at the top, and nothing
# happens." Reproduced headless before the change: red's unit on the node at
# (2, 6), red ending every turn, and for as long as anyone cared to press
# space blue's two units stood where they were -- one beside red's other unit
# "attacking" (there is no attack until T10), one "retreating". No rule gave a
# node any meaning, and the policy's models were never told who stands where.
#
# Decided with the owner: holding a node ends the game (`SkirmishVictory`),
# and the policy walks first at a node an enemy stands on.
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
	assert_str(victory.progress(BoardGame.SIDE_NAMES)).contains("2 of %d" % SkirmishVictory.HOLD_TURNS)


func test_the_policy_walks_at_a_node_an_enemy_stands_on() -> void:
	var game: BoardGame = _mounted_scene()
	game._state.unit_by_id(1).cell = FLAG
	game.step_decision()

	var decision: LearnedDecision = game._plan

	assert_str(decision.action).is_equal(LearnedDecision.CONTEST)
	assert_str(decision.reason).contains("a rule, not the model")


func test_standing_on_the_flag_makes_something_happen() -> void:
	# The owner's game, played to the end: red stands on the flag and only
	# ends its turns. Either blue breaks the hold, or red wins it.
	var game: BoardGame = _mounted_scene()
	game._state.unit_by_id(1).cell = FLAG

	var contested: bool = false
	for press: int in range(200):
		if game._victory.winner != SkirmishVictory.NOBODY:
			break
		game.step_decision()
		contested = contested or SkirmishVictory.holder_of(game._state, FLAG) == SkirmishVictory.NOBODY

	assert_bool(contested or game._victory.winner == RED).is_true()
	assert_bool(contested).override_failure_message("blue never came to the flag").is_true()


func _board_with(placed: Array, to_move: int) -> BoardState:
	var units: Array[Unit] = []
	for entry: Array in placed:
		units.append(Unit.new(units.size() + 1, entry[0], entry[1], 10, BoardGame.POINTS_PER_TURN))
	return BoardState.new(GridGraph.new(BoardGame.COLUMNS, BoardGame.ROWS), units, to_move)


func _mounted_scene() -> BoardGame:
	var game: BoardGame = auto_free((load("res://game/main.tscn") as PackedScene).instantiate())
	add_child(game)
	return game
