# T97 in the engine: the maze's rules one at a time, the properties over
# seeded games -- no ghost reverses outside a mode change, every mode change
# reverses, no ghost enters a wall, a seeded game replays -- and the scene
# showing each ghost's decision before it moves.
#
# The vectors (`make test-maze-vectors`) hold this game to the Python one
# step by step; these hold it to the Dossier's rules on its own. Pac-Man's
# moves in the seeded games are drawn from a second `GakXorshift`, so the
# games are the same on every run and every machine.
extends GdUnitTestSuite

const GAMES: int = 120
const STEPS: int = 160
const MOVES: Array[String] = ["up", "left", "down", "right"]

var _locale_before: String = ""


func before() -> void:
	_locale_before = TranslationServer.get_locale()


func before_test() -> void:
	TranslationServer.set_locale("en")


func after() -> void:
	TranslationServer.set_locale(_locale_before)


func test_the_maze_is_small_with_no_dead_end_and_four_pellets() -> void:
	var cells: Array[Vector2i] = MazeRules.floor_cells()
	assert_int(cells.size()).is_equal(52)
	for cell: Vector2i in cells:
		var exits: int = MOVES.filter(func(way: String) -> bool: return MazeRules.is_open(MazeRules.moved(cell, way))).size()
		assert_int(exits).is_greater_equal(2)
	assert_int(MazeGame.new().pellets.size()).is_equal(4)


func test_the_schedule_is_the_dossiers_level_one_in_steps() -> void:
	assert_str(MazeRules.mode_at(13)).is_equal(MazeRules.SCATTER)
	assert_str(MazeRules.mode_at(14)).is_equal(MazeRules.CHASE)
	assert_str(MazeRules.mode_at(54)).is_equal(MazeRules.SCATTER)
	assert_str(MazeRules.mode_at(10000)).is_equal(MazeRules.CHASE)


func test_each_ghost_aims_at_its_own_target() -> void:
	var blinky := MazeGhost.new("blinky")
	var pinky := MazeGhost.new("pinky")
	assert_that(blinky.target(MazeRules.SCATTER, Vector2i(6, 7), "left")).is_equal(Vector2i(11, -2))
	assert_that(pinky.target(MazeRules.SCATTER, Vector2i(6, 7), "left")).is_equal(Vector2i(1, -2))
	assert_that(blinky.target(MazeRules.CHASE, Vector2i(3, 5), "up")).is_equal(Vector2i(3, 5))
	assert_that(pinky.target(MazeRules.CHASE, Vector2i(6, 7), "left")).is_equal(Vector2i(2, 7))
	# Facing up, Pinky's target is four up and -- the arcade's bug -- four left.
	assert_that(pinky.target(MazeRules.CHASE, Vector2i(6, 7), "up")).is_equal(Vector2i(2, 3))


func test_the_way_back_is_never_offered_and_a_tie_goes_up_left_down_right() -> void:
	var ghost := MazeGhost.new("blinky")
	ghost.cell = Vector2i(3, 3)
	ghost.heading = "right"
	var ways: Array[Dictionary] = ghost.ways(Vector2i(4, 4))
	assert_array(ways.map(func(way: Dictionary) -> String: return way["direction"])).is_equal(["down", "right"])
	assert_int(ways[0]["squared"]).is_equal(ways[1]["squared"])
	assert_str(MazeGhost.nearest(ways)).is_equal("down")


func test_up_wins_a_tie_with_left_however_the_ways_are_listed() -> void:
	var ghost := MazeGhost.new("blinky")
	ghost.cell = Vector2i(5, 3)
	ghost.heading = "left"
	# (4, 2) is one cell from both (5, 2), up, and (4, 3), left.
	var ways: Array[Dictionary] = ghost.ways(Vector2i(4, 2))
	assert_array(ways.map(func(way: Dictionary) -> int: return way["squared"])).is_equal([1, 1])
	assert_str(MazeGhost.nearest(ways)).is_equal("up")
	var listed_backwards: Array[Dictionary] = ways.duplicate()
	listed_backwards.reverse()
	assert_str(MazeGhost.nearest(listed_backwards)).is_equal("up")


