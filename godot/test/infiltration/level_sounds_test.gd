# A sound that goes on is heard while it goes on (T81): held for its hold,
# let go after; a one-off heard once; a louder sound replaces a held one.
extends GdUnitTestSuite


func _guard_hearing(loudness: float, at: float, hold: float) -> InfiltrationGuard:
	var level: InfiltrationLevel = InfiltrationLevel.read(InfiltrationLevel.WAREHOUSE)
	var world: InfiltrationWorld = InfiltrationWorld.make(level, InfiltrationRules.read(), 1, [level.guard_specs[0]])
	var guard: InfiltrationGuard = world.guards[0]
	guard.heard = {"loudness": loudness, "place": Vector2(1, 1), "kind": "footstep", "at": at, "until": at + hold}
	return guard


func test_a_held_sound_is_heard_until_its_hold_ends_and_then_let_go() -> void:
	var guard: InfiltrationGuard = _guard_hearing(0.5, 1.0, 0.4)
	for now: float in [1.0, 1.1, 1.2, 1.3]:
		assert_float(float(LevelSounds.heard_now(guard, now).get("loudness", 0.0))).is_equal(0.5)
	assert_bool(LevelSounds.heard_now(guard, 1.4).is_empty()).is_true()
	assert_bool(guard.heard.is_empty()).is_true()


func test_a_one_off_sound_is_heard_in_the_step_it_arrives_only() -> void:
	var guard: InfiltrationGuard = _guard_hearing(0.5, 1.0, 0.0)
	assert_float(float(LevelSounds.heard_now(guard, 1.0)["loudness"])).is_equal(0.5)
	assert_bool(LevelSounds.heard_now(guard, 1.1).is_empty()).is_true()


func test_the_player_walking_holds_its_steps_for_their_cadence() -> void:
	var level: InfiltrationLevel = InfiltrationLevel.read(InfiltrationLevel.WAREHOUSE)
	var rules: InfiltrationRules = InfiltrationRules.read()
	var world: InfiltrationWorld = InfiltrationWorld.make(level, rules, 1, [level.guard_specs[0]])
	var guard: InfiltrationGuard = world.guards[0]
	world.player.position = guard.position - Vector2.from_angle(guard.facing)
	var intent := PlayerIntent.new()
	intent.direction = Vector2.ONE.normalized()
	world.step(intent)
	assert_bool(guard.heard.is_empty()).is_false()
	assert_float(float(guard.heard["until"]) - float(guard.heard["at"])).is_equal_approx(float(rules.player["noise_every"]), 1e-9)
