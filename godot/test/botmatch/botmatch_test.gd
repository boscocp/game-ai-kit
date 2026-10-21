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
## The longest a bot may stand wanting to move, in a whole match: measured
## at 3 s over six matches once bodies were solid and passing was weighed.
const STILL_AT_MOST: float = 5.0
## How much further on one side of a mirrored meeting may get than the
## other, in metres: under one stride at the walking speed.
const MEETING_LEAD: float = 0.2
## How far apart, in seconds, the mean walks from a team's spawns to its
## points may be: under one second's walk is under five metres.
const WALK_TOLERANCE: float = 1.0
## Platforms, a stair and boxes on both levels, for the height checks.
const HEIGHT_ARENA: String = "res://test/botmatch/height_arena.json"


func test_every_arena_is_its_own_mirror_across_the_middle() -> void:
	for path: String in BotArena.ARENAS:
		_assert_mirrored(BotArena.new(0.4, path))


func _assert_mirrored(arena: BotArena) -> void:
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


func test_an_arena_made_at_random_is_a_mirror_and_playable() -> void:
	# T67's third arena, which the effects test plays: a few seeds' worth.
	for seed_value: int in range(1, 6):
		var data: Dictionary = RandomArena.make(seed_value)
		assert_bool(data.is_empty()).override_failure_message("seed %d made no arena" % seed_value).is_false()
		var arena := BotArena.new(0.4, data)
		_assert_mirrored(arena)
		_assert_spots_mirrored(arena)
		assert_bool(RandomArena.playable(arena, 0.4)).is_true()
		assert_int(arena.spots.size()).is_greater(10)


func test_an_arena_with_a_point_walled_in_is_not_playable() -> void:
	# The generator's own check, shown a point inside a box: it must refuse.
	var data: Dictionary = RandomArena.make(1)
	var point: Dictionary = data["points"][2]
	(data["boxes"] as Array).append({"x": point["x"], "z": point["z"], "width": 7, "depth": 7, "height": 5.0})
	assert_bool(RandomArena.playable(BotArena.new(0.4, data), 0.4)).is_false()


func test_the_cover_spots_are_a_mirror_and_never_crowd_each_other() -> void:
	for path: String in BotArena.ARENAS:
		_assert_spots_mirrored(BotArena.new(0.4, path))


func _assert_spots_mirrored(arena: BotArena) -> void:
	var places: Dictionary = {}
	for spot: BotArena.Spot in arena.spots:
		places["%.3f %.3f %s" % [spot.position.x, spot.position.y, spot.low]] = true
	for spot: BotArena.Spot in arena.spots:
		var mirror: String = "%.3f %.3f %s" % [arena.width - spot.position.x, spot.position.y, spot.low]
		assert_bool(places.has(mirror)).override_failure_message("no mirror for %s" % spot.position).is_true()
		for other: BotArena.Spot in arena.spots:
			var crowding: bool = other != spot and other.position.distance_to(spot.position) < BotArena.SPOT_SPACING - 1e-3
			assert_bool(crowding).override_failure_message("%s and %s" % [spot.position, other.position]).is_false()


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
	for path: String in BotArena.ARENAS:
		_assert_walks_even(path)


func _assert_walks_even(path: String) -> void:
	var blue: PackedFloat64Array = _mean_walks(BotMatch.BLUE, path)
	var red: PackedFloat64Array = _mean_walks(BotMatch.RED, path)
	for point: int in range(blue.size()):
		var apart: float = absf(blue[point] - blue[0])
		assert_float(apart).override_failure_message("%s, blue: %s" % [path, blue]).is_less_equal(WALK_TOLERANCE)
		assert_float(red[point]).is_equal_approx(blue[point], 0.05)


func test_no_point_sees_into_a_spawn() -> void:
	# A body standing on a spawn, from eyes standing on a point.
	var rules := MatchRules.new()
	for path: String in BotArena.ARENAS:
		_assert_no_point_sees_a_spawn(rules, BotArena.new(rules.body_radius, path))


func _assert_no_point_sees_a_spawn(rules: MatchRules, arena: BotArena) -> void:
	var starts: Array = arena.spawns["blue"] + arena.spawns["red"]
	for point: Vector2 in arena.point_places:
		for start: Vector2 in starts:
			var seen: bool = arena.clear_line(arena.above(point, rules.eye_height), arena.above(start, rules.chest_height))
			assert_bool(seen).override_failure_message("%s sees %s" % [point, start]).is_false()


