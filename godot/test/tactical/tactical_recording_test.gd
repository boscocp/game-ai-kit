# T25, step 3: a game of the tactical board kept as its decisions, and played
# again from them. A recording is only worth keeping if the game it rebuilds
# is the game that was played -- so a whole game is recorded, written as the
# file is written, read back, and replayed to the same end.
extends GdUnitTestSuite


# These tests read the English words. The engine starts in the system's
# locale, so on a Portuguese system they would read the pt-BR ones (T79);
# the Portuguese screen is test/locale's. The locale found is put back.
var _locale_before: String


func before() -> void:
	_locale_before = TranslationServer.get_locale()
	TranslationServer.set_locale("en")


func after() -> void:
	TranslationServer.set_locale(_locale_before)


func test_a_recorded_game_replays_to_the_same_end_through_its_file() -> void:
	var played: Dictionary = _recorded_game(7)
	var read: Dictionary = JSON.parse_string(JSON.stringify(played["recording"]))
	var again: Dictionary = TacticalRecording.replay(read)

	assert_int(again["refused"]).is_equal(-1)
	assert_str(_digest(again["end"])).is_equal(_digest(played["end"]))
	assert_int(TacticalVictory.winner(again["end"])).is_equal(TacticalVictory.winner(played["end"]))


func test_the_person_s_rows_are_their_decisions_on_the_board_they_saw() -> void:
	var recording: Dictionary = _recorded_game(3)["recording"]
	var rows: Array[Dictionary] = TacticalRecording.rows_of(recording)
	var theirs: int = recording["decisions"].filter(func(row: Dictionary) -> bool: return row["side"] == TacticalScenario.BLUE).size()

	assert_int(rows.size()).is_equal(theirs)
	for row: Dictionary in rows:
		assert_int((row["board"] as BoardState).current_faction).is_equal(TacticalScenario.BLUE)
		assert_int((row["board"] as BoardState).turn_number).is_equal(row["decision"]["turn"])


func test_a_decision_the_rules_refuse_stops_the_replay_and_says_where() -> void:
	var recording: Dictionary = _recorded_game(3)["recording"]
	# Walk red's first walker into the rock at (2, 3), which nothing crosses.
	var first_walk: int = recording["decisions"].find_custom(func(row: Dictionary) -> bool: return row["kind"] == "move")
	recording["decisions"][first_walk]["path"] = [[2, 3]]

	assert_int(TacticalRecording.replay(recording)["refused"]).is_equal(first_walk)


func test_a_file_that_is_not_a_recording_says_why() -> void:
	assert_str(TacticalRecording.why_not_a_recording([])).is_equal("not a JSON object")
	assert_str(TacticalRecording.why_not_a_recording({"format": "x"})).starts_with("no ")
	var wrong: Dictionary = _recorded_game(3)["recording"]
	wrong["version"] = 99
	assert_str(TacticalRecording.why_not_a_recording(wrong)).contains("version 99")
	assert_str(TacticalRecording.why_not_a_recording(_recorded_game(3)["recording"])).is_empty()


func test_the_scene_records_only_when_asked_and_undo_drops_the_row() -> void:
	var scene: TacticalGame = _mounted_scene(true)
	var runner: Unit = _first_of(scene.state, TacticalScenario.RED, TacticalRules.RUNNER)
	scene.click_cell(runner.cell + Vector2i(-1, 0))
	assert_int(scene._recorded.size()).is_equal(1)
	assert_str(scene._recorded[0]["kind"]).is_equal("move")

	scene.undo()
	assert_int(scene._recorded.size()).is_equal(0)

	var quiet: TacticalGame = _mounted_scene(false)
	quiet.click_cell(_first_of(quiet.state, TacticalScenario.RED, TacticalRules.RUNNER).cell + Vector2i(-1, 0))
	assert_int(quiet._recorded.size()).is_equal(0)


func test_the_scene_keeps_a_game_once_it_is_over_and_only_once() -> void:
	var scene: TacticalGame = _mounted_scene(true)
	var folder: String = "user://recordings-under-test-%d" % Time.get_ticks_usec()
	scene.recordings_folder = ProjectSettings.globalize_path(folder)
	scene.click_cell(_first_of(scene.state, TacticalScenario.RED, TacticalRules.RUNNER).cell + Vector2i(-1, 0))
	scene._refresh()
	assert_int(scene.games_kept).is_equal(0)

	scene.winner = TacticalScenario.RED
	scene._refresh()
	scene._refresh()

	assert_int(scene.games_kept).is_equal(1)
	var files: PackedStringArray = DirAccess.get_files_at(folder)
	assert_int(files.size()).is_equal(1)
	var kept: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join(files[0])))
	assert_str(TacticalRecording.why_not_a_recording(kept)).is_empty()
	assert_str(kept["player"]).is_equal(TacticalRecording.PERSON)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(folder.path_join(files[0])))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))


