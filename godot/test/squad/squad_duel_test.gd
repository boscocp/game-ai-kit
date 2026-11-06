# What `make test-squad-duel` holds (T88), each with a planted row it must
# refuse: `SquadDuel.wrong_position`, `wrong_match` and `missing_rows`,
# which the runner applies to every row it makes -- and the measurement's
# note, `searched_less`, which says and never fails. And the positions
# file: the opening, a flank, a long shot and a retreat to cover, as the
# task asks.
extends GdUnitTestSuite

# Where the planted searcher that believes no enemy is left lives.
const EXPECTI_TESTS: GDScript = preload("res://test/squad/expecti_squad_test.gd")


func test_a_row_that_holds_is_not_refused() -> void:
	var position: Dictionary = _first("flank")
	var rows: Array[Dictionary] = [_row(position, 1, 40), _row(position, 2, 200), _row(position, 2, 900)]
	assert_array(SquadDuel.wrong_position(position, rows)).is_empty()


func test_an_answer_that_is_not_the_positions_is_refused() -> void:
	var position: Dictionary = _first("flank")
	var planted: Dictionary = _row(position, 1, 40)
	planted["expecti"] = "1 shoots 99"
	assert_array(SquadDuel.wrong_position(position, [planted])).is_not_empty()


func test_a_budget_that_finished_nothing_is_refused() -> void:
	var position: Dictionary = _first("long shot")
	assert_array(SquadDuel.wrong_position(position, [_row(position, 0, 40)])).is_not_empty()
	assert_array(SquadDuel.wrong_position(position, [_row(position, 1, 0)])).is_not_empty()


func test_a_longer_window_that_searched_less_is_noted_and_not_refused() -> void:
	var position: Dictionary = _first("retreat to cover")
	var starved: Array[Dictionary] = [_row(position, 2, 40), _row(position, 1, 200)]
	assert_array(SquadDuel.wrong_position(position, starved)).is_empty()
	assert_array(SquadDuel.searched_less(position, starved)).is_not_empty()
	assert_array(SquadDuel.searched_less(position, [_row(position, 1, 200), _row(position, 1, 40)])).is_not_empty()
	assert_array(SquadDuel.searched_less(position, [_row(position, 1, 40), _row(position, 2, 200)])).is_empty()


func test_a_run_short_of_rows_or_matches_is_refused() -> void:
	assert_array(SquadDuel.missing_rows("matches", 6, 6)).is_empty()
	assert_array(SquadDuel.missing_rows("matches", 6, 0)).is_not_empty()
	assert_array(SquadDuel.missing_rows("position rows", 30, 29)).is_not_empty()


func test_a_match_with_no_end_or_a_lost_decision_is_refused() -> void:
	var ended: Dictionary = {"game": 1, "winner": TacticalScenario.RED, "lost": [0, 0]}
	assert_array(SquadDuel.wrong_match(ended)).is_empty()
	assert_array(SquadDuel.wrong_match(ended.merged({"winner": TacticalVictory.NOBODY}, true))).is_not_empty()
	assert_array(SquadDuel.wrong_match(ended.merged({"lost": [0, 1]}, true))).is_not_empty()
	assert_array(SquadDuel.wrong_match(ended.merged({"held": 1}, true))).is_not_empty()


func test_a_match_where_a_searcher_believes_the_game_over_is_refused() -> void:
	var believes_no_enemy: GDScript = EXPECTI_TESTS.BelievesNoEnemy
	var planted: Dictionary = SquadDuel.match_row(believes_no_enemy.new(1, 20), WeighedSquad.new(), 1)
	assert_int(planted["held"]).is_greater(0)
	assert_str(" ".join(SquadDuel.wrong_match(planted))).contains("held on a game believed over")
	var sound: Dictionary = SquadDuel.match_row(MctsSquad.new(1, SquadDuel.MATCH_ITERATIONS), WeighedSquad.new(), 1)
	assert_int(sound["held"]).is_equal(0)


func test_the_positions_are_thirty_with_each_kind_the_task_names() -> void:
	var positions: Array = _duel()["positions"]
	assert_int(positions.size()).is_equal(30)
	for about: String in ["the opening", "flank", "long shot", "retreat to cover"]:
		assert_bool(positions.any(func(position: Dictionary) -> bool: return position["about"] == about)).is_true()
	assert_array(SquadScenario.rows()).is_equal(_duel()["map"])


func test_the_tags_say_what_a_position_holds() -> void:
	for about: String in ["flank", "long shot", "retreat to cover"]:
		var position: Dictionary = _first(about)
		var phase: int = SquadSearchGame.WALK if position["phase"] == "walk" else SquadSearchGame.SHOOT
		assert_array(SquadDuel.tags(SquadDuel.board_of(position), int(position["acting"]), phase)).contains([about])
	var opening: Dictionary = _first("the opening")
	assert_array(SquadDuel.tags(SquadDuel.board_of(opening), int(opening["acting"]), SquadSearchGame.WALK)).is_empty()


func test_searched_for_a_moment_both_answer_from_the_positions_answers() -> void:
	var position: Dictionary = _first("flank")
	var row: Dictionary = SquadDuel.searched(position, 20, 1)
	assert_array(SquadDuel.wrong_position(position, [row])).is_empty()


func test_the_gates_fixed_budget_answers_the_same_twice() -> void:
	var position: Dictionary = _first("retreat to cover")
	var once: Dictionary = SquadDuel.searched_fixed(position, 7)
	assert_array(SquadDuel.wrong_position(position, [once])).is_empty()
	assert_dict(SquadDuel.searched_fixed(position, 7)).is_equal(once)
	assert_int(once["iterations"]).is_equal(SquadDuel.FIXED_ITERATIONS)


# A row of the duel for `position`: both searches answering its first
# answer, with this depth and these iterations.
func _row(position: Dictionary, depth: int, iterations: int) -> Dictionary:
	var answer: String = position["expected"]["values"][0][0]
	return {"mcts": answer, "iterations": iterations, "expecti": answer, "depth": depth, "positions": 1}


func _first(about: String) -> Dictionary:
	return _duel()["positions"].filter(func(position: Dictionary) -> bool: return position["about"] == about)[0]


func _duel() -> Dictionary:
	var path: String = ProjectSettings.globalize_path("res://").path_join("../spec/squad/duel.json")
	return JSON.parse_string(FileAccess.get_file_as_string(path))