func test_the_same_agents_play_a_whole_match_on_the_other_arena() -> void:
	# The owner's test of an agent (AIMA's): on another map it must cope,
	# with nothing in its code knowing which map it is on. Every point is
	# taken by someone, both sides fire, the power weapon is fetched, and
	# nobody stands blocked for long.
	var counter := ErrorCounter.new()
	OS.add_logger(counter)
	var rules := MatchRules.new()
	var world := BotMatch.new(3, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules,
			BotArena.new(rules.body_radius, BotArena.YARDS))
	var taken: Dictionary = {}
	var still: PackedFloat64Array = PackedFloat64Array()
	still.resize(world.bots.size())
	var longest_still: float = 0.0
	while not world.over():
		var before: Array[Vector2] = []
		for bot: MatchBot in world.bots:
			before.append(bot.position)
		world.step()
		for index: int in range(world.point_owner.size()):
			taken[index] = taken.get(index, false) or world.point_owner[index] != -1
		for bot: MatchBot in world.bots:
			still[bot.id] = still[bot.id] + rules.step if _wants_to_move_and_did_not(bot, before[bot.id]) else 0.0
			longest_still = maxf(longest_still, still[bot.id])
	OS.remove_logger(counter)
	assert_int(counter.errors).is_equal(0)
	assert_bool(taken.values().all(func(was: bool) -> bool: return was)).override_failure_message("taken: %s" % taken).is_true()
	assert_int(world.stats[0].shots).is_greater(100)
	assert_int(world.stats[1].shots).is_greater(100)
	assert_int(world.stats[0].power_taken + world.stats[1].power_taken).is_greater(0)
	# How long any bot wanted to move and stood: not `blocked_for`, which the
	# passage choice resets each time it decides, so could never grow.
	assert_float(longest_still).override_failure_message("stood %.1f s wanting to move" % longest_still).is_less(STILL_AT_MOST)


# Alive, walking or falling back, not yet where it goes, and where it was.
func _wants_to_move_and_did_not(bot: MatchBot, before: Vector2) -> bool:
	var moving: bool = bot.action == MatchBot.MOVE or bot.action == MatchBot.FALL_BACK
	return bot.alive() and moving and not bot.arrived() and bot.position.distance_to(before) < 0.01


func test_the_acting_order_turns_round_so_neither_side_always_moves_first() -> void:
	# Bodies are solid: who moves first takes a contested door, and in id
	# order that was always blue.
	var rules := MatchRules.new()
	var world := BotMatch.new(1, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)
	var first: Array[int] = [0, 0]
	for _step: int in range(20):
		first[world.acting_order()[0].team] += 1
		world.time += rules.step
	assert_array(first).is_equal([10, 10])


func test_an_exact_tie_round_a_body_turns_both_sides_the_same_way() -> void:
	# A body square on the line of the step: turning 45 degrees either way is
	# as near and as clear. The tie goes south for both, which the mirror
	# across x keeps -- a fixed "+45 first" turned blue south and red north.
	var rules := MatchRules.new()
	var world := BotMatch.new(1, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)
	for bot: MatchBot in world.bots:
		bot.respawn_left = INF
	var turned: Array[float] = []
	for side: Array in [[0, 6, 1.0], [6, 0, -1.0]]:
		var mover: MatchBot = world.bots[side[0]]
		var body: MatchBot = world.bots[side[1]]
		mover.respawn_left = 0.0
		body.respawn_left = 0.0
		mover.position = Vector2(24.0 - 0.45 * side[2], 16.5)
		body.position = Vector2(24.0 + 0.45 * side[2], 16.5)
		var step := Vector2(0.225 * side[2], 0.0)
		turned.append(MatchActions._best_step(world, mover, step, mover.position + step * 20.0).y)
		mover.respawn_left = INF
		body.respawn_left = INF
	assert_float(turned[0]).is_greater(0.0)
	assert_float(turned[1]).is_equal_approx(turned[0], 1e-6)


func test_a_teammate_stepping_aside_takes_the_same_side_for_both_teams() -> void:
	# Straight away from the asker blocked by a third body: either side is as
	# far from it, and the tie goes south for both -- "+90 first" sent blue's
	# teammate north and red's south.
	var rules := MatchRules.new()
	var world := BotMatch.new(1, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)
	for bot: MatchBot in world.bots:
		bot.respawn_left = INF
	var asides: Array[float] = []
	for side: Array in [[0, 1, 2, 1.0], [6, 7, 8, -1.0]]:
		var placed: Array[MatchBot] = []
		for index: int in range(3):
			var bot: MatchBot = world.bots[side[index]]
			bot.respawn_left = 0.0
			bot.position = Vector2(24.0 + (index - 1.5) * 0.85 * side[3], 16.5)
			placed.append(bot)
		asides.append(MatchPassage._aside(world, placed[0], placed[1]).y)
		for bot: MatchBot in placed:
			bot.respawn_left = INF
	assert_float(asides[0]).is_greater(16.5)
	assert_float(asides[1]).is_equal_approx(asides[0], 1e-6)


func test_a_head_on_meeting_favours_neither_side() -> void:
	# Blue east and red west along one row, meeting at the mirror line, in
	# the match's own acting order. Moving one after the other, they cannot
	# end as each other's mirror -- the first to step aside takes a side,
	# and the other takes the free one -- but neither may get further on.
	# This one holds the whole of it; the two above hold each rule.
	var rules := MatchRules.new()
	var world := BotMatch.new(1, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)
	for bot: MatchBot in world.bots:
		bot.respawn_left = INF
	var blue: MatchBot = _walker(world, 0, Vector2(21.5, 16.5), Vector2(27.5, 16.5))
	var red: MatchBot = _walker(world, 6, Vector2(26.5, 16.5), Vector2(20.5, 16.5))
	var widest: float = 0.0
	for _step: int in range(40):
		for bot: MatchBot in world.acting_order().filter(func(each: MatchBot) -> bool: return each.alive()):
			MatchActions.act(world, bot, rules.step)
		world.time += rules.step
		widest = maxf(widest, absf((blue.position.x - 21.5) - (26.5 - red.position.x)))
	assert_bool(blue.arrived() and red.arrived()).is_true()
	assert_float(widest).override_failure_message("one got %.2f m further on" % widest).is_less(MEETING_LEAD)


