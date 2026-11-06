# T96: maps for the XCOM-style mode built by wave function collapse -- a map
# the rules can play, the two checks that refuse one they cannot (on the
# seeds measured to be refused, and on maps made by hand), a contradiction
# restarted from the next seed and left on the board where it happened, a
# map that belongs to the ruleset that built it, and N and B in the scene:
# the terrain drawn, a blocked cell explained, and clicks refused, all on
# the built map.
extends GdUnitTestSuite

## Three tiles, none beside itself, the open ground one of them: every map
## has cover and every cell can be walked, and seeds 1 to 3 run into a
## contradiction (measured with the Python twin, 2026-11-06).
const CONTRARY: Dictionary = {"tiles": [{"tile": ".", "weight": 1, "left_right": "Tf", "up_down": "Tf"},
		{"tile": "T", "weight": 1, "left_right": ".f", "up_down": ".f"},
		{"tile": "f", "weight": 1, "left_right": ".T", "up_down": ".T"}]}


## One tile, open ground beside itself: a map with no cover anywhere, which
## the rules refuse every time.
const OPEN_GROUND: Dictionary = {"tiles": [{"tile": ".", "weight": 1, "left_right": ".", "up_down": "."}]}


func after_test() -> void:
	SquadScenario.use_map([] as Array[String])
	SquadMapBuild._tile_set = {}


func test_a_map_is_the_tactical_maps_size_in_its_letters_with_every_start_open() -> void:
	var build := SquadMapBuild.new(1)
	assert_int(build.seed_used).is_equal(1)
	assert_int(build.rows.size()).is_equal(TacticalScenario.MAP.size())
	for row: String in build.rows:
		assert_int(row.length()).is_equal(TacticalScenario.MAP[0].length())
		for letter: String in row:
			assert_str(".T#~=f").contains(letter)
	for start: Array in SquadScenario.starts():
		assert_str(build.rows[start[0].y][start[0].x]).is_equal(TacticalRules.PLAIN)
	assert_str(SquadMapCheck.why_unplayable(build.rows)).is_empty()


func test_the_tactical_map_is_playable_and_a_walled_start_or_one_in_the_open_is_not() -> void:
	assert_str(SquadMapCheck.why_unplayable(TacticalScenario.MAP)).is_empty()
	var walled: Array[String] = TacticalScenario.MAP.duplicate()
	# Red's runner at (1, 2), rock on its four sides.
	walled[1] = ".#" + walled[1].substr(2)
	walled[2] = "#.#" + walled[2].substr(3)
	walled[3] = ".#" + walled[3].substr(2)
	assert_str(SquadMapCheck.why_unplayable(walled)).starts_with("no walk from")
	var open: Array[String] = []
	for row: String in TacticalScenario.MAP:
		open.append(".".repeat(row.length()))
	assert_str(SquadMapCheck.why_unplayable(open)).starts_with("no cover within one action")


# Wave 142's review: the three maps refused in the first twenty from seed 1,
# each kept one seed on -- two of them for a blue start, which a check of
# red's starts alone would let through.
func test_the_measured_refusals_are_refused_for_their_reasons() -> void:
	var refused: Array[Array] = [[3, "no cover within one action of (13, 3)"],
			[6, "no walk from (1, 2) to (0, 5)"], [21, "no cover within one action of (0, 5)"]]
	for case: Array in refused:
		var build := SquadMapBuild.new(case[0])
		assert_int(build.seed_used).is_equal(case[0] + 1)
		assert_array(build.unplayable).contains_exactly([case[1]])


func test_a_blue_start_walled_in_is_refused() -> void:
	var walled: Array[String] = TacticalScenario.MAP.duplicate()
	# Blue's shield at (12, 6), rock on its four sides.
	walled[5] = walled[5].substr(0, 12) + "#" + walled[5].substr(13)
	walled[6] = walled[6].substr(0, 11) + "#.#"
	walled[7] = walled[7].substr(0, 12) + "#" + walled[7].substr(13)
	assert_str(SquadMapCheck.why_unplayable(walled)).is_equal("no walk from (1, 2) to (12, 6)")


