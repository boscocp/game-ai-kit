# T87: `SquadSearchGame`, the squad's side of `GakAdversarialGame`.
#
# The positions in spec/squad/positions.json, as `make
# test-squad-search-vectors` runs them, held here too, with a wrong count
# and a drifted map refused. Then the game itself, which the vectors would
# pass wrong in both languages alike: its walks are the board's walks, a
# shot is a hit and a miss at the chance the person is shown, a question
# with one answer is passed over, the turn passes after the last piece, and
# the score stays in [-1, 1] and is the result once the game is over.
extends GdUnitTestSuite

const RUNNER: GDScript = preload("res://test/squad/squad_search_vectors_runner.gd")
const POSITIONS: int = 40

var _game := SquadSearchGame.new()
var _rules := SquadRuleset.new()


func test_every_position_is_the_files() -> void:
	var written: Dictionary = _written()
	assert_array(RUNNER.map_drifted(written["map"])).is_empty()
	assert_int(written["positions"].size()).is_equal(3)
	for position: Dictionary in written["positions"]:
		assert_array(RUNNER.check_position(position)).is_empty()


func test_a_wrong_count_and_a_drifted_map_are_refused() -> void:
	var written: Dictionary = _written()
	var position: Dictionary = written["positions"][1]
	position["visits"][0][1] = int(position["visits"][0][1]) + 1
	assert_array(RUNNER.check_position(position)).is_not_empty()
	var rows: Array = written["map"].duplicate()
	rows[0] = rows[0].replace("T", ".")
	assert_array(RUNNER.map_drifted(rows)).is_not_empty()


func test_its_walks_are_the_boards_walks_at_the_same_cost() -> void:
	var check := SquadUnseenCheck.new(POSITIONS)
	for index: int in range(check.size()):
		var board: BoardState = check.position(index)
		for unit: Unit in board.units_of(board.current_faction):
			_assert_walks_are_the_boards(board, unit)


func test_a_shot_hits_and_misses_at_the_chance_the_person_is_shown() -> void:
	var root: SquadSearchGame.Position = RUNNER.root(_written()["positions"][1])
	var shot: Array = ["shoot", 3, 8]
	var possible: Array = _game.outcomes(root, shot)
	var chance: int = SquadCombat.chance_of(SquadScenario.rows(), root.board.unit_by_id(3), root.board.unit_by_id(8))
	assert_int(possible.size()).is_equal(2)
	assert_float(possible[0]["probability"]).is_equal(chance / 100.0)
	assert_float(possible[0]["probability"] + possible[1]["probability"]).is_equal_approx(1.0, 0.000001)
	var hit: BoardState = (possible[0]["state"] as SquadSearchGame.Position).board
	var missed: BoardState = (possible[1]["state"] as SquadSearchGame.Position).board
	assert_object(hit.unit_by_id(8)).is_null()  # 4 health, and the mortar deals 5
	assert_int(missed.unit_by_id(8).health).is_equal(4)
	assert_int(missed.unit_by_id(3).movement_points).is_equal(0)


func test_after_the_last_piece_the_turn_passes_with_movement_refilled() -> void:
	var root: SquadSearchGame.Position = RUNNER.root(_written()["positions"][1])
	# The mortar holds its fire; red's wader, the last to act, holds where it
	# is and holds its fire at blue's wader, which it sees: blue is to move.
	var after_mortar: SquadSearchGame.Position = _game.result(root, ["hold", 3])
	assert_int(after_mortar.unit_id).is_equal(4)
	var after_walk: SquadSearchGame.Position = _game.result(after_mortar, ["hold", 4])
	assert_int(after_walk.unit_id).is_equal(4)
	assert_int(after_walk.phase).is_equal(SquadSearchGame.SHOOT)
	var after_wader: SquadSearchGame.Position = _game.result(after_walk, ["hold", 4])
	assert_int(_game.to_move(after_wader)).is_equal(TacticalScenario.BLUE)
	assert_int(after_wader.board.turn_number).is_equal(root.board.turn_number + 1)
	assert_int(after_wader.phase).is_equal(SquadSearchGame.WALK)
	for unit: Unit in after_wader.board.units_of(TacticalScenario.BLUE):
		assert_int(unit.movement_points).is_equal(unit.type.movement)