func _walker(world: BotMatch, bot_id: int, start: Vector2, goal: Vector2) -> MatchBot:
	var bot: MatchBot = world.bots[bot_id]
	bot.respawn_left = 0.0
	bot.position = start
	world.send(bot, goal, -1)
	bot.action = MatchBot.MOVE
	return bot


func test_red_walks_the_mirror_of_blues_path_to_a_point_on_the_line() -> void:
	# Every point sits on the mirror line, a cell edge: red's path must be
	# blue's mirrored, not one cell short.
	var rules := MatchRules.new()
	for path: String in BotArena.ARENAS:
		_assert_every_path_mirrors(_match_on(rules, path))


func _match_on(rules: MatchRules, path: String) -> BotMatch:
	var arena := BotArena.new(rules.body_radius, path)
	return BotMatch.new(1, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules, arena)


func _assert_every_path_mirrors(world: BotMatch) -> void:
	for point: Vector2 in world.arena.point_places:
		_assert_paths_mirror(world, point)


func _assert_paths_mirror(world: BotMatch, point: Vector2) -> void:
	var blue: MatchBot = world.bots[0]
	var red: MatchBot = world.bots[6]
	world.send(blue, point, -1)
	world.send(red, point, -1)
	var mirrored: Array[Vector2i] = []
	for cell: Vector2i in red.path:
		mirrored.append(Vector2i(int(world.arena.width) - 1 - cell.x, cell.y))
	assert_array(mirrored).override_failure_message("to %s" % point).is_equal(blue.path)


func test_a_part_used_power_weapon_is_worth_no_walk_home() -> void:
	# The base gives its holder nothing until it is empty: weighed as spent,
	# a holder with seven rounds walked home and stood there for the match.
	var rules := MatchRules.new()
	var world := BotMatch.new(1, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)
	var bot: MatchBot = world.bots[0]
	world.supply.power_back_at = INF
	world.teams[0].bot_modes[bot.id] = MatchTeam.HOLD
	MatchSupply.arm_power(bot, rules)
	bot.ammo = 7
	bot.position = world.arena.resupply["blue"]
	world.supply.think(world, world.teams[0])
	assert_str(bot.errand).is_equal(MatchSupply.NO_ERRAND)
	# Empty, the base gives it a rifle: then it is worth the walk.
	bot.ammo = 0
	bot.position = Vector2(10.5, 16.5)
	world.supply.think(world, world.teams[0])
	assert_str(bot.errand).is_equal(MatchSupply.RESUPPLY)


func test_a_respawn_leaves_nothing_of_the_last_life_behind() -> void:
	var rules := MatchRules.new()
	var world := BotMatch.new(1, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)
	var bot: MatchBot = world.bots[0]
	bot.velocity = Vector2(40.0, 0.0)
	bot.blocked_for = 0.2
	bot.refused_by[1] = 3.0
	bot.last_passage = {"chosen": PassageChoice.WAIT}
	bot.reload_left = 1.0
	world.respawn(bot)
	assert_vector(bot.velocity).is_equal(Vector2.ZERO)
	assert_float(bot.blocked_for).is_equal(0.0)
	assert_bool(bot.refused_by.is_empty() and bot.last_passage.is_empty()).is_true()
	assert_float(bot.reload_left).is_equal(0.0)


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
	mine.pitch = atan2(rules.chest_height - rules.eye_height, 2.0)
	MatchActions.fire_aimed(world, mine)
	assert_int(enemy.health).is_equal(rules.health - rules.damage)
	# From the ground below, level, the platform's side takes the shot.
	mine.position = Vector2(9.5, 3.0)
	enemy.position = Vector2(14.5, 3.0)
	mine.pitch = 0.0
	MatchActions.fire_aimed(world, mine)
	assert_int(enemy.health).is_equal(rules.health - rules.damage)


# Each point's mean walk, in seconds, from every spawn of `side`; each walk
# is asserted within three to nine seconds on the way.
func _mean_walks(side: int, path: String) -> PackedFloat64Array:
	var rules := MatchRules.new()
	var world := BotMatch.new(1, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules,
			BotArena.new(rules.body_radius, path))
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


# Seconds for `bot` to walk from `start` to `goal` in `world`, by its path,
# alone: the others are out of the match, so this is the map's walk and not
# a queue behind teammates standing in the spawn room.
func _walk_time(world: BotMatch, bot: MatchBot, start: Vector2, goal: Vector2) -> float:
	for other: MatchBot in world.bots:
		other.respawn_left = INF if other != bot else 0.0
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
	# Down at the chest, 1.2 m up, six metres on: the torso.
	mine.pitch = atan2(rules.chest_height - rules.eye_height, 6.0)
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
	mine.pitch = atan2(rules.chest_height - rules.eye_height, 6.0)
	# Off the aim by more than a body's half-width: no hit either.
	mine.position = Vector2(15.0, 13.0)
	enemy.position = Vector2(21.0, 13.5)
	MatchActions.fire_aimed(world, mine)
	assert_int(enemy.health).is_equal(rules.health - rules.damage)


func test_a_bot_sprints_to_a_far_goal_and_walks_once_an_enemy_is_seen() -> void:
	var rules := MatchRules.new()
	var world := BotMatch.new(1, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)
	var bot: MatchBot = world.bots[0]
	# Along lane A's north side, clear of every box.
	bot.position = Vector2(15.0, 3.0)
	world.send(bot, Vector2(15.0 + rules.sprint_from + 4.0, 3.0), -1)
	bot.action = MatchBot.MOVE
	bot.choose_pace([] as Array[int], rules.sprint_from)
	assert_bool(bot.sprinting).is_true()
	MatchActions.act(world, bot, 1.0)
	assert_float(bot.position.x).is_equal_approx(15.0 + rules.sprint_speed, 1e-3)
	# An enemy in its row: it walks, the same far goal or not.
	bot.choose_pace([6] as Array[int], rules.sprint_from)
	assert_bool(bot.sprinting).is_false()
	# Near its goal it walks too.
	bot.position = Vector2(15.0 + rules.sprint_from, 3.0)
	bot.choose_pace([] as Array[int], rules.sprint_from)
	assert_bool(bot.sprinting).is_false()


func test_nobody_fires_while_sprinting() -> void:
	var rules := MatchRules.new()
	var world := BotMatch.new(1, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)
	var mine: MatchBot = world.bots[0]
	var enemy: MatchBot = world.bots[6]
	mine.controlled = true
	mine.action = MatchBot.PLAYED
	mine.position = Vector2(15.0, 13.0)
	enemy.position = Vector2(21.0, 13.0)
	mine.wants_to_walk = Vector2.RIGHT
	mine.wants_to_sprint = true
	mine.wants_to_fire = true
	# The trigger held cancels the sprint; the key alone sprints and holds fire.
	MatchActions.act(world, mine, rules.step)
	assert_bool(mine.sprinting).is_false()
	assert_int(world.stats[0].shots).is_equal(1)
	mine.wants_to_fire = false
	MatchActions.act(world, mine, rules.step)
	assert_bool(mine.sprinting).is_true()
	# A bot set to shoot while sprinting -- planted, its list never does --
	# does not fire, and a shot forced through is counted.
	var bot: MatchBot = world.bots[1]
	bot.position = Vector2(15.0, 14.0)
	bot.facing = 0.0
	bot.goal = bot.position
	bot.action = MatchBot.SHOOT
	bot.target = enemy.id
	bot.sprinting = true
	MatchActions.act(world, bot, rules.step)
	assert_int(world.stats[0].shots).is_equal(1)
	MatchActions.fire(world, bot, enemy)
	assert_int(world.stats[0].shots_sprinting).is_equal(1)


func test_a_bot_reloads_early_when_it_weighs_quiet_and_where_it_was_going() -> void:
	var rules := MatchRules.new()
	var world := BotMatch.new(1, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)
	var bot: MatchBot = world.bots[0]
	var places: Dictionary = {6: Vector2(30.0, 3.0)}
	bot.position = Vector2(15.0, 3.0)
	bot.goal = bot.position
	# Nine rounds of thirty: reloading is worth 0.55, holding 0.3.
	bot.ammo = 9
	bot.decide(_percepts(bot, 1.0, [] as Array[int], places), 0.0)
	assert_str(bot.action).is_equal(MatchBot.RELOAD)
	# An enemy in sight, even one not reacted to yet: it does not.
	bot.decide(_percepts(bot, 1.0, [6] as Array[int], places), 5.0)
	assert_str(bot.action).is_not_equal(MatchBot.RELOAD)
	# On its way somewhere: not yet.
	bot.goal = Vector2(25.0, 3.0)
	bot.decide(_percepts(bot, 1.0, [] as Array[int], places), 0.0)
	assert_str(bot.action).is_equal(MatchBot.MOVE)
	# Enough rounds left -- sixteen, worth 0.2 to reload: it holds.
	bot.goal = bot.position
	bot.ammo = 16
	bot.decide(_percepts(bot, 1.0, [] as Array[int], places), 0.0)
	assert_str(bot.action).is_equal(MatchBot.HOLD)


func test_a_shot_takes_the_damage_of_the_zone_it_crosses() -> void:
	# Six metres apart, standing: aimed at the middle of each zone in turn.
	var rules := MatchRules.new()
	var world := BotMatch.new(1, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)
	var mine: MatchBot = world.bots[0]
	var enemy: MatchBot = world.bots[6]
	mine.position = Vector2(15.0, 3.0)
	mine.facing = 0.0
	enemy.position = Vector2(21.0, 3.0)
	var expected: Dictionary = {MatchRules.HEAD: 24, MatchRules.TORSO: 12, MatchRules.LIMB: 6}
	for zone: String in expected:
		enemy.health = rules.health
		var middle: float = MatchActions.zone_middle(rules, zone, false)
		mine.pitch = atan2(middle - rules.eye_height, 6.0)
		MatchActions.fire_aimed(world, mine)
		assert_int(rules.health - enemy.health).override_failure_message(zone).is_equal(expected[zone])
		assert_str(str(world.recent_shots[-1][6])).is_equal(zone)
	assert_int(world.stats[0].zone_hits[MatchRules.HEAD]).is_equal(1)
	# Over the shoulder, beside the head: air, and no hit.
	enemy.health = rules.health
	enemy.position = Vector2(21.0, 3.0 + rules.head_half_width + 0.05)
	mine.pitch = atan2(MatchActions.zone_middle(rules, MatchRules.HEAD, false) - rules.eye_height, 6.0)
	MatchActions.fire_aimed(world, mine)
	assert_int(enemy.health).is_equal(rules.health)


func test_the_zones_shrink_with_a_crouched_body() -> void:
	var rules := MatchRules.new()
	var shrink: float = rules.crouched_body_height / rules.body_height
	assert_str(rules.zone_at(rules.head_from * shrink + 0.01, 0.0, true)).is_equal(MatchRules.HEAD)
	assert_str(rules.zone_at(rules.head_from * shrink + 0.01, 0.0, false)).is_equal(MatchRules.TORSO)
	assert_str(rules.zone_at(rules.crouched_body_height + 0.05, 0.0, true)).is_equal(MatchRules.NONE)
	assert_str(rules.zone_at(1.0, rules.torso_half_width + 0.05, false)).is_equal(MatchRules.LIMB)
	assert_str(rules.zone_at(0.4, 0.0, false)).is_equal(MatchRules.LIMB)


func test_the_humanoid_drawn_is_the_zones_of_the_rules() -> void:
	# What a person sees is where a shot lands: the boxes' edges are the
	# rules' zone edges, at the rules' height.
	var rules := MatchRules.new()
	var height: float = rules.body_height
	var head: Array = AssetShelf.HUMANOID["Head"]
	var torso: Array = AssetShelf.HUMANOID["Torso"]
	var arm: Array = AssetShelf.HUMANOID["ArmRight"]
	assert_float(((head[1] as Vector3).y - (head[0] as Vector3).y / 2.0) * height).is_equal_approx(rules.head_from, 0.01)
	assert_float((head[0] as Vector3).x / 2.0 * height).is_equal_approx(rules.head_half_width, 0.01)
	assert_float(((torso[1] as Vector3).y - (torso[0] as Vector3).y / 2.0) * height).is_equal_approx(rules.torso_from, 0.01)
	assert_float((torso[0] as Vector3).x / 2.0 * height).is_equal_approx(rules.torso_half_width, 0.01)
	assert_float(((arm[1] as Vector3).x + (arm[0] as Vector3).x / 2.0) * height).is_equal_approx(rules.body_half_width, 0.01)


func test_a_bot_aims_at_the_head_close_and_the_torso_far() -> void:
	var rules := MatchRules.new()
	var world := BotMatch.new(1, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)
	var shooter: MatchBot = world.bots[0]
	var target: MatchBot = world.bots[6]
	# Along lane A's north side, nothing between them.
	shooter.position = Vector2(15.0, 3.0)
	target.position = Vector2(18.0, 3.0)
	assert_str(MatchAim.ZONES[MatchAim.aim(world, shooter, target)[2]]).is_equal("head")
	target.position = Vector2(33.0, 3.0)
	assert_str(MatchAim.ZONES[MatchAim.aim(world, shooter, target)[2]]).is_equal("torso")
	# Planted: a team that always aims at the head, at the same range.
	world.teams[0].aims_by_worth = false
	assert_str(MatchAim.ZONES[MatchAim.aim(world, shooter, target)[2]]).is_equal("head")


func test_low_cover_hides_the_legs_from_the_aim() -> void:
	# The low box in lane A runs 18.5 .. 19.5; the target stands just east of it.
	var rules := MatchRules.new()
	var world := BotMatch.new(1, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)
	var shooter: MatchBot = world.bots[0]
	var target: MatchBot = world.bots[6]
	shooter.position = Vector2(15.0, 5.0)
	target.position = Vector2(20.3, 5.0)
	var exposure: Dictionary = {}
	for zone: AimChoice.Zone in MatchAim.zones_of(world, shooter, target):
		exposure[zone.name] = zone.exposure
	assert_dict(exposure).is_equal({"head": 1.0, "torso": 1.0, "arms": 1.0, "legs": 0.0})


func test_aiming_by_worth_does_more_damage_a_shot_at_range_than_always_the_head() -> void:
	# Two thousand shots at fifteen metres, the same rolls for both: what the
	# technique is for, shown on its own before the effects test shows it in
	# whole matches.
	var rules := MatchRules.new()
	var damage: Array[int] = []
	for by_worth: bool in [true, false]:
		var world := BotMatch.new(7, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)
		world.teams[0].aims_by_worth = by_worth
		var shooter: MatchBot = world.bots[0]
		var target: MatchBot = world.bots[6]
		shooter.position = Vector2(15.0, 3.0)
		target.position = Vector2(30.0, 3.0)
		for _shot: int in range(2000):
			target.health = rules.health
			shooter.ammo = rules.magazine
			MatchActions.fire(world, shooter, target)
		damage.append(world.stats[0].damage)
	assert_int(damage[0]).override_failure_message("by worth %d, always the head %d" % damage).is_greater(damage[1])


func test_a_rifle_has_120_rounds_and_a_reload_takes_only_what_is_left() -> void:
	var rules := MatchRules.new()
	var world := BotMatch.new(1, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)
	var bot: MatchBot = world.bots[0]
	assert_int(bot.ammo + bot.reserve).is_equal(120)
	bot.ammo = 5
	bot.reserve = 10
	bot.action = MatchBot.RELOAD
	for _step: int in range(int(rules.reload_time / rules.step) + 2):
		MatchActions.act(world, bot, rules.step)
	assert_int(bot.ammo).is_equal(15)
	assert_int(bot.reserve).is_equal(0)
	# Nothing left: no reload, and its list does not ask for one.
	bot.ammo = 0
	bot.decide(_percepts(bot, 1.0), 0.0)
	assert_str(bot.action).is_not_equal(MatchBot.RELOAD)


func test_a_reload_that_finished_does_not_begin_again_before_the_next_decision() -> void:
	# The action stays RELOAD until the bot decides again; a finished reload
	# used to start another in that gap, so every reload took two.
	var rules := MatchRules.new()
	var world := BotMatch.new(1, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)
	var bot: MatchBot = world.bots[0]
	bot.ammo = 5
	bot.action = MatchBot.RELOAD
	for _step: int in range(int(rules.reload_time * 1.5 / rules.step)):
		MatchActions.act(world, bot, rules.step)
	assert_int(bot.ammo).is_equal(rules.magazine)
	assert_int(bot.reserve).is_equal(rules.reserve - 25)
	assert_float(bot.reload_left).is_equal(0.0)


func test_a_person_walks_while_reloading_but_does_not_sprint_and_reloads_only_by_hand() -> void:
	var rules := MatchRules.new()
	var world := BotMatch.new(1, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)
	var mine: MatchBot = world.bots[0]
	mine.controlled = true
	mine.position = Vector2(15.0, 3.0)
	mine.wants_to_walk = Vector2.RIGHT
	mine.wants_to_sprint = true
	mine.reload_left = rules.reload_time
	mine.ammo = 0
	world.step()
	assert_str(mine.action).is_equal(MatchBot.PLAYED)
	for _step: int in range(19):
		world.step()
	# A second at the walking speed, not the sprint, and the reload went on.
	assert_float(mine.position.x).is_equal_approx(15.0 + rules.speed, 0.06)
	assert_bool(mine.sprinting).is_false()
	assert_float(mine.reload_left).is_less(rules.reload_time - 0.9)
	# Empty, the trigger alone reloads nothing.
	mine.reload_left = 0.0
	mine.ammo = 0
	mine.wants_to_fire = true
	mine.wants_to_sprint = false
	world.step()
	assert_float(mine.reload_left).is_equal(0.0)
	assert_int(mine.ammo).is_equal(0)


func test_the_base_fills_a_rifle_and_the_power_weapon_comes_back_a_minute_later() -> void:
	var rules := MatchRules.new()
	var world := BotMatch.new(1, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)
	var bot: MatchBot = world.bots[0]
	bot.ammo = 3
	bot.reserve = 0
	bot.position = world.arena.resupply["blue"]
	world.supply.touch(world, bot)
	assert_int(bot.ammo + bot.reserve).is_equal(120)
	bot.position = world.arena.power_place
	world.supply.touch(world, bot)
	assert_str(bot.weapon).is_equal(MatchSupply.POWER)
	assert_int(bot.ammo).is_equal(rules.power_rounds)
	assert_bool(world.supply.power_there(world.time + rules.power_respawn - 0.1)).is_false()
	assert_bool(world.supply.power_there(world.time + rules.power_respawn)).is_true()
	# Three times the rifle's damage, a torso hit.
	var enemy: MatchBot = world.bots[6]
	MatchActions.land(world, bot, enemy, MatchRules.TORSO)
	assert_int(rules.health - enemy.health).is_equal(rules.damage * 3)
	# At the base with rounds left it keeps it; empty, it takes a rifle back.
	bot.position = world.arena.resupply["blue"]
	world.supply.touch(world, bot)
	assert_str(bot.weapon).is_equal(MatchSupply.POWER)
	bot.ammo = 0
	world.supply.touch(world, bot)
	assert_str(bot.weapon).is_equal(MatchSupply.RIFLE)
	assert_int(bot.ammo + bot.reserve).is_equal(120)


func test_a_death_brings_back_the_rifle_and_a_streak_of_five_earns_the_power_weapon() -> void:
	var rules := MatchRules.new()
	var world := BotMatch.new(1, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)
	var bot: MatchBot = world.bots[0]
	MatchSupply.arm_power(bot, rules)
	bot.streak = 4
	world.killed(bot, 6)
	world.respawn(bot)
	assert_str(bot.weapon).is_equal(MatchSupply.RIFLE)
	assert_int(bot.ammo + bot.reserve).is_equal(120)
	assert_int(bot.streak).is_equal(0)
	for victim: int in range(6, 6 + rules.streak_for_power):
		world.killed(world.bots[victim], bot.id)
	assert_int(bot.streak).is_equal(rules.streak_for_power)
	bot.position = world.arena.resupply["blue"]
	world.supply.touch(world, bot)
	assert_str(bot.weapon).is_equal(MatchSupply.POWER)
	assert_int(bot.streak).is_equal(0)


