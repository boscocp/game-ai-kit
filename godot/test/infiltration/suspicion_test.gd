# T115: a guard's intruder network. Its tables are the vector's; a noise
# alone stays under the threshold and a door found open goes over it; a
# sign is let go when it is old or looked into; and, played on the
# warehouse, a door left open sends a guard to check it, the guard shuts
# it, and the belief falls again with the door named as the change.
extends GdUnitTestSuite

const VECTOR: String = "../spec/vectors/bayes/the-guards-intruder.json"


func _world() -> InfiltrationWorld:
	return InfiltrationWorld.make(InfiltrationLevel.read(InfiltrationLevel.WAREHOUSE), InfiltrationRules.read(), 1)


func test_the_games_tables_are_the_vectors() -> void:
	var path: String = ProjectSettings.globalize_path("res://").path_join(VECTOR)
	var vector: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var game: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GuardSuspicion.FILE))
	assert_str(GuardSuspicion.new().network.problem()).is_empty()
	assert_bool(game["variables"] == vector["network"]["variables"]).override_failure_message(
		"intruder_network.json's tables differ from the-guards-intruder.json's").is_true()


func test_a_noise_alone_stays_under_the_threshold_and_a_door_goes_over() -> void:
	var threshold: float = SuspicionView.threshold(InfiltrationRules.actions())
	assert_float(threshold).is_equal(0.3)
	var heard := GuardSuspicion.new()
	heard.notice_kind("footstep", Vector2(5, 5), 1.0)
	heard.reconsider(1.0)
	assert_float(heard.belief).is_greater(GuardSuspicion.new().belief)
	assert_float(heard.belief).is_less(threshold)
	# The lead is the sign seen that raised the belief, not the largest change:
	# here "partner not quiet" lowers it more than the noise raises it.
	assert_str(heard.lead).is_equal("noise")
	assert_str(heard.strongest).is_equal("partner_quiet")
	assert_float(float(heard.moved["partner_quiet"])).is_less(0.0)
	var found := GuardSuspicion.new()
	found.notice_kind("open_door", Vector2(5, 5), 1.0)
	found.reconsider(1.0)
	assert_float(found.belief).is_greater_equal(threshold)
	assert_str(found.strongest).is_equal("open_door")
	assert_str(found.lead).is_equal("open_door")
	assert_str(str(found.last_change["by"])).is_equal("open_door")
	assert_vector(found.lead_place()).is_equal(Vector2(5, 5))


func test_an_event_no_sign_names_is_not_evidence() -> void:
	var suspicion := GuardSuspicion.new()
	var before: float = suspicion.belief
	suspicion.notice_kind("check_in", Vector2(5, 5), 1.0)
	suspicion.reconsider(1.0)
	assert_float(suspicion.belief).is_equal(before)
	assert_dict(suspicion.last_change).is_empty()


func test_a_sign_too_old_is_seen_as_no() -> void:
	var suspicion := GuardSuspicion.new()
	suspicion.notice_kind("open_door", Vector2(5, 5), 0.0)
	var kept: float = float(suspicion.spec["evidence"]["open_door"]["remember_for"])
	assert_str(str(suspicion.seen(kept)["open_door"])).is_equal(GuardSuspicion.SEEN)
	assert_str(str(suspicion.seen(kept + 0.1)["open_door"])).is_equal(GuardSuspicion.NOT_SEEN)


# The first guard to check the evidence, stepping `world` until it does, at
# most `steps` steps; -1 when none does. Its reason is asserted then.
func _first_checker(world: InfiltrationWorld, steps: int) -> int:
	for step: int in range(steps):
		world.step(PlayerIntent.new())
		var checking: Array = world.guards.filter(func(guard: InfiltrationGuard) -> bool: return guard.action == "check the evidence")
		if not checking.is_empty():
			assert_str((checking[0] as InfiltrationGuard).suspicion.lead).is_equal("open_door")
			return (checking[0] as InfiltrationGuard).id
	return -1


func test_a_door_left_open_is_checked_shut_and_forgotten() -> void:
	var world: InfiltrationWorld = _world()
	world.doors_open[0] = true
	var checker: int = _first_checker(world, 600)
	assert_int(checker).override_failure_message("no guard checked the open door").is_not_equal(-1)
	if checker == -1:
		return
	var peak: float = world.guard(checker).suspicion.belief
	assert_float(peak).is_greater_equal(SuspicionView.threshold(world.actions))
	for step: int in range(600):
		world.step(PlayerIntent.new())
		if not world.doors_open[0] and world.guard(checker).suspicion.belief < peak:
			break
	assert_bool(world.doors_open[0]).override_failure_message("the door was left open").is_false()
	var suspicion: GuardSuspicion = world.guard(checker).suspicion
	assert_float(suspicion.belief).is_less(SuspicionView.threshold(world.actions))
	assert_str(str(suspicion.last_change["by"])).is_equal("open_door")
	assert_str(str(suspicion.last_change["seen"])).is_equal(GuardSuspicion.NOT_SEEN)


func test_the_view_says_the_last_change() -> void:
	TranslationServer.set_locale("en")
	var suspicion := GuardSuspicion.new()
	assert_str(SuspicionView.last_line(suspicion)).is_equal("last change: none yet")
	suspicion.notice_kind("open_door", Vector2(5, 5), 1.0)
	suspicion.reconsider(1.0)
	assert_str(SuspicionView.last_line(suspicion)).starts_with("last change: open_door seen, 0.00 to 0.4")


func test_the_player_opens_and_shuts_a_door_within_reach() -> void:
	var world: InfiltrationWorld = _world()
	world.player.position = world.level.doors[1]["place"] + Vector2(1.0, 0.0)
	var intent := PlayerIntent.new()
	intent.use_door = true
	PlayerActions.apply(world, intent)
	assert_bool(world.doors_open[1]).is_true()
	PlayerActions.apply(world, intent)
	assert_bool(world.doors_open[1]).is_false()
	world.player.position = world.level.start
	PlayerActions.apply(world, intent)
	assert_bool(world.doors_open.has(true)).is_false()


func test_with_nothing_seen_there_is_no_lead() -> void:
	var suspicion := GuardSuspicion.new()
	assert_str(suspicion.lead).is_empty()
	assert_vector(suspicion.lead_place()).is_equal(Vector2.INF)
	assert_str(str(suspicion.asked["noise"])).is_equal(GuardSuspicion.NOT_SEEN)
