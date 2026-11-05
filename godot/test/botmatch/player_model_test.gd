# The bot match reading the person (T100, T123): ADR 0016's three
# conditions on `PlayerModel`, and what `MatchDifficulty` is allowed to
# change.
#
#   1. it counts: every field the model keeps is a whole number -- counts,
#      and the team they are of;
#   2. it starts empty with every match, in the table's middle row (that N
#      in the scene seats a new one is `botmatch_restart_test.gd`'s), and
#      again on a seat on the other team;
#   3. it can be rebuilt from the person's events: the events a match
#      noted, replayed twice through a fresh model, give the same counts
#      and the same rows, and those are the rows the match read live --
#      from memory, and from the log `MatchEventLog` wrote and read back.
#
# N14 holds this suite, which names the model, to reading and writing no
# file itself. The log is written and read by `MatchEventLog`, the one
# writer N14 does not hold, and the vectors are read by `ModelVectorFiles`;
# this suite is handed what they read. The scene is loaded by a suite that
# names neither class.
extends GdUnitTestSuite

const STANDING_IN: int = 0
const SECONDS: float = 90.0


func before() -> void:
	TranslationServer.set_locale("en")


# A match with bot 0 played by a stand-in aiming `own_degrees` off, the
# model on, after `seconds`.
static func _played(seed_value: int, own_degrees: float, seconds: float = SECONDS) -> BotMatch:
	var rules := MatchRules.new()
	var world := BotMatch.new(seed_value, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)
	world.bots[STANDING_IN].own_aim_error = deg_to_rad(own_degrees)
	world.difficulty = MatchDifficulty.new(world)
	world.seat_person(STANDING_IN)
	_play_on(world, seconds)
	return world


static func _play_on(world: BotMatch, seconds: float) -> void:
	while world.time < seconds - 1e-6 and not world.over():
		world.step()


# Every live reading of `world` equals its replay from the events it noted.
static func _rebuilt_as_read(world: BotMatch) -> bool:
	var difficulty: MatchDifficulty = world.difficulty
	var replayed: Array[Dictionary] = PlayerModel.replay(difficulty.table, world.person_events, world.steps_done - 1,
			difficulty.interval_steps)
	if replayed.size() != difficulty.readings.size():
		return false
	for index: int in range(replayed.size()):
		var live: Dictionary = difficulty.readings[index].duplicate()
		live.erase("changed")
		if replayed[index] != live:
			return false
	return true


func test_every_field_the_model_keeps_is_a_count() -> void:
	var fields: Array[String] = []
	for property: Dictionary in PlayerModel.new().get_property_list():
		if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			fields.append(property["name"])
			assert_int(property["type"]).override_failure_message("%s is not an int" % property["name"]).is_equal(TYPE_INT)
	assert_array(fields).contains_exactly(["shots", "hits", "kills", "deaths", "dealt", "taken", "team_dealt",
			"team_taken", "team", "restarts"])


func test_an_empty_model_reads_the_middle_row_the_knobs_own_aim() -> void:
	var rules := MatchRules.new()
	var world := BotMatch.new(1, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)
	var difficulty := MatchDifficulty.new(world)
	assert_dict(difficulty.model.counts()).is_equal(_empty_counts(0))
	assert_float(float(rules.difficulty["rows"][difficulty.row]["aim_error_degrees"])).is_equal(rules.aim_error_degrees)


func test_the_match_rebuilds_from_its_events_twice_alike_and_as_it_read_them_live() -> void:
	var world: BotMatch = _played(3, 1.0)
	var difficulty: MatchDifficulty = world.difficulty
	assert_int(world.person_events.size()).is_greater(10)
	var first: Array[Dictionary] = PlayerModel.replay(difficulty.table, world.person_events, world.steps_done - 1,
			difficulty.interval_steps)
	var second: Array[Dictionary] = PlayerModel.replay(difficulty.table, world.person_events, world.steps_done - 1,
			difficulty.interval_steps)
	assert_array(first).is_equal(second)
	assert_int(first.size()).is_equal(difficulty.readings.size())
	for index: int in range(first.size()):
		var live: Dictionary = difficulty.readings[index].duplicate()
		live.erase("changed")
		assert_dict(first[index]).is_equal(live)


static func _empty_counts(restarts: int) -> Dictionary:
	return {"shots": 0, "hits": 0, "kills": 0, "deaths": 0, "dealt": 0, "taken": 0, "team_dealt": 0,
			"team_taken": 0, "restarts": restarts}