func test_the_first_draw_decides_keeping_and_the_second_picks_the_way() -> void:
	var ghost := MazeGhost.new("blinky")
	ghost.cell = Vector2i(3, 3)
	ghost.heading = "right"
	var ways: Array[Dictionary] = ghost.ways(Vector2i(4, 4))
	# One stream, as in a game: a small seed's first draw is small, so fresh
	# seeds would almost never reach the second draw.
	var dice := GakXorshift.new(11)
	var mirror := GakXorshift.new(11)
	var turns: int = 0
	for _fork: int in range(300):
		var wanted: Array = [MazeGhost.NEAREST, "down"]
		if mirror.uniform() >= MazeRules.precision():
			wanted = [MazeGhost.DICE, ways[mirror.next() % ways.size()]["direction"]]
			turns += 1
		var choice: Dictionary = MazeGhost.choose(ways, MazeRules.CHASE, dice)
		assert_array([choice["kind"], choice["chosen"]]).is_equal(wanted)
	assert_int(turns).is_greater(30)


func test_scatter_and_a_single_way_draw_no_dice() -> void:
	var ghost := MazeGhost.new("blinky")
	ghost.cell = Vector2i(3, 3)
	ghost.heading = "right"
	var dice := GakXorshift.new(5)
	assert_str(MazeGhost.choose(ghost.ways(Vector2i(4, 4)), MazeRules.SCATTER, dice)["kind"]).is_equal(MazeGhost.NEAREST)
	ghost.cell = Vector2i(5, 2)
	ghost.heading = "up"
	assert_str(MazeGhost.choose(ghost.ways(Vector2i.ZERO), MazeRules.CHASE, dice)["kind"]).is_equal(MazeGhost.ONLY_WAY)
	assert_int(dice.next()).is_equal(GakXorshift.new(5).next())


func test_in_chase_the_dice_overrule_the_dossier_about_one_time_in_ten_at_a_fork_of_two() -> void:
	var ghost := MazeGhost.new("blinky")
	ghost.cell = Vector2i(3, 3)
	ghost.heading = "right"
	var ways: Array[Dictionary] = ghost.ways(Vector2i(4, 4))
	var dice := GakXorshift.new(11)
	var other: int = 0
	for _draw: int in range(20000):
		if MazeGhost.choose(ways, MazeRules.CHASE, dice)["chosen"] != "down":
			other += 1
	# (1 - 0.8) / 2 of the time the dice pick the way that is not the Dossier's.
	assert_float(other / 20000.0).is_equal_approx((1.0 - MazeRules.precision()) / 2.0, 0.01)


func test_into_a_wall_pac_man_stays_and_walking_onto_a_ghost_is_a_catch() -> void:
	var game := MazeGame.new(1)
	game.step("down")
	assert_that(game.pacman).is_equal(Vector2i(6, 7))
	assert_str(game.facing).is_equal("left")
	game.pacman = Vector2i(4, 3)
	game.ghosts[0].cell = Vector2i(3, 3)
	game.step("left")
	assert_str(game.outcome).is_equal(MazeGame.CAUGHT)


func test_a_ghost_walking_onto_pac_man_catches_him() -> void:
	var game := MazeGame.new(1)
	game.pacman = Vector2i(3, 3)
	game.ghosts[0].cell = Vector2i(4, 3)
	game.ghosts[0].next_move = "left"
	game.step("up")  # a wall: he stays on (3, 3), and the ghost walks onto him
	assert_str(game.outcome).is_equal(MazeGame.CAUGHT)
	assert_that(game.ghosts[0].cell).is_equal(Vector2i(3, 3))


func test_the_last_pellet_wins_before_the_ghosts_move() -> void:
	var game := MazeGame.new(1)
	game.pellets = [Vector2i(5, 7)] as Array[Vector2i]
	var ghost_was: Vector2i = game.ghosts[0].cell
	game.step("left")
	assert_str(game.outcome).is_equal(MazeGame.WON)
	assert_that(game.ghosts[0].cell).is_equal(ghost_was)


func test_no_ghost_reverses_outside_a_mode_change_and_every_change_reverses() -> void:
	var records: Array[Dictionary] = _every_step()
	assert_int(records.size()).is_greater(1000)
	var reversals: int = 0
	for record: Dictionary in records:
		var changed: bool = _mode_changed_at(record["steps"])
		var wanted: Array = record["before"].map(func(_heading: String) -> bool: return changed)
		assert_array(_reversed(record)).override_failure_message("step %s" % record).is_equal(wanted)
		reversals += 1 if changed else 0
	# A property no game ever reached would hold nothing.
	assert_int(reversals).is_greater(10)


func test_no_ghost_enters_a_wall() -> void:
	for record: Dictionary in _every_step():
		assert_bool(record["cells"].all(MazeRules.is_open)).is_true()


