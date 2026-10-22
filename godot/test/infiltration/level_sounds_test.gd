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


func _world_of_one() -> InfiltrationWorld:
	var level: InfiltrationLevel = InfiltrationLevel.read(InfiltrationLevel.WAREHOUSE)
	return InfiltrationWorld.make(level, InfiltrationRules.read(), 1, [level.guard_specs[0]])


func _throw(loudness: float) -> Dictionary:
	return {"kind": "thrown_object", "place": Vector2(5, 5), "from": -1, "carries": Vector2.INF,
		"urgency": 0.0, "loudness": loudness, "hold": 0.0}


func test_a_held_footstep_does_not_hide_a_quieter_throw_made_later() -> void:
	var guard: InfiltrationGuard = _guard_hearing(0.8, 1.0, 0.4)
	var world: InfiltrationWorld = _world_of_one()
	world.time = 1.1
	world.sounds._deliver(world, guard, _throw(0.3))
	assert_str(str(LevelSounds.heard_now(guard, 1.1)["kind"])).is_equal("thrown_object")


func test_within_one_step_the_louder_sound_is_the_one_heard() -> void:
	var guard: InfiltrationGuard = _guard_hearing(0.8, 1.0, 0.4)
	var world: InfiltrationWorld = _world_of_one()
	world.time = 1.0
	world.sounds._deliver(world, guard, _throw(0.3))
	assert_str(str(LevelSounds.heard_now(guard, 1.0)["kind"])).is_equal("footstep")


# A one-off: by the time the guard acts its senses have let it go, so a
# glance that read `guard.heard` (wave 80) looked nowhere.
func test_a_glance_turns_to_a_sound_heard_out_of_sight() -> void:
	var world: InfiltrationWorld = _world_of_one()
	var guard: InfiltrationGuard = world.guards[0]
	world.player.position = guard.position - Vector2.from_angle(guard.facing) * 2.0
	world.time = 1.0
	world.sounds.emit(world, "thrown_object", world.player.position, -1)
	InfiltrationSenses.sense(guard, world, 0.1, false)
	assert_bool(guard.percept.sight.perceived()).is_false()
	assert_float(guard.percept.loudness).is_greater(0.0)
	guard.action = "glance"
	assert_vector(GuardActs._act(guard, world)).is_equal(guard.percept.heard_place)