func test_the_share_is_the_teams_the_persons_bot_and_its_mates() -> void:
	var world: BotMatch = _played(3, 1.0, 60.0)
	var model: PlayerModel = world.difficulty.model
	var mates: int = 0
	for event: Dictionary in world.person_events:
		mates += 1 if str(event["kind"]).begins_with("mate_") else 0
	assert_int(mates).is_greater(0)
	assert_int(model.team_dealt).is_greater(model.dealt)
	assert_int(model.team_taken).is_greater(model.taken)


func test_the_knob_is_the_other_teams_aim_and_a_row_of_the_table() -> void:
	var world: BotMatch = _played(2, 1.0)
	var rows: Array = world.rules.difficulty["rows"]
	var row: Dictionary = rows[world.difficulty.row]
	assert_float(world.teams[BotMatch.RED].aim_error).is_equal_approx(deg_to_rad(float(row["aim_error_degrees"])), 1e-9)
	assert_float(world.teams[BotMatch.BLUE].aim_error).is_equal_approx(deg_to_rad(world.rules.aim_error_degrees), 1e-9)
	for read: int in world.difficulty.rows_read():
		assert_int(read).is_between(0, rows.size() - 1)


func test_a_sharp_stand_in_is_read_harder_than_a_poor_one() -> void:
	var sharp: BotMatch = _played(4, 0.5, 120.0)
	var poor: BotMatch = _played(4, 12.0, 120.0)
	assert_int(sharp.difficulty.row).is_greater(poor.difficulty.row)


func test_a_match_nobody_plays_changes_nobodys_aim() -> void:
	var rules := MatchRules.new()
	var world := BotMatch.new(5, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)
	world.difficulty = MatchDifficulty.new(world)
	for step: int in range(roundi(30.0 / rules.step)):
		world.step()
	assert_int(world.difficulty.readings.size()).is_greater(0)
	assert_int(world.person_events.size()).is_equal(0)
	for team: MatchTeam in world.teams:
		assert_float(team.aim_error).is_equal_approx(deg_to_rad(world.rules.aim_error_degrees), 1e-9)


func test_the_panel_shows_the_counts_the_share_and_the_row() -> void:
	var world: BotMatch = _played(3, 1.0, 30.0)
	var lines: Array[String] = BotMatchLines.difficulty_lines(world)
	assert_int(lines.size()).is_equal(3)
	assert_str(lines[0]).contains("%d shots" % world.difficulty.model.shots)
	assert_str(lines[1]).contains("+ %d)" % int(world.rules.difficulty["prior_points"]))
	assert_str(lines[2]).contains("row %d of" % (world.difficulty.row + 1))


func test_a_model_with_another_prior_fails_the_vectors() -> void:
	var vectors: Dictionary = ModelVectorFiles.read_all(ModelVectorFiles.directory())
	assert_int(vectors.size()).is_greater_equal(11)
	var rules := MatchRules.new()
	var planted := MatchRules.new()
	planted.difficulty = rules.difficulty.duplicate(true)
	planted.difficulty["prior_points"] = 1
	var failures: int = 0
	for name: String in vectors:
		assert_array(ModelConformance.check_vector(name, vectors[name], rules)).is_empty()
		failures += ModelConformance.check_vector(name, vectors[name], planted).size()
	assert_int(failures).is_greater(0)


func test_a_model_with_no_band_fails_the_vectors() -> void:
	var vectors: Dictionary = ModelVectorFiles.read_all(ModelVectorFiles.directory())
	var planted := MatchRules.new()
	planted.difficulty["band"] = {"from": 0.5, "to": 0.5}
	var failures: int = 0
	for name: String in vectors:
		failures += ModelConformance.check_vector(name, vectors[name], planted).size()
	assert_int(failures).is_greater(0)


func test_the_log_read_back_from_disk_rebuilds_the_readings_by_itself() -> void:
	var world: BotMatch = _played(6, 1.0)
	var path: String = MatchEventLog.save(MatchEventLog.of(world, 6, BotArena.ARENA), MatchEventLog.TESTS, "replayed")
	assert_str(path).is_not_empty()
	var kept: Dictionary = MatchEventLog.read(path)
	var interval_steps: int = roundi(float(kept["difficulty"]["interval"]) / float(kept["step"]))
	var rebuilt: Array[Dictionary] = PlayerModel.replay(kept["difficulty"], kept["events"], kept["last_step"],
			interval_steps)
	assert_int(rebuilt.size()).is_equal(world.difficulty.readings.size())
	for index: int in range(rebuilt.size()):
		var live: Dictionary = world.difficulty.readings[index]
		assert_int(int(rebuilt[index]["row"])).is_equal(int(live["row"]))
		assert_dict(rebuilt[index]["counts"]).is_equal(live["counts"])


