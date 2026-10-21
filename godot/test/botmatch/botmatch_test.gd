# The bot match's ground and its rules, one promise at a time. The effects
# of the techniques are botmatch_effects.gd's; these name the part when one
# of the floors under them breaks.
extends GdUnitTestSuite

## Rays drawn; those with an end inside a box are not compared, and on the
## lanes map, half of it walls, that is most of them.
const RAYS: int = 1600
## A ray this close to a box's surface may be answered either way: the slab
## test counts touching as a hit, and a physics engine keeps a margin.
const GRAZE: float = 0.02
## How far apart, in seconds, the mean walks from a team's spawns to its
## points may be: under one second's walk is under five metres.
const WALK_TOLERANCE: float = 1.0
## Platforms, a stair and boxes on both levels, for the height checks.
const HEIGHT_ARENA: String = "res://test/botmatch/height_arena.json"


func test_the_arena_is_its_own_mirror_across_the_middle() -> void:
	var arena := BotArena.new(0.4)
	var mirrored: Dictionary = {}
	for box: AABB in arena.boxes:
		mirrored["%.2f %.2f %.2f %.2f %.2f" % [box.position.x, box.position.z, box.size.x, box.size.z, box.size.y]] = true
	for box: AABB in arena.boxes:
		var key: String = "%.2f %.2f %.2f %.2f %.2f" % [arena.width - box.end.x, box.position.z, box.size.x, box.size.z, box.size.y]
		assert_bool(mirrored.has(key)).override_failure_message("no mirror for %s" % box).is_true()
	# The floor too, cell by cell: a stair on one side only is no mirror.
	for x: int in range(int(arena.width)):
		for z: int in range(int(arena.depth)):
			var cell := Vector2i(x, z)
			var opposite := Vector2i(int(arena.width) - 1 - x, z)
			assert_float(arena.walk_graph.height_of(opposite)).is_equal(arena.walk_graph.height_of(cell))
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
	await _assert_agrees_with_physics(BotArena.new(0.4), 1.6)


func test_the_slab_test_agrees_with_godots_rays_over_platforms_and_stairs() -> void:
	# Rays as high as eyes on the platform, so some pass over it and some
	# strike its side or a step.
	await _assert_agrees_with_physics(BotArena.new(0.4, HEIGHT_ARENA), 4.5)


func _assert_agrees_with_physics(arena: BotArena, highest: float) -> void:
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
	var blocked: int = 0
	for _ray: int in range(RAYS):
		var from := Vector3(random.randf_range(0, arena.width), random.randf_range(0.5, highest), random.randf_range(0, arena.depth))
		var to := Vector3(random.randf_range(0, arena.width), random.randf_range(0.5, highest), random.randf_range(0, arena.depth))
		# A ray from inside a box is not a hit to Godot (hit_from_inside is
		# off), and no bot's eyes or body are ever inside one.
		if _inside_a_box(arena, from) or _inside_a_box(arena, to):
			continue
		compared += 1
		var physics_clear: bool = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to)).is_empty()
		blocked += 0 if physics_clear else 1
		if physics_clear != arena.clear_line(from, to) and not _grazes(arena, from, to):
			disagreements.append("%s -> %s: physics %s" % [from, to, physics_clear])
	world.queue_free()
	assert_int(compared).is_greater(RAYS / 5)
	# Both answers occur, or agreeing would prove nothing: an arena with no
	# boxes agrees on every ray.
	assert_int(blocked).is_greater(compared / 10)
	assert_int(compared - blocked).is_greater(compared / 10)
	assert_array(disagreements).is_empty()


func test_every_point_is_as_far_from_each_spawn_and_within_three_to_nine_seconds() -> void:
	# Walked by the match itself: a bot sent from each spawn to each point,
	# timed until it arrives. Per team, each point's mean over the spawns is
	# within WALK_TOLERANCE of the others', and red's are blue's, mirrored.
	var blue: PackedFloat64Array = _mean_walks(BotMatch.BLUE)
	var red: PackedFloat64Array = _mean_walks(BotMatch.RED)
	for point: int in range(blue.size()):
		var apart: float = absf(blue[point] - blue[0])
		assert_float(apart).override_failure_message("blue: %s" % blue).is_less_equal(WALK_TOLERANCE)
		assert_float(red[point]).is_equal_approx(blue[point], 0.05)


func test_no_point_sees_into_a_spawn() -> void:
	# A body standing on a spawn, from eyes standing on a point.
	var rules := MatchRules.new()
	var arena := BotArena.new(rules.body_radius)
	var starts: Array = arena.spawns["blue"] + arena.spawns["red"]
	for point: Vector2 in arena.point_places:
		for start: Vector2 in starts:
			var seen: bool = arena.clear_line(arena.above(point, rules.eye_height), arena.above(start, rules.chest_height))
			assert_bool(seen).override_failure_message("%s sees %s" % [point, start]).is_false()


func test_a_stair_is_cut_into_steps_and_the_floor_rises_with_it() -> void:
	var arena := BotArena.new(0.4, HEIGHT_ARENA)
	assert_int(arena.steps.size()).is_equal(4)
	var expected: Array[float] = [0.0, 0.5, 1.0, 1.5, 2.0, 2.5]
	for index: int in range(expected.size()):
		var place := Vector2(7.5 + index, 5.5)
		assert_float(arena.floor_at(place)).override_failure_message("at %s" % place).is_equal_approx(expected[index], 1e-6)
	# A bot on the platform has its eyes eye_height above it.
	assert_float(arena.above(Vector2(14.5, 3.5), 1.5).y).is_equal_approx(4.0, 1e-6)
	# The low box on the platform is low to a bot standing beside it there.
	var on_top: Array = arena.spots.filter(func(spot: BotArena.Spot) -> bool:
		return spot.box == 0 and arena.floor_at(spot.position) > 2.0)
	assert_bool(on_top.is_empty()).is_false()
	assert_bool(on_top.all(func(spot: BotArena.Spot) -> bool: return spot.low)).is_true()
	# No spot hides behind a step.
	for spot: BotArena.Spot in arena.spots:
		assert_bool(arena.steps.has(arena.boxes[spot.box])).is_false()


func test_a_bot_climbs_the_stair_and_never_the_side() -> void:
	var arena := BotArena.new(0.4, HEIGHT_ARENA)
	var from := Vector2i(6, 3)
	var to := Vector2i(14, 3)
	var climbed: Array[Vector2i] = AStarSearch.new().search(arena.walk_graph, from, to).path
	assert_bool(climbed.is_empty()).is_false()
	assert_float(_largest_rise(arena, from, climbed)).is_less_equal(BotArena.MAX_RISE)
	assert_bool(climbed.any(func(cell: Vector2i) -> bool: return cell.x >= 8 and cell.x < 12 and cell.y >= 4 and cell.y < 6)) \
			.override_failure_message("no step of the stair in %s" % [climbed]).is_true()
	# Planted: the same search on the grid alone walks straight up the
	# platform's side. If this ever held the rise too, the check above
	# could not tell a height-aware graph from a flat one.
	var flat: Array[Vector2i] = AStarSearch.new().search(GridSearchGraph.new(arena.walk), from, to).path
	assert_float(_largest_rise(arena, from, flat)).is_greater(BotArena.MAX_RISE)


func test_a_straight_walk_goes_up_a_stair_and_not_up_a_wall() -> void:
	var arena := BotArena.new(0.4, HEIGHT_ARENA)
	assert_bool(arena.walkable(Vector2(7.5, 5.0), Vector2(14.5, 5.0))).is_true()
	assert_bool(arena.walkable(Vector2(10.5, 3.5), Vector2(14.5, 3.5))).is_false()
	assert_bool(arena.can_step(Vector2(11.0, 3.5), Vector2(11.3, 3.5), 0.4)).is_true()
	assert_bool(arena.can_step(Vector2(11.5, 5.0), Vector2(12.1, 5.0), 0.4)).is_true()
	assert_bool(arena.can_step(Vector2(11.5, 3.5), Vector2(12.6, 3.5), 0.4)).is_false()


func test_high_ground_sees_over_cover_that_hides_a_crouching_bot() -> void:
	var rules := MatchRules.new()
	var world := _height_match(rules)
	var looker: MatchBot = world.bots[0]
	var target: MatchBot = world.bots[6]
	# Crouched south of the low box on the ground (8 .. 10, 9 .. 10).
	target.position = Vector2(9.0, 10.6)
	target.crouched = true
	looker.position = Vector2(9.0, 7.0)
	looker.facing = PI / 2.0
	assert_bool(world.sees(looker, target)).is_false()
	# From the platform's edge, 2.5 m up, the same body shows over the box.
	looker.position = Vector2(13.5, 7.5)
	looker.facing = (target.position - looker.position).angle()
	assert_bool(world.sees(looker, target)).is_true()


func test_a_person_climbs_the_stair_and_is_stopped_by_the_side() -> void:
	var rules := MatchRules.new()
	var world := _height_match(rules)
	var mine: MatchBot = world.bots[0]
	mine.controlled = true
	mine.action = MatchBot.PLAYED
	mine.wants_to_walk = Vector2.RIGHT
	mine.position = Vector2(6.5, 3.5)
	for _step: int in range(60):
		MatchActions.act(world, mine, rules.step)
	assert_float(mine.position.x).is_less(12.0)
	assert_float(world.arena.floor_at(mine.position)).is_equal(0.0)
	mine.position = Vector2(6.5, 5.0)
	for _step: int in range(60):
		MatchActions.act(world, mine, rules.step)
	assert_float(mine.position.x).is_greater(12.5)
	assert_float(world.arena.floor_at(mine.position)).is_equal_approx(2.5, 1e-6)


func test_a_shot_level_across_the_platform_hits_a_body_standing_on_it() -> void:
	# The body is between its own floor and its top, not the ground's: a
	# level shot at eye height 4.0 crosses a body from 2.5 to 4.3.
	var rules := MatchRules.new()
	var world := _height_match(rules)
	var mine: MatchBot = world.bots[0]
	var enemy: MatchBot = world.bots[6]
	mine.position = Vector2(13.5, 3.5)
	mine.facing = 0.0
	enemy.position = Vector2(15.5, 3.5)
	MatchActions.fire_aimed(world, mine)
	assert_int(enemy.health).is_equal(rules.health - rules.damage)
	# From the ground below, level, the platform's side takes the shot.
	mine.position = Vector2(9.5, 3.0)
	enemy.position = Vector2(14.5, 3.0)
	MatchActions.fire_aimed(world, mine)
	assert_int(enemy.health).is_equal(rules.health - rules.damage)


# Each point's mean walk, in seconds, from every spawn of `side`; each walk
# is asserted within three to nine seconds on the way.
func _mean_walks(side: int) -> PackedFloat64Array:
	var rules := MatchRules.new()
	var world := BotMatch.new(1, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)
	var bot: MatchBot = world.bots[side * BotMatch.BOTS_A_SIDE]
	var starts: Array = world.arena.spawns[BotMatch.TEAM_NAMES[side]]
	var means := PackedFloat64Array()
	for point: Vector2 in world.arena.point_places:
		var total: float = 0.0
		for start: Vector2 in starts:
			var seconds: float = _walk_time(world, bot, start, point)
			assert_float(seconds).override_failure_message("%s to %s: %.2f s" % [start, point, seconds]).is_between(3.0, 9.0)
			total += seconds
		means.append(total / starts.size())
	return means


# Seconds for `bot` to walk from `start` to `goal` in `world`, by its path.
func _walk_time(world: BotMatch, bot: MatchBot, start: Vector2, goal: Vector2) -> float:
	bot.position = start
	bot.path.clear()
	bot.goal = start
	world.send(bot, goal, -1)
	bot.action = MatchBot.MOVE
	var seconds: float = 0.0
	while not bot.arrived() and seconds < 30.0:
		MatchActions.act(world, bot, world.rules.step)
		seconds += world.rules.step
	return seconds


func _height_match(rules: MatchRules) -> BotMatch:
	var arena := BotArena.new(rules.body_radius, HEIGHT_ARENA)
	return BotMatch.new(1, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules, arena)


# The largest rise or fall between one cell of a walk and the next.
func _largest_rise(arena: BotArena, from: Vector2i, path: Array[Vector2i]) -> float:
	var largest: float = 0.0
	var before: Vector2i = from
	for cell: Vector2i in path:
		largest = maxf(largest, absf(arena.walk_graph.height_of(cell) - arena.walk_graph.height_of(before)))
		before = cell
	return largest


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
	# Either side of the pillar north of B: 23.5 .. 24.5 east-west.
	looker.position = Vector2(21.0, 13.5)
	looker.facing = 0.0
	target.position = Vector2(27.0, 13.5)
	assert_bool(world.sees(looker, target)).is_false()
	target.position = Vector2(27.0, 16.0)
	assert_bool(world.sees(looker, target)).is_true()
	# Behind it, outside the view cone and farther than NEAR: unseen.
	target.position = Vector2(15.0, 16.0)
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
	mine.position = Vector2(15.0, 13.0)
	mine.facing = 0.0
	mine.wants_to_walk = Vector2.RIGHT
	for _step: int in range(20):
		world.step()
	# One second east at the rules' speed, no faster.
	assert_float(mine.position.x).is_equal_approx(15.0 + rules.speed, 0.06)
	assert_str(mine.action).is_equal(MatchBot.PLAYED)
	# Walking into the pillar north of B, from 23.5, stops at its face.
	for _step: int in range(60):
		world.step()
	assert_float(mine.position.x).is_less(23.5 - rules.body_radius + 0.01)


func test_a_person_hits_what_they_aim_at_and_not_through_a_wall() -> void:
	var rules := MatchRules.new()
	var world := BotMatch.new(1, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)
	var mine: MatchBot = world.bots[0]
	var enemy: MatchBot = world.bots[6]
	mine.position = Vector2(15.0, 13.0)
	mine.facing = 0.0
	enemy.position = Vector2(21.0, 13.0)
	MatchActions.fire_aimed(world, mine)
	assert_int(enemy.health).is_equal(rules.health - rules.damage)
	# Behind the pillar north of B, straight along the aim: no hit.
	mine.position = Vector2(21.0, 13.5)
	enemy.position = Vector2(27.0, 13.5)
	MatchActions.fire_aimed(world, mine)
	assert_int(enemy.health).is_equal(rules.health - rules.damage)
	# Aimed at the floor in front of them: the floor stops it, short of the enemy.
	mine.position = Vector2(15.0, 13.0)
	enemy.position = Vector2(21.0, 13.0)
	mine.pitch = deg_to_rad(-30.0)
	MatchActions.fire_aimed(world, mine)
	assert_int(enemy.health).is_equal(rules.health - rules.damage)
	var shot: Array = world.recent_shots[-1]
	assert_float((shot[5] as Vector3).y).is_equal_approx(0.0, 1e-4)
	# Aimed over their head: a miss, though the line across is true.
	mine.pitch = deg_to_rad(20.0)
	MatchActions.fire_aimed(world, mine)
	assert_int(enemy.health).is_equal(rules.health - rules.damage)
	mine.pitch = 0.0
	# Off the aim by more than a body's half-width: no hit either.
	mine.position = Vector2(15.0, 13.0)
	enemy.position = Vector2(21.0, 13.5)
	MatchActions.fire_aimed(world, mine)
	assert_int(enemy.health).is_equal(rules.health - rules.damage)


func test_teammates_leave_a_persons_spot_to_them_and_the_list_takes_back_over() -> void:
	var rules := MatchRules.new()
	var world := BotMatch.new(1, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)
	var mine: MatchBot = world.bots[0]
	mine.controlled = true
	# A place by point A, inside the area a squad holding A chooses in.
	var held: int = world.places_near(world.arena.point_places[0], 3.0)[0]
	var spot: Vector2 = world.place_position(held)
	mine.position = spot
	world.step()
	assert_int(world.teams[0].claims.get(held, -1)).is_equal(mine.id)
	# A teammate choosing round that spot finds it closed to it.
	var mate: MatchBot = world.bots[1]
	mate.position = spot + Vector2(2.0, 0.0)
	world.teams[0].bot_points[mate.id] = 0
	world.teams[0].bot_modes[mate.id] = MatchTeam.HOLD
	TeamTactics.choose_spot(world, world.teams[0], mate, world.time)
	var choice: TacticalPositions.Choice = world.teams[0].last_choice[mate.id][0]
	var places: Array = world.teams[0].last_choice[mate.id][1]
	assert_bool(places.has(held)).override_failure_message("the spot was not among its candidates").is_true()
	assert_str(choice.statuses[places.find(held)]).is_equal(TacticalPositions.CLAIMED)
	assert_int(mate.spot).is_not_equal(held)
	# Given back, it runs its list again and chooses a spot of its own.
	mine.controlled = false
	mine.path.clear()
	mine.chose_at = -INF
	for _step: int in range(int(1.0 / rules.step)):
		world.step()
	assert_str(mine.action).is_not_equal(MatchBot.PLAYED)
	assert_float(mine.chose_at).is_greater(0.0)


func test_shots_of_every_length_are_drawn_without_an_engine_error() -> void:
	var counter := ErrorCounter.new()
	OS.add_logger(counter)
	var rules := MatchRules.new()
	var world := BotMatch.new(1, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)
	var drawing := BotMatchDrawing.new()
	drawing.shelf = AssetShelf.new(AssetShelf.MANIFEST, "res://test/botmatch/nothing_downloaded/")
	(Engine.get_main_loop() as SceneTree).root.add_child(drawing)
	drawing.build(world)
	var shooter: MatchBot = world.bots[0]
	var eyes: Vector3 = MatchActions.eyes_of(world, shooter)
	# Planted: shots ending at the muzzle, inside the tracer's first metre,
	# straight up, and far -- every case the tracer's shape must survive.
	for end: Vector3 in [eyes, eyes + Vector3(0.5, 0, 0), eyes + Vector3(0, 5, 0), eyes + Vector3(30, -1, 2)]:
		world.record_shot(shooter, -1, false, end)
	drawing.refresh(world, 0)
	OS.remove_logger(counter)
	drawing.queue_free()
	assert_int(counter.errors).is_equal(0)


## Counts what the engine reports as an error.
class ErrorCounter extends Logger:
	var errors: int = 0

	func _log_error(_function: String, _file: String, _line: int, _code: String,
			_rationale: String, _editor_notify: bool, _error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		errors += 1


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