func test_a_seeded_game_replays_and_the_seed_matters() -> void:
	var first: Array = _trace(7)
	assert_array(_trace(7)).is_equal(first)
	var different: int = 0
	for seed_number: int in range(20):
		if str(_trace(seed_number)) != str(first):
			different += 1
	assert_int(different).is_greater(0)


func test_the_scene_shows_each_ghost_deciding_before_it_moves() -> void:
	var demo: MazeDemo = auto_free(load("res://game/maze/maze.tscn").instantiate())
	add_child(demo)
	for _step: int in range(3):
		demo.step_decision()
	var ghost: Dictionary = demo.decision_overlay()["ghosts"][0]
	assert_that(ghost["target"]).is_equal(demo.game.ghosts[0].decision["target"])
	assert_str(ghost["chosen"]).is_equal(demo.game.ghosts[0].next_move)
	assert_bool(ghost["ways"].size() >= 1 and ghost["ways"][0].has("distance")).is_true()
	assert_str(demo.get_node("Interface/Decision").text).contains("BLINKY")


func test_g_brings_pinky_in() -> void:
	var demo: MazeDemo = auto_free(load("res://game/maze/maze.tscn").instantiate())
	add_child(demo)
	var press := InputEventKey.new()
	press.keycode = KEY_G
	press.pressed = true
	demo._unhandled_input(press)
	assert_int(demo.game.ghosts.size()).is_equal(2)
	assert_str(demo.get_node("Interface/Decision").text).contains("PINKY")


# Every step of GAMES seeded games with both ghosts and random runs of moves:
# before and after it, each ghost's heading, and where each ghost stands.
func _every_step() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for seed_number: int in range(GAMES):
		records += _played(seed_number)
	return records


func _played(seed_number: int) -> Array[Dictionary]:
	var game := MazeGame.new(seed_number, ["blinky", "pinky"])
	var chooser := GakXorshift.new(seed_number + 1000)
	var records: Array[Dictionary] = []
	var move: String = "left"
	while game.is_playing() and game.steps < STEPS:
		if chooser.index(4) == 0:
			move = MOVES[chooser.index(4)]
		var record: Dictionary = {"seed": seed_number, "steps": game.steps, "before": _headings(game)}
		game.step(move)
		record.merge({"after": _headings(game), "cells": _cells(game)})
		if game.is_playing():
			records.append(record)
	return records


func _headings(game: MazeGame) -> Array:
	return game.ghosts.map(func(ghost: MazeGhost) -> String: return ghost.heading)


func _cells(game: MazeGame) -> Array:
	return game.ghosts.map(func(ghost: MazeGhost) -> Vector2i: return ghost.cell)


# Whether the move made in step `steps` was chosen across a mode change.
func _mode_changed_at(steps: int) -> bool:
	return steps > 0 and MazeRules.mode_at(steps) != MazeRules.mode_at(steps - 1)


# For each ghost, whether its move in this step went back the way it came.
func _reversed(record: Dictionary) -> Array:
	var found: Array = []
	for index: int in range(record["before"].size()):
		found.append(record["after"][index] == MazeRules.reverse(record["before"][index]))
	return found


func _trace(seed_number: int) -> Array:
	var game := MazeGame.new(seed_number, ["blinky", "pinky"])
	var trace: Array = [game.snapshot()]
	for index: int in range(60):
		game.step(MOVES[(index / 5) % 4])
		trace.append(game.snapshot())
	return trace


# T121: the maze vectors runner refuses a file of the wrong types before it
# reads one. Moves or a trace given as text, in a copy of a real file, were
# a SCRIPT ERROR that skipped the check and let the runner exit 0 or 1.
func test_a_maze_vector_of_the_wrong_types_is_refused() -> void:
	var runner: GDScript = preload("res://test/maze/maze_vectors_runner.gd")
	var vector: Dictionary = VectorShape.read_spec("vectors/maze/an-imprecise-turn-in-chase.json")
	assert_str(VectorShape.why_not(vector, runner.SHAPE)).is_empty()
	var paths: Array = [["ghosts"], ["moves"], ["trace"], ["trace", 0, "pacman"], ["trace", 0, "ghosts", 0]]
	for path: Array in paths:
		var why: String = VectorShape.why_not(VectorShape.planted(vector, path, "x"), runner.SHAPE)
		assert_str(why).override_failure_message(str(path)).is_not_empty()