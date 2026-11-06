# T96: maps for the XCOM-style mode built by wave function collapse -- a map
# the rules can play, the two checks that refuse one they cannot, a
# contradiction restarted from the next seed and left on the board where it
# happened, and N and B in the scene.
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


func test_a_map_the_rules_cannot_play_is_refused_and_the_next_seed_built() -> void:
	SquadMapBuild._tile_set = OPEN_GROUND
	var build := SquadMapBuild.new(5)
	assert_array(build.rows).is_empty()
	assert_int(build.seed_used).is_equal(-1)
	assert_int(build.unplayable.size()).is_equal(SquadMapBuild.TRIES)
	assert_str(build.unplayable[0]).starts_with("no cover within one action")
	assert_int(build.last_seed()).is_equal(5 + SquadMapBuild.TRIES - 1)


func test_the_rules_play_the_next_game_on_the_map_used_and_the_tactical_one_after() -> void:
	var build := SquadMapBuild.new(2)
	SquadScenario.use_map(build.rows)
	assert_array(SquadScenario.rows()).is_equal(build.rows)
	var state: BoardState = SquadRuleset.new().start()
	assert_int(state.units.size()).is_equal(2 * SquadTable.squad().size())
	SquadScenario.use_map([] as Array[String])
	assert_array(SquadScenario.rows()).is_equal(TacticalScenario.MAP)


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


func _opened() -> TacticalGame:
	var scene: TacticalGame = auto_free((load("res://game/tactical/tactical.tscn") as PackedScene).instantiate())
	scene.play_in_modes([AdvanceWarsRuleset.new(), SquadRuleset.new()], 1)
	add_child(scene)
	return scene