func test_cover_one_step_beyond_one_action_is_not_within_it() -> void:
	var runner_action: int = SquadTable.action(TacticalRules.RUNNER)
	var start := Vector2i(1, 2)
	for far: int in [0, 1]:
		# Trees on row 2 so that the first covered cell is `runner_action + far`
		# steps from the start, over open ground costing one a step.
		var rows: Array[String] = _open_rows()
		var trees: int = start.x + runner_action + far + 1
		rows[2] = rows[2].substr(0, trees) + "T" + rows[2].substr(trees + 1)
		var ground: GakGridGraph = TacticalRules.graphs_from(rows)[UnitType.GROUND]
		assert_bool(SquadMapCheck.has_cover_within(rows, ground, start, runner_action)).is_equal(far == 0)


func test_water_beside_a_cell_is_no_cover() -> void:
	var rows: Array[String] = _open_rows()
	for cell: Vector2i in [Vector2i(4, 3), Vector2i(6, 3), Vector2i(5, 2), Vector2i(5, 4)]:
		rows[cell.y] = rows[cell.y].substr(0, cell.x) + TacticalRules.WATER + rows[cell.y].substr(cell.x + 1)
	assert_bool(SquadMapCheck.is_covered(rows, Vector2i(5, 3))).is_false()
	rows[2] = rows[2].substr(0, 5) + TacticalRules.ROCK + rows[2].substr(6)
	assert_bool(SquadMapCheck.is_covered(rows, Vector2i(5, 3))).is_true()


func test_a_map_the_rules_cannot_play_is_refused_and_the_next_seed_built() -> void:
	SquadMapBuild._tile_set = OPEN_GROUND
	var build := SquadMapBuild.new(5)
	assert_array(build.rows).is_empty()
	assert_int(build.seed_used).is_equal(-1)
	assert_int(build.unplayable.size()).is_equal(SquadMapBuild.TRIES)
	assert_str(build.unplayable[0]).starts_with("no cover within one action")
	assert_int(build.last_seed()).is_equal(5 + SquadMapBuild.TRIES - 1)


# Wave 142's review: a map built by one ruleset outlived it, and the scene
# opened again from the menu played on it under "map: the tactical one".
func test_a_built_map_belongs_to_the_ruleset_that_built_it() -> void:
	var first := SquadRuleset.new()
	first.build_map(false)
	assert_array(SquadScenario.rows()).is_equal(first.map_build.rows)
	assert_int(first.start().units.size()).is_equal(2 * SquadTable.squad().size())
	var again := SquadRuleset.new()
	assert_array(SquadScenario.rows()).is_equal(TacticalScenario.MAP)
	assert_str(SquadMapWords.line(again)).starts_with("map: the tactical one")
	again.start()
	assert_array(SquadScenario.rows()).is_equal(TacticalScenario.MAP)
	first.start()
	assert_array(SquadScenario.rows()).is_equal(first.map_rows)
	# Decision 10: the first map a ruleset builds is the same map every time.
	again.build_map(false)
	assert_array(again.map_rows).is_equal(first.map_rows)


func test_a_contradiction_restarts_from_the_next_seed_and_is_shown_where_it_happened() -> void:
	SquadMapBuild._tile_set = CONTRARY
	var build := SquadMapBuild.new(1)
	assert_array(build.contradictions).contains_exactly(["8,8", "7,7", "3,5"])
	assert_int(build.seed_used).is_equal(4)
	build.watch()
	var steps: int = 0
	while build.stuck() == Vector2i(-1, -1) and steps < 200:
		build.step()
		steps += 1
	assert_object(build.stuck()).is_equal(Vector2i(8, 8))
	assert_str(build.counts()[Vector2i(8, 8)]).is_equal("0")
	build.step()
	assert_int(int(build.shown()["seed"])).is_equal(2)
	assert_object(build.stuck()).is_equal(Vector2i(-1, -1))


func test_watching_shows_the_cell_of_least_entropy_before_it_collapses_and_counts_dropping() -> void:
	var build := SquadMapBuild.new(1)
	build.watch()
	var next: Vector2i = build.choosing()
	assert_object(next).is_not_equal(Vector2i(-1, -1))
	var before: Dictionary[Vector2i, String] = build.counts()
	var weights: Dictionary = TileGrid.weights_of(SquadMapBuild.tile_set())
	for cell: Vector2i in before:
		assert_float(build.choosing_entropy()).is_less_equal(WaveCollapse.entropy_of(build.tiles_left(cell), weights))
	build.step()
	assert_bool(build.counts().has(next)).is_false()
	assert_int(build.counts().size()).is_equal(before.size() - 1)
	while not build.finished():
		build.step()
	assert_array(build.partial_rows()).is_equal(build.rows)


func test_n_plays_a_new_game_on_a_new_map_and_b_shows_one_built() -> void:
	var scene: TacticalGame = _opened()
	assert_str(scene._status.text).contains("map: the tactical one")
	scene._press(KEY_N)
	var squad: SquadRuleset = scene.ruleset as SquadRuleset
	assert_array(SquadScenario.rows()).is_equal(squad.map_build.rows)
	assert_str(scene._status.text).contains("map: seed %d" % squad.map_build.seed_used)
	assert_int(scene.state.units.size()).is_equal(2 * SquadTable.squad().size())
	scene._press(KEY_B)
	assert_bool(squad.watching_the_build).is_true()
	assert_bool(scene._intent._odds.is_empty()).is_false()
	assert_int(scene._intent._dashes.size()).is_equal(1)
	assert_str(scene._status.text).contains("entropy")
	var overlay: Dictionary = scene.decision_overlay()
	assert_bool(overlay["map build"].has("next cell")).is_true()
	scene._press(KEY_B)
	scene._press(KEY_N)
	assert_bool(squad.watching_the_build).is_false()
	assert_array(SquadScenario.rows()).is_equal(squad.map_build.rows)
	assert_bool(scene.decision_overlay().has("map build")).is_false()


# Wave 142's review: the scene draws the built map, explains a blocked cell
# from it, and takes no click while a build is shown.
func test_the_scene_draws_explains_and_holds_clicks_on_the_built_map() -> void:
	var scene: TacticalGame = _opened()
	scene._press(KEY_N)
	var built: Array[String] = (scene.ruleset as SquadRuleset).map_rows
	var drawn: Dictionary = scene._terrain()
	for y: int in range(built.size()):
		assert_bool(_drawn_like(drawn, built, y)).override_failure_message("row %d" % y).is_true()
	var rock: Vector2i = _first_rock_not_in_the_tactical_map(built)
	assert_str(scene._explained("unit 1 is blocked", rock)).contains("rock")
	scene._press(KEY_B)
	var before: BoardState = scene.state
	var target: Vector2i = _a_walk_for_the_piece_in_hand(scene)
	scene._unhandled_input(_click_on(scene, target))
	assert_object(scene.state).is_same(before)
	scene._press(KEY_N)
	var game_before: BoardState = scene.state
	scene._unhandled_input(_click_on(scene, _a_walk_for_the_piece_in_hand(scene)))
	assert_object(scene.state).is_not_same(game_before)


# True when every tree, water and bridge of row `y` of `rows` is drawn as one.
func _drawn_like(drawn: Dictionary, rows: Array[String], y: int) -> bool:
	var kinds: Dictionary = {TacticalRules.TREES: BoardView.TREES, TacticalRules.WATER: BoardView.WATER,
			TacticalRules.BRIDGE: BoardView.BRIDGE}
	for x: int in range(rows[y].length()):
		if kinds.has(rows[y][x]) and drawn.get(Vector2i(x, y)) != kinds[rows[y][x]]:
			return false
		if not kinds.has(rows[y][x]) and rows[y][x] != TacticalRules.FORD and drawn.has(Vector2i(x, y)):
			return false
	return true


func _first_rock_not_in_the_tactical_map(rows: Array[String]) -> Vector2i:
	for cell: Vector2i in TacticalRules.cells_of(rows, TacticalRules.ROCK):
		if TacticalScenario.MAP[cell.y][cell.x] != TacticalRules.ROCK:
			return cell
	return Vector2i(-1, -1)


# A cell the piece in hand could walk to on the game's board.
func _a_walk_for_the_piece_in_hand(scene: TacticalGame) -> Vector2i:
	var walks: Dictionary = TacticalReach.walks_for(scene.state, scene.state.unit_by_id(scene._selected_id))
	return walks.keys()[0]


func _click_on(scene: TacticalGame, cell: Vector2i) -> InputEventMouseButton:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.global_position = scene._board.to_global(scene._board.centre_of(cell))
	return click


func _open_rows() -> Array[String]:
	var rows: Array[String] = []
	for row: String in TacticalScenario.MAP:
		rows.append(TacticalRules.PLAIN.repeat(row.length()))
	return rows


func _opened() -> TacticalGame:
	var scene: TacticalGame = auto_free((load("res://game/tactical/tactical.tscn") as PackedScene).instantiate())
	scene.play_in_modes([AdvanceWarsRuleset.new(), SquadRuleset.new()], 1)
	add_child(scene)
	return scene
