# The bot match's event log (T100, ADR 0017): what condition 3 of ADR 0016's
# amendment replays, kept to a file only when asked. This suite writes and
# reads one back; `player_model_test.gd` replays the same events through a
# fresh model, and holds no file at all (N14).
extends GdUnitTestSuite

const FOLDER: String = MatchEventLog.TESTS


static func _played(seconds: float) -> BotMatch:
	var rules := MatchRules.new()
	var world := BotMatch.new(7, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)
	world.person = 0
	while world.time < seconds - 1e-6:
		world.step()
	return world


func test_a_log_read_back_is_the_events_in_order_with_the_seed() -> void:
	var world: BotMatch = _played(40.0)
	assert_int(world.person_events.size()).is_greater(0)
	var path: String = MatchEventLog.save(MatchEventLog.of(world, 7, BotArena.ARENA), FOLDER, "kept")
	assert_str(path).is_not_empty()
	var read: Dictionary = MatchEventLog.read(path)
	assert_int(read["seed"]).is_equal(7)
	assert_int(read["last_step"]).is_equal(world.steps_done - 1)
	assert_dict(read["difficulty"]).is_equal(world.rules.difficulty)
	assert_array(read["events"]).is_equal(world.person_events)


func test_the_events_are_only_the_persons_and_in_step_order() -> void:
	var world: BotMatch = _played(40.0)
	var last: int = -1
	var shots: int = 0
	for event: Dictionary in world.person_events:
		assert_int(int(event["step"])).is_greater_equal(last)
		last = int(event["step"])
		shots += 1 if event["kind"] == "shot" else 0
	# Every shot the person's team fired is a teammate's or theirs; theirs are
	# no more than the team's.
	assert_int(shots).is_between(1, world.stats[BotMatch.BLUE].shots)


func test_nobody_playing_keeps_no_events_and_writes_no_file() -> void:
	var rules := MatchRules.new()
	var world := BotMatch.new(7, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)
	for step: int in range(200):
		world.step()
	assert_int(world.person_events.size()).is_equal(0)
	assert_str(MatchEventLog.save(MatchEventLog.of(world, 7, BotArena.ARENA), FOLDER,
			"empty")).is_empty()


func test_a_run_not_opened_to_record_does_not_ask() -> void:
	assert_bool(MatchEventLog.asked()).is_false()