func test_a_game_the_scene_kept_replays_to_its_winner() -> void:
	# Red never moves; blue's rules attack and win, and every attack moves the
	# board's seed on -- so the file must hold the seed the game began with.
	var scene: TacticalGame = _mounted_scene(true)
	var folder: String = "user://recordings-under-test-%d" % Time.get_ticks_usec()
	scene.recordings_folder = ProjectSettings.globalize_path(folder)
	scene.state.dice_seed = 11
	scene._starting_seed = 11
	while scene.winner == TacticalVictory.NOBODY:
		scene.end_turn()
		scene.end_turn()
		scene.play_rest_of_computer_turn()
	var files: PackedStringArray = DirAccess.get_files_at(folder)
	assert_int(files.size()).is_equal(1)
	var kept: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join(files[0])))
	var again: Dictionary = TacticalRecording.replay(kept)

	assert_int(int(kept["dice_seed"])).is_equal(11)
	assert_int(again["refused"]).is_equal(-1)
	assert_int(TacticalVictory.winner(again["end"])).is_equal(scene.winner)
	assert_bool(kept["decisions"].any(func(row: Dictionary) -> bool: return row["kind"] == "attack")).is_true()
	assert_bool(kept["decisions"].all(func(row: Dictionary) -> bool: return int(row["side"]) == TacticalScenario.BLUE)).is_true()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(folder.path_join(files[0])))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))


func test_a_wait_is_a_row_and_so_is_each_of_the_computer_s_decisions() -> void:
	var scene: TacticalGame = _mounted_scene(true)
	scene.wait()
	assert_str(scene._recorded.back()["kind"]).is_equal("hold")
	var person_rows: int = scene._recorded.size()
	scene.end_turn()
	scene.end_turn()
	scene.play_rest_of_computer_turn()

	assert_int(scene._recorded.size()).is_greater(person_rows)
	assert_int(int(scene._recorded.back()["side"])).is_equal(TacticalScenario.BLUE)


# A game of the rules against themselves on `dice_seed`, recorded decision by
# decision as the scene records it, with blue as "the person": {"recording",
# "end"}.
static func _recorded_game(dice_seed: int) -> Dictionary:
	var state: BoardState = TacticalScenario.build()
	state.dice_seed = dice_seed
	var turns: Array[BlueTurn] = [BlueTurn.new(RuleBasedBlue.new()), BlueTurn.new(RuleBasedBlue.new())]
	var rows: Array[Dictionary] = []
	var turns_allowed: int = TacticalVictory.ROUND_LIMIT * TacticalScenario.FACTIONS + 1
	while TacticalVictory.winner(state) == TacticalVictory.NOBODY and state.turn_number <= turns_allowed:
		var turn: BlueTurn = turns[state.current_faction]
		turn.begin(state)
		while not turn.finished() and TacticalVictory.winner(state) == TacticalVictory.NOBODY:
			state = _play_recorded(turn, state, rows)
		if TacticalVictory.winner(state) == TacticalVictory.NOBODY:
			state = TurnStart.open(state)[0]
	var recording: Dictionary = TacticalRecording.made(rows, dice_seed, TacticalRecording.PERSON, TacticalScenario.BLUE,
		"rules", TacticalVictory.winner(state), state.turn_number / TacticalScenario.FACTIONS + 1)
	return {"recording": recording, "end": state}


# `turn`'s next decision played on `state`, and written into `rows` when the
# board took it.
static func _play_recorded(turn: BlueTurn, state: BoardState, rows: Array[Dictionary]) -> BoardState:
	var deciding: TacticalDecision = turn.next
	var after: BoardState = turn.play(state)
	if deciding in turn.played:
		rows.append(TacticalRecording.row_of(deciding, state))
	return after


# Everything a replay must get right, as one line: whose turn, the funds, and
# every piece where it stands with the health it has.
static func _digest(state: BoardState) -> String:
	var pieces: Array[String] = []
	for unit: Unit in state.units:
		pieces.append("%d:%d:%s:%s:%d" % [unit.id, unit.faction, unit.type.type_name, unit.cell, unit.health])
	pieces.sort()
	return "%d %d %s %s" % [state.turn_number, state.current_faction, state.funds, " ".join(pieces)]


func _mounted_scene(recording: bool) -> TacticalGame:
	var scene: TacticalGame = auto_free((load("res://game/tactical/tactical.tscn") as PackedScene).instantiate())
	scene.recording = recording
	add_child(scene)
	return scene


static func _first_of(state: BoardState, side: int, type_name: String) -> Unit:
	for unit: Unit in state.units_of(side):
		if unit.type.type_name == type_name:
			return unit
	return null
