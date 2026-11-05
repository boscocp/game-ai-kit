# The bot match's scene seats an empty player model with every match (T100,
# ADR 0016's condition 2): N, and the scene's first match. A suite of its
# own because it loads the scene, and N14 holds every script naming the
# model or `MatchDifficulty` to loading nothing; this one reaches both only
# through `world.difficulty`, and checks what they hold against numbers.
extends GdUnitTestSuite

## What an empty model's counts are, written out: the suite names no class
## of the model's.
const EMPTY: Dictionary = {"shots": 0, "hits": 0, "kills": 0, "deaths": 0, "dealt": 0, "taken": 0, "team_dealt": 0,
		"team_taken": 0, "restarts": 0}


func test_n_in_the_scene_seats_an_empty_model() -> void:
	var scene: Node = (load("res://game3d/botmatch/botmatch.tscn") as PackedScene).instantiate()
	add_child(scene)
	var world: BotMatch = scene.world
	assert_dict(world.difficulty.model.counts()).is_equal(EMPTY)
	world.seat_person(0)
	for step: int in range(roundi(30.0 / world.rules.step)):
		world.step()
	assert_int(world.difficulty.readings.size()).is_greater(0)
	scene._view_key(KEY_N)
	var fresh: BotMatch = scene.world
	assert_bool(fresh == world).is_false()
	assert_int(fresh.person).is_equal(-1)
	assert_int(fresh.person_events.size()).is_equal(0)
	assert_int(fresh.difficulty.readings.size()).is_equal(0)
	assert_dict(fresh.difficulty.model.counts()).is_equal(EMPTY)
	for team: MatchTeam in fresh.teams:
		assert_float(team.aim_error).is_equal_approx(deg_to_rad(fresh.rules.aim_error_degrees), 1e-9)
	scene.free()
