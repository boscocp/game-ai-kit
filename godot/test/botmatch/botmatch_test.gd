# The bot match's ground and its rules, one promise at a time. The effects
# of the techniques are botmatch_effects.gd's; these name the part when one
# of the floors under them breaks.
extends GdUnitTestSuite

const RAYS: int = 400
## A ray this close to a box's surface may be answered either way: the slab
## test counts touching as a hit, and a physics engine keeps a margin.
const GRAZE: float = 0.02


func test_the_arena_is_its_own_mirror_across_the_middle() -> void:
	var arena := BotArena.new(0.4)
	var mirrored: Dictionary = {}
	for box: AABB in arena.boxes:
		mirrored["%.2f %.2f %.2f %.2f" % [box.position.x, box.position.z, box.size.x, box.size.z]] = true
	for box: AABB in arena.boxes:
		var key: String = "%.2f %.2f %.2f %.2f" % [arena.width - box.end.x, box.position.z, box.size.x, box.size.z]
		assert_bool(mirrored.has(key)).override_failure_message("no mirror for %s" % box).is_true()
	for index: int in range(arena.spawns["blue"].size()):
		var blue: Vector2 = arena.spawns["blue"][index]
		var red: Vector2 = arena.spawns["red"][index]
		assert_vector(Vector2(arena.width - blue.x, blue.y)).is_equal(red)
		# The walk grid is a mirror too, so a spawn on a cell's edge is not.
		assert_int(BotArena.cell_of(red).x).is_equal(int(arena.width) - 1 - BotArena.cell_of(blue).x)


func test_every_spot_and_spawn_is_somewhere_a_bot_can_stand() -> void:
	var arena := BotArena.new(0.4)
	assert_int(arena.spots.size()).is_greater(40)
	for spot: BotArena.Spot in arena.spots:
		assert_bool(arena.can_stand(spot.position, 0.4)).override_failure_message(spot.id).is_true()
	for team: String in arena.spawns:
		for place: Vector2 in arena.spawns[team]:
			assert_bool(arena.can_stand(place, 0.4)).is_true()


func test_the_slab_test_agrees_with_godots_own_rays() -> void:
	var arena := BotArena.new(0.4)
	var world := Node3D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(world)
	for box: AABB in arena.boxes:
		world.add_child(_solid(box))
	await (Engine.get_main_loop() as SceneTree).physics_frame
	await (Engine.get_main_loop() as SceneTree).physics_frame
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var random := RandomNumberGenerator.new()
	random.seed = 51
	var disagreements: Array[String] = []
	var compared: int = 0
	for _ray: int in range(RAYS):
		var from := Vector3(random.randf_range(0, 48), random.randf_range(0.5, 1.6), random.randf_range(0, 32))
		var to := Vector3(random.randf_range(0, 48), random.randf_range(0.5, 1.6), random.randf_range(0, 32))
		# A ray from inside a box is not a hit to Godot (hit_from_inside is
		# off), and no bot's eyes or body are ever inside one.
		if _inside_a_box(arena, from) or _inside_a_box(arena, to):
			continue
		compared += 1
		var physics_clear: bool = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to)).is_empty()
		if physics_clear != arena.clear_line(from, to) and not _grazes(arena, from, to):
			disagreements.append("%s -> %s: physics %s" % [from, to, physics_clear])
	world.queue_free()
	assert_int(compared).is_greater(RAYS * 3 / 4)
	assert_array(disagreements).is_empty()


func _inside_a_box(arena: BotArena, place: Vector3) -> bool:
	for box: AABB in arena.boxes:
		if box.has_point(place):
			return true
	return false


func test_the_same_seed_plays_the_same_match() -> void:
	var first: String = _played(5)
	assert_str(_played(5)).is_equal(first)
	assert_str(_played(6)).is_not_equal(first)


func test_a_bot_is_never_told_of_an_enemy_behind_a_high_box() -> void:
	var rules := MatchRules.new()
	var world := BotMatch.new(1, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)
	var looker: MatchBot = world.bots[0]
	var target: MatchBot = world.bots[6]
	# Either side of the high block at (12, 10): 11 .. 13 east-west.
	looker.position = Vector2(9.0, 10.0)
	looker.facing = 0.0
	target.position = Vector2(15.0, 10.0)
	assert_bool(world.sees(looker, target)).is_false()
	target.position = Vector2(15.0, 14.0)
	assert_bool(world.sees(looker, target)).is_true()
	# Behind it, outside the view cone and farther than NEAR: unseen.
	target.position = Vector2(4.0, 14.0)
	assert_bool(world.sees(looker, target)).is_false()