func test_a_question_with_one_answer_is_passed_over() -> void:
	var root: SquadSearchGame.Position = RUNNER.root(_written()["positions"][0])
	# A walk of the runner that dashes leaves it no shot: the next question
	# is the shield's walk, not the runner's shot.
	var far: Array = (root.answers() as Array).filter(func(walk: Array) -> bool:
		return walk[0] == "walk" and walk[3] > SquadTable.action("runner"))[0]
	var after: SquadSearchGame.Position = _game.result(root, far)
	assert_int(after.unit_id).is_equal(2)
	assert_int(after.phase).is_equal(SquadSearchGame.WALK)
	for answer: Array in after.answers():
		assert_int(answer[1]).is_equal(2)


func test_the_score_is_within_one_and_the_result_once_over() -> void:
	var check := SquadUnseenCheck.new(POSITIONS)
	for index: int in range(check.size()):
		var board: BoardState = check.position(index)
		var position := SquadSearchGame.Position.new(board, board.units_of(board.current_faction)[0].id, SquadSearchGame.WALK, [] as Array[int])
		for side: int in [TacticalScenario.RED, TacticalScenario.BLUE]:
			assert_float(absf(_game.evaluate(position, side))).is_less_equal(1.0)
	var root: SquadSearchGame.Position = RUNNER.root(_written()["positions"][1])
	var gone: BoardState = root.board.duplicate_state()
	for unit: Unit in gone.units_of(TacticalScenario.BLUE):
		unit.health = 0
	var over := SquadSearchGame.Position.new(gone.duplicate_state(), -1, SquadSearchGame.WALK, [] as Array[int])
	assert_bool(_game.is_terminal(over)).is_true()
	assert_array(_game.actions(over)).is_empty()
	assert_float(_game.evaluate(over, TacticalScenario.RED)).is_equal(1.0)
	assert_float(_game.evaluate(over, TacticalScenario.BLUE)).is_equal(-1.0)


# Every walk the search lists for `unit` is one `TacticalReach` offers, at
# what its route costs, and none is missing.
func _assert_walks_are_the_boards(board: BoardState, unit: Unit) -> void:
	var routes: Dictionary = TacticalReach.walks_for(board, unit)
	var walks: Array = SquadSearchGame.walks(board, unit)
	assert_int(walks.size()).is_equal(routes.size())
	for walk: Array in walks:
		assert_int(walk[3]).is_equal(Move.new(unit.id, routes[walk[2]]).cost_on(board.graph_for(unit)))


func _written() -> Dictionary:
	var path: String = ProjectSettings.globalize_path("res://").path_join("../spec/squad/positions.json")
	return JSON.parse_string(FileAccess.get_file_as_string(path))


# T121: the squad search vectors runner refuses a file of the wrong types
# before it reads one. A map, pieces or visits given as text, in a copy of
# the real file, were a SCRIPT ERROR that skipped the check and exited 0.
func test_a_positions_file_of_the_wrong_types_is_refused() -> void:
	var runner: GDScript = preload("res://test/squad/squad_search_vectors_runner.gd")
	var written: Dictionary = VectorShape.read_spec("squad/positions.json")
	assert_str(VectorShape.why_not(written, runner.SHAPE)).is_empty()
	var paths: Array = [["map"], ["positions"], ["positions", 0, "pieces"], ["positions", 0, "visits"],
			["positions", 0, "waiting"]]
	for path: Array in paths:
		var why: String = VectorShape.why_not(VectorShape.planted(written, path, "x"), runner.SHAPE)
		assert_str(why).override_failure_message(str(path)).is_not_empty()