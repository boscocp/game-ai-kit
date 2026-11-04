# The bot match reading the person (T100): ADR 0016's three conditions on
# `PlayerModel`, and what `MatchDifficulty` is allowed to change.
#
#   1. it counts: every field the model keeps is a whole-number count;
#   2. it starts empty with every match, in the table's middle row (that N
#      in the scene seats a new one is `botmatch_restart_test.gd`'s);
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
	world.person = STANDING_IN
	world.bots[STANDING_IN].own_aim_error = deg_to_rad(own_degrees)
	world.difficulty = MatchDifficulty.new(world)
	while world.time < seconds - 1e-6 and not world.over():
		world.step()
	return world


func test_every_field_the_model_keeps_is_a_count() -> void:
	var fields: Array[String] = []
	for property: Dictionary in PlayerModel.new().get_property_list():
		if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			fields.append(property["name"])
			assert_int(property["type"]).override_failure_message("%s is not an int" % property["name"]).is_equal(TYPE_INT)
	assert_array(fields).contains_exactly(["shots", "hits", "kills", "deaths", "dealt", "taken"])


func test_an_empty_model_reads_the_middle_row_the_knobs_own_aim() -> void:
	var rules := MatchRules.new()
	var world := BotMatch.new(1, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)
	var difficulty := MatchDifficulty.new(world)
	assert_dict(difficulty.model.counts()).is_equal({"shots": 0, "hits": 0, "kills": 0, "deaths": 0, "dealt": 0,
			"taken": 0})
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
	assert_int(vectors.size()).is_greater_equal(7)
	var rules := MatchRules.new()
	var planted := MatchRules.new()
	planted.difficulty = rules.difficulty.duplicate(true)
	planted.difficulty["prior_points"] = 1
	var failures: int = 0
	for name: String in vectors:
		assert_array(ModelConformance.check_vector(name, vectors[name], rules)).is_empty()
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


func test_changing_sides_moves_the_aim_to_the_new_other_team_at_once() -> void:
	var world: BotMatch = _played(4, 0.5, 30.5)
	var row: Dictionary = world.rules.difficulty["rows"][world.difficulty.row]
	world.seat_person(BotMatch.BOTS_A_SIDE)
	world.step()
	assert_float(world.teams[BotMatch.RED].aim_error).is_equal_approx(deg_to_rad(world.rules.aim_error_degrees), 1e-9)
	assert_float(world.teams[BotMatch.BLUE].aim_error).is_equal_approx(deg_to_rad(float(row["aim_error_degrees"])), 1e-9)
