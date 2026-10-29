# T98 in the engine: the MDP's published policy read and played, in the
# regime it was solved for -- Blinky alone, chasing for ever.
#
# The vectors (`make test-mdp-vectors`) hold ten states' values and moves to
# a third reading of the rules; these hold the reader on its own: the slot
# arithmetic is Python's, the lookahead over the published values always
# finds the policy's move best (the policy is the greedy one over those
# values, so a disagreement means the two languages' rules have drifted),
# and the policy plays seeded games to the end without being caught.
extends GdUnitTestSuite

const GAMES: int = 40
const STEPS: int = 400
## The start state's slot, as `gameaikit.mdp.maze.index` numbers it.
const START_SLOT: int = 154335
const SLOTS: int = 173056

var _locale_before: String = ""


func before() -> void:
	_locale_before = TranslationServer.get_locale()


func before_test() -> void:
	TranslationServer.set_locale("en")


func after() -> void:
	TranslationServer.set_locale(_locale_before)


func test_the_tables_are_published_and_laid_out_as_python_lays_them() -> void:
	assert_bool(MdpPacMan.is_published()).is_true()
	assert_int(MdpPacMan.slot_of(_game())).is_equal(START_SLOT)
	assert_bool(is_nan(MdpPacMan.value_at(SLOTS - 1))).is_true()
	assert_bool(is_nan(MdpPacMan.value_at(START_SLOT))).is_false()
	assert_str(MdpPacMan.policy_letter(SLOTS)).is_equal(".")


func test_the_mdp_regime_chases_from_the_first_step_and_never_reverses() -> void:
	var game: MazeGame = _game()
	var mdp := MdpPacMan.new()
	while game.is_playing() and game.steps < STEPS:
		assert_str(game.mode()).is_equal(MazeRules.CHASE)
		assert_str(game.ghosts[0].decision["kind"]).is_not_equal(MazeGhost.REVERSAL)
		game.step(mdp.move_for(game))
	assert_str(MazeGame.new(1).mode()).is_equal(MazeRules.SCATTER)


func test_blinkys_chances_are_the_rules() -> void:
	var game: MazeGame = _game()
	var blinky: MazeGhost = game.ghosts[0]
	blinky.cell = Vector2i(5, 3)
	blinky.heading = "right"
	var chances: Dictionary = MazeGhost.chances(blinky.ways(game.pacman), MazeRules.CHASE)
	# Up leads to (5, 2), 26 from Pac-Man squared; right to (6, 3), 16: the Dossier's way.
	assert_array(chances.keys()).is_equal(["up", "right"])
	assert_float(chances["right"]).is_equal_approx(0.8 + 0.2 / 2.0, 1e-12)
	assert_float(chances["up"]).is_equal_approx(0.2 / 2.0, 1e-12)
	var scatter: Dictionary = MazeGhost.chances(blinky.ways(game.pacman), MazeRules.SCATTER)
	assert_float(scatter["right"]).is_equal(1.0)
	assert_float(scatter["up"]).is_equal(0.0)


func test_the_lookahead_finds_the_policys_move_best_in_every_state_played() -> void:
	var mdp := MdpPacMan.new()
	var checked: int = 0
	for seed_number: int in range(1, GAMES + 1):
		var game: MazeGame = _game(seed_number)
		while game.is_playing() and game.steps < STEPS:
			var moves: Array[Dictionary] = mdp.lookahead(game)
			var best: float = moves.map(func(move: Dictionary) -> float: return move["q"]).max()
			var chosen: Dictionary = moves.filter(func(move: Dictionary) -> bool: return move["chosen"])[0]
			assert_bool(moves.all(func(move: Dictionary) -> bool: return not is_nan(move["q"]))).is_true()
			assert_float(chosen["q"]).is_greater_equal(best - 1e-9)
			checked += 1
			game.step(mdp.move_for(game))
	assert_int(checked).is_greater(GAMES * 10)


func test_the_policy_wins_every_seeded_game_without_being_caught() -> void:
	var mdp := MdpPacMan.new()
	for seed_number: int in range(1, GAMES + 1):
		var game: MazeGame = _game(seed_number)
		while game.is_playing() and game.steps < STEPS:
			game.step(mdp.move_for(game))
		assert_str(game.outcome).is_equal(MazeGame.WON)


func test_the_value_map_covers_every_cell_pac_man_could_stand_on() -> void:
	var game: MazeGame = _game()
	var values: Dictionary = MdpPacMan.value_map(game)
	# 52 floor cells, less Blinky's and the four with a pellet on them.
	assert_int(values.size()).is_equal(52 - 1 - 4)
	assert_float(values[game.pacman]["value"]).is_equal(MdpPacMan.value_at(START_SLOT))
	assert_str(values[game.pacman]["move"]).is_equal(MdpPacMan.new().move_for(game))


func test_c_hands_pac_man_to_the_mdp_and_back() -> void:
	var demo: MazeDemo = auto_free(load("res://game/maze/maze.tscn").instantiate())
	add_child(demo)
	_press(demo, KEY_C)
	assert_bool(demo.mdp_playing).is_true()
	assert_int(demo.game.ghosts.size()).is_equal(1)
	assert_str(demo.game.mode()).is_equal(MazeRules.CHASE)
	_press(demo, KEY_G)
	assert_int(demo.game.ghosts.size()).is_equal(1)
	demo.step_decision()
	var overlay: Dictionary = demo.decision_overlay()
	assert_str(overlay["controller"]).is_equal("mdp")
	assert_int(overlay["mdp"]["moves"].size()).is_equal(4)
	assert_bool(overlay["mdp"]["value"] is float).is_true()
	assert_str(demo.get_node("Interface/Decision").text).contains("value iteration")
	assert_str(demo.get_node("Interface/Status").text).contains("C: you play")
	_press(demo, KEY_C)
	assert_bool(demo.mdp_playing).is_false()
	assert_str(demo.game.mode()).is_equal(MazeRules.SCATTER)
	assert_bool(demo.decision_overlay().has("mdp")).is_false()


func test_c_without_a_published_policy_keeps_your_game_and_says_why() -> void:
	var demo: MazeDemo = auto_free(load("res://game/maze/maze.tscn").instantiate())
	add_child(demo)
	demo.started = true
	demo.play_step()
	var before: MazeGame = demo.game
	demo.hand_over(false)
	assert_bool(demo.mdp_playing).is_false()
	assert_object(demo.game).is_same(before)
	assert_str(demo.get_node("Interface/Status").text).contains("make solve-maze")
	_press(demo, KEY_V)
	assert_str(demo.get_node("Interface/Status").text).not_contains("make solve-maze")


func _game(seed_number: int = 1) -> MazeGame:
	return MazeGame.new(seed_number, MdpPacMan.spec()["ghosts"], MdpPacMan.spec()["schedule"])


func _press(demo: MazeDemo, keycode: Key) -> void:
	var press := InputEventKey.new()
	press.keycode = keycode
	press.pressed = true
	demo._unhandled_input(press)