func test_going_back_is_weighed_and_the_planted_rules_never_and_always_differ() -> void:
	var rules := MatchRules.new()
	var world := BotMatch.new(1, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)
	var team: MatchTeam = world.teams[0]
	var bot: MatchBot = world.bots[0]
	world.supply.power_back_at = INF
	team.bot_modes[bot.id] = MatchTeam.HOLD
	bot.position = Vector2(10.5, 16.5)
	# Full: nothing to go back for.
	world.supply.think(world, team)
	assert_str(bot.errand).is_equal(MatchSupply.NO_ERRAND)
	# Ten rounds left, near the base: worth the walk.
	bot.ammo = 10
	bot.reserve = 0
	world.supply.think(world, team)
	assert_str(bot.errand).is_equal(MatchSupply.RESUPPLY)
	assert_float(float(bot.errand_weighing[MatchSupply.RESUPPLY][3])).is_greater(0.0)
	# A power weapon half spent: the base gives it nothing, so it stays;
	# empty, the base gives a rifle, and it goes.
	MatchSupply.arm_power(bot, rules)
	bot.ammo = rules.power_rounds / 2
	world.supply.think(world, team)
	assert_str(bot.errand).is_equal(MatchSupply.NO_ERRAND)
	bot.ammo = 0
	world.supply.think(world, team)
	assert_str(bot.errand).is_equal(MatchSupply.RESUPPLY)
	MatchSupply.arm_rifle(bot, rules)
	bot.ammo = 10
	bot.reserve = 0
	# Planted: a team that never goes back, and one that always does.
	team.resupply_rule = MatchSupply.NEVER
	world.supply.think(world, team)
	assert_str(bot.errand).is_equal(MatchSupply.NO_ERRAND)
	team.resupply_rule = MatchSupply.ALWAYS
	bot.ammo = rules.magazine - 1
	bot.reserve = rules.reserve
	world.supply.think(world, team)
	assert_str(bot.errand).is_equal(MatchSupply.RESUPPLY)
	team.resupply_rule = MatchSupply.WEIGH
	world.supply.think(world, team)
	assert_str(bot.errand).is_equal(MatchSupply.NO_ERRAND)


func test_a_team_sends_one_bot_for_the_power_weapon_and_not_into_enemies() -> void:
	var rules := MatchRules.new()
	var world := BotMatch.new(1, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)
	var team: MatchTeam = world.teams[0]
	for index: int in range(BotMatch.BOTS_A_SIDE):
		world.bots[index].position = Vector2(17.5, 14.5 + index * 0.5)
		team.bot_modes[index] = MatchTeam.HOLD
	world.supply.think(world, team)
	var sent: Array = team.members.filter(func(bot_id: int) -> bool:
		return world.bots[bot_id].errand == MatchSupply.FETCH)
	assert_int(sent.size()).is_equal(1)
	# Three enemies remembered beside it: not worth the danger.
	for enemy: int in [6, 7, 8]:
		team.remember(enemy, world.arena.power_place + Vector2(2.0, 0.0), world.time)
	world.supply.think(world, team)
	assert_int(world.supply.fetcher[0]).is_equal(-1)


func test_nobody_walks_through_a_body_friend_or_enemy() -> void:
	# Walking into another body, on the open floor and with it pinned
	# against the low box in lane A: stopped at two radii, and it unmoved.
	for other_id: int in [6, 1]:
		for pinned: bool in [false, true]:
			_walk_into(other_id, pinned)


func _walk_into(other_id: int, pinned: bool) -> void:
	var rules := MatchRules.new()
	var world := BotMatch.new(1, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)
	var mine: MatchBot = world.bots[0]
	var other: MatchBot = world.bots[other_id]
	mine.controlled = true
	other.controlled = true
	mine.wants_to_walk = Vector2.RIGHT
	mine.position = Vector2(15.0, 5.0 if pinned else 3.0)
	other.position = Vector2(18.0 if pinned else 17.0, mine.position.y)
	var stood: Vector2 = other.position
	for _step: int in range(60):
		world.step()
	var label: String = "%s, %s" % ["enemy" if other_id == 6 else "teammate", "pinned" if pinned else "open"]
	assert_float(mine.position.distance_to(other.position)).override_failure_message(label) \
			.is_greater_equal(rules.body_radius * 2.0 - 1e-3)
	assert_vector(other.position).override_failure_message(label).is_equal_approx(stood, Vector2(1e-3, 1e-3))


func test_a_teammate_asked_to_make_way_weighs_it_and_steps_aside() -> void:
	# Measured in a match: two of a team against lane A's north wall, the
	# one going west waited on the one holding for 13 s. Now the blocked one
	# weighs its ways (no way round, nobody leaving), asks, and the holder,
	# with nobody in sight, finds it cheap and steps aside.
	var rules := MatchRules.new()
	var world := BotMatch.new(1, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)
	var walker: MatchBot = world.bots[4]
	var holder: MatchBot = world.bots[5]
	holder.position = Vector2(24.75, 2.8)
	holder.goal = holder.position
	holder.action = MatchBot.HOLD
	walker.position = Vector2(24.98, 2.014)
	walker.path = [Vector2i(23, 2)] as Array[Vector2i]
	walker.goal = Vector2(23.25, 2.8)
	walker.action = MatchBot.MOVE
	for _step: int in range(40):
		MatchActions.act(world, walker, rules.step)
		holder.decide(_percepts(holder, world.time), 0.0)
		MatchActions.act(world, holder, rules.step)
	assert_bool(walker.arrived()).override_failure_message("stuck at %s" % walker.position).is_true()
	assert_str(str(walker.last_passage["chosen"])).is_equal(PassageChoice.ASK)
	assert_str(str(walker.last_passage["answer"])).is_equal("granted")
	assert_float(walker.position.distance_to(holder.position)).is_greater_equal(rules.body_radius * 2.0 - 1e-3)


func test_a_teammate_in_a_fight_refuses_and_the_asker_remembers_it() -> void:
	var rules := MatchRules.new()
	var world := BotMatch.new(1, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)
	var holder: MatchBot = world.bots[5]
	var request: PassageChoice.Request = MatchPassage.request_to(world, holder, world.bots[4])
	request.saves = 2.0
	assert_bool(PassageChoice.answer(request, MatchPassage.prices_of(rules)).granted).is_true()
	# Two enemies in sight, shooting: 0.5 + 2 x 2.0 + 1.5 = 6 s, more than 2.
	request.enemies_in_sight = 2
	request.shooting = true
	var reply: PassageChoice.Answer = PassageChoice.answer(request, MatchPassage.prices_of(rules))
	assert_float(reply.cost).is_equal_approx(6.0, 1e-9)
	assert_bool(reply.granted).is_false()
	# And when nothing else gets the asker past, its saving has no end: granted.
	request.saves = INF
	assert_bool(PassageChoice.answer(request, MatchPassage.prices_of(rules)).granted).is_true()


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


func test_with_nothing_downloaded_a_bot_is_a_humanoid_of_six_parts() -> void:
	var shelf := AssetShelf.new(AssetShelf.MANIFEST, "res://test/botmatch/nothing_downloaded/")
	var body := BotBody.new(shelf, BotMatchDrawing.BLUE)
	var parts: Array[String] = []
	for mesh: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		parts.append(str(mesh.name))
	parts.sort()
	assert_array(parts).is_equal(["ArmLeft", "ArmRight", "Head", "LegLeft", "LegRight", "Torso"])
	assert_float(AssetShelf.bounds_of(body).size.y).is_equal_approx(BotBody.HEIGHT, 1e-3)
	body.free()


func test_a_new_match_draws_without_writing_to_the_last_ones_bodies() -> void:
	# N frees the drawing's children and builds again; what still pointed at
	# the old bodies made every refresh after it a script error.
	var counter := ErrorCounter.new()
	OS.add_logger(counter)
	var rules := MatchRules.new()
	var drawing := BotMatchDrawing.new()
	drawing.shelf = AssetShelf.new(AssetShelf.MANIFEST, "res://test/botmatch/nothing_downloaded/")
	(Engine.get_main_loop() as SceneTree).root.add_child(drawing)
	for seed_value: int in [1, 2]:
		for child: Node in drawing.get_children():
			child.free()
		var world := BotMatch.new(seed_value, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)
		drawing.build(world)
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


# What `bot` perceives with `in_sight` enemies standing at `places`: the
# record its decision reads, built by hand.
static func _percepts(bot: MatchBot, now: float, in_sight: Array[int] = [], places: Dictionary = {}) -> MatchPercepts:
	var percepts: MatchPercepts = MatchPercepts.of_body(bot, now, 30)
	percepts.in_sight = in_sight
	percepts.enemy_places = places
	return percepts


func test_a_bot_decides_from_its_percepts_alone_with_no_match_at_all() -> void:
	# No arena, no teams, no world: the record is all it reads (T67).
	var bot := MatchBot.new()
	bot.ammo = 30
	bot.reserve = 90
	var percepts: MatchPercepts = _percepts(bot, 5.0, [9] as Array[int], {9: Vector2(10.0, 0.0)})
	percepts.shot_worth = {9: 0.25}
	bot.decide(percepts, 0.3)
	# Seen for the first time now: not reacted to yet, so it holds.
	assert_str(bot.action).is_equal(MatchBot.HOLD)
	percepts.now = 5.5
	bot.decide(percepts, 0.3)
	assert_str(bot.action).is_equal(MatchBot.SHOOT)
	assert_int(bot.target).is_equal(9)
	# Every action was weighed, and the shot scored highest.
	var shoot: int = bot.actions.map(func(each: ActionChoice.Action) -> String: return each.name).find(MatchBot.SHOOT)
	assert_int(bot.last_choice.chosen).is_equal(shoot)
	assert_int(bot.last_choice.scores.size()).is_equal(bot.actions.size())


func test_an_enemy_shot_is_heard_louder_nearer_and_a_friends_is_not_news() -> void:
	var rules := MatchRules.new()
	var world := BotMatch.new(1, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)
	var listener: MatchBot = world.bots[0]
	listener.position = Vector2(15.5, 3.5)
	world.bots[1].position = Vector2(16.5, 3.5)
	world.bots[6].position = Vector2(30.5, 3.5)
	world.record_shot(world.bots[1], -1, false, Vector3.ZERO)
	assert_float(MatchSenses.perceive(world, listener, false).heard).is_equal(0.0)
	world.record_shot(world.bots[6], -1, false, Vector3.ZERO)
	var heard: MatchPercepts = MatchSenses.perceive(world, listener, false)
	assert_float(heard.heard).is_equal_approx(1.0 - 15.0 / rules.shot_heard_metres, 1e-6)
	assert_vector(heard.heard_from).is_equal(world.bots[6].position)
	# Out of hearing, nothing.
	listener.position = Vector2(0.5, 3.5)
	assert_float(MatchSenses.perceive(world, listener, false).heard).is_equal(0.0)