func test_the_rules_file_is_read_whole() -> void:
	var rules := MatchRules.new()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MatchRules.RULES))
	for key: String in data:
		if key != "about" and key != "knobs":
			assert_float(float(rules.get(key))).override_failure_message(key).is_equal(float(data[key]))
	assert_float(rules.reaction).is_equal(float(data["knobs"]["reaction"]))


func test_a_person_drives_the_same_body_by_the_same_rules() -> void:
	var rules := MatchRules.new()
	var world := BotMatch.new(1, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)
	var mine: MatchBot = world.bots[0]
	mine.controlled = true
	mine.position = Vector2(6.0, 4.0)
	mine.facing = 0.0
	mine.wants_to_walk = Vector2.RIGHT
	for _step: int in range(20):
		world.step()
	# One second east at the rules' speed, no faster.
	assert_float(mine.position.x).is_equal_approx(6.0 + rules.speed, 0.06)
	assert_str(mine.action).is_equal(MatchBot.PLAYED)
	# Walking into the high block at (15, 4) stops at its face.
	for _step: int in range(60):
		world.step()
	assert_float(mine.position.x).is_less(14.0 - rules.body_radius + 0.01)


func test_a_person_hits_what_they_aim_at_and_not_through_a_wall() -> void:
	var rules := MatchRules.new()
	var world := BotMatch.new(1, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)
	var mine: MatchBot = world.bots[0]
	var enemy: MatchBot = world.bots[6]
	mine.position = Vector2(9.0, 14.0)
	mine.facing = 0.0
	enemy.position = Vector2(15.0, 14.0)
	MatchActions.fire_aimed(world, mine)
	assert_int(enemy.health).is_equal(rules.health - rules.damage)
	# Behind the high block at (12, 10), straight along the aim: no hit.
	mine.position = Vector2(9.0, 10.0)
	enemy.position = Vector2(15.0, 10.0)
	MatchActions.fire_aimed(world, mine)
	assert_int(enemy.health).is_equal(rules.health - rules.damage)
	# Off the aim by more than a body's half-width: no hit either.
	mine.position = Vector2(9.0, 14.0)
	enemy.position = Vector2(15.0, 14.5)
	MatchActions.fire_aimed(world, mine)
	assert_int(enemy.health).is_equal(rules.health - rules.damage)


func test_teammates_leave_a_persons_spot_to_them_and_the_list_takes_back_over() -> void:
	var rules := MatchRules.new()
	var world := BotMatch.new(1, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)
	var mine: MatchBot = world.bots[0]
	mine.controlled = true
	var spot: Vector2 = world.place_position(0)
	mine.position = spot
	world.step()
	assert_int(world.teams[0].claims.get(0, -1)).is_equal(mine.id)
	mine.controlled = false
	for _step: int in range(int(1.0 / rules.step)):
		world.step()
	assert_str(mine.action).is_not_equal(MatchBot.PLAYED)


func _played(seed_value: int) -> String:
	var rules := MatchRules.new()
	rules.time_limit = 30.0
	var world := BotMatch.new(seed_value, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)
	world.play_out()
	var places: Array[String] = []
	for bot: MatchBot in world.bots:
		places.append("%.4f,%.4f,%d" % [bot.position.x, bot.position.y, bot.health])
	return "%s %s %d" % [world.score, places, world.stats[0].shots]


# Whether the segment passes within GRAZE of a box's surface: hit by the box
# grown by GRAZE, missed by it shrunk by GRAZE.
func _grazes(arena: BotArena, from: Vector3, to: Vector3) -> bool:
	for box: AABB in arena.boxes:
		var grown: bool = BotArena.segment_hits_box(from, to, box.grow(GRAZE))
		var shrunk: bool = BotArena.segment_hits_box(from, to, box.grow(-GRAZE))
		if grown != shrunk:
			return true
	return false


func _solid(box: AABB) -> StaticBody3D:
	var body := StaticBody3D.new()
	var holder := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	holder.shape = shape
	body.add_child(holder)
	body.position = box.get_center()
	return body