# Half a second past a reading, so the step taken after the change is not
# one: a reading would re-apply the knob and hide a seat that did nothing.
func test_giving_the_bot_back_restores_both_aims_at_once() -> void:
	var world: BotMatch = _played(4, 0.5, 30.5)
	assert_float(world.teams[BotMatch.RED].aim_error).is_not_equal(deg_to_rad(world.rules.aim_error_degrees))
	world.seat_person(-1)
	world.step()
	for team: MatchTeam in world.teams:
		assert_float(team.aim_error).is_equal_approx(deg_to_rad(world.rules.aim_error_degrees), 1e-9)


# A change of side (T123): the counts start empty and the row goes back to
# the middle at once, so neither team keeps the aim the other side earned.
func test_changing_sides_empties_the_counts_and_puts_the_knob_back_at_once() -> void:
	var world: BotMatch = _played(4, 0.5, 30.5)
	assert_int(world.difficulty.row).is_not_equal(PlayerModel.start_row(world.rules.difficulty))
	world.seat_person(BotMatch.BOTS_A_SIDE)
	world.step()
	assert_dict(world.difficulty.model.counts()).is_equal(_empty_counts(1))
	assert_dict(world.difficulty.overlay()["counts"]).is_equal(_empty_counts(1))
	assert_int(world.difficulty.row).is_equal(PlayerModel.start_row(world.rules.difficulty))
	for team: MatchTeam in world.teams:
		assert_float(team.aim_error).is_equal_approx(deg_to_rad(world.rules.aim_error_degrees), 1e-9)


# The seat counts the events since the last reading too, so the counts
# after it are the ones before it or more, never fewer.
func test_a_seat_on_the_same_team_keeps_the_counts_and_the_knob() -> void:
	var world: BotMatch = _played(4, 0.5, 30.5)
	var dealt: int = world.difficulty.model.team_dealt
	var row: int = world.difficulty.row
	world.seat_person(STANDING_IN + 1)
	world.step()
	assert_int(world.difficulty.model.restarts).is_equal(0)
	assert_int(world.difficulty.model.team_dealt).is_greater_equal(dealt)
	assert_int(dealt).is_greater(0)
	assert_int(world.difficulty.row).is_equal(row)


func test_a_match_with_a_change_of_side_rebuilds_from_its_events_as_read_live() -> void:
	var world: BotMatch = _played(4, 0.5, 30.5)
	world.seat_person(-1)
	_play_on(world, 41.0)
	world.seat_person(BotMatch.BOTS_A_SIDE)
	world.bots[BotMatch.BOTS_A_SIDE].own_aim_error = deg_to_rad(0.5)
	_play_on(world, 90.0)
	assert_int(world.difficulty.model.restarts).is_equal(1)
	assert_bool(_rebuilt_as_read(world)).is_true()


# A seat taken exactly on a reading's step (the review of wave 132): it is
# stamped with the last step taken, so the reading at the next interval
# counts it live and replayed alike. Stamped with `steps_done`, live and
# replay part.
func test_a_seat_on_a_reading_step_rebuilds_as_read_live() -> void:
	var world: BotMatch = _played(4, 0.5, 30.0)
	assert_int(world.steps_done % world.difficulty.interval_steps).is_equal(0)
	world.seat_person(BotMatch.BOTS_A_SIDE)
	_play_on(world, 60.0)
	assert_int(world.difficulty.model.restarts).is_equal(1)
	assert_bool(_rebuilt_as_read(world)).is_true()


# Only the person's own team-mates' damage is noted as a mate's: an
# opponent's hit or hurt is not the team's share (the review of wave 132).
func test_mate_events_come_only_from_the_persons_team() -> void:
	var rules := MatchRules.new()
	var world := BotMatch.new(1, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)
	world.seat_person(0)
	var before: int = world.person_events.size()
	world.note(BotMatch.BOTS_A_SIDE, "hit", 10)
	world.note(BotMatch.BOTS_A_SIDE, "hurt", 10)
	assert_int(world.person_events.size()).is_equal(before)
	world.note(1, "hit", 10)
	world.note(1, "shot")
	assert_int(world.person_events.size()).is_equal(before + 1)
	assert_str(str(world.person_events[-1]["kind"])).is_equal(PlayerModel.MATE_HIT)
