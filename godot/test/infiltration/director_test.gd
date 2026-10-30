# The director on the infiltration level (T90): off, the level is T70's;
# on, its reserve waits out of sight, a patrol is never sent where the
# player sees it start, no guard's belief changes when the director acts,
# and on a level where the player lives long enough it goes the whole way
# round: build up, peak, fade, relax, build up.
#
# Each claim has a planted director it must catch: one that cheats on the
# belief, one that sends a guard the player is looking at.
extends GdUnitTestSuite

## The properties' two minutes, for the claims held on every level.
const STEPS: int = 1200
## The scripted players the claims are held on: one that shows itself and
## then hides, one that lies still and throws distractions.
const PLAYERS: Array[String] = ["hide", "distract"]
## A generated level on which the distracting player is never found, so a
## run lasts long enough for whole cycles; `director_measure.gd` prints the
## others, where the guards find it first. Five minutes of it.
const LIVING_LEVEL: int = 10
const LIVING_STEPS: int = 3000

## The runs every claim reads, made once.
static var _measured: Array[Dictionary] = []


func test_off_the_level_is_as_t70_made_it() -> void:
	for level: InfiltrationLevel in InfiltrationRuns.levels():
		var world: InfiltrationWorld = InfiltrationWorld.make(level, InfiltrationRules.read(), 1)
		assert_object(world.director).is_null()
		assert_int(world.guards.size()).is_equal(level.guard_specs.size())
		assert_int(world.guards.filter(func(guard: InfiltrationGuard) -> bool: return guard.reserve()).size()).is_equal(0)


func test_every_level_has_a_reserve_out_of_the_starts_sight() -> void:
	for level: InfiltrationLevel in InfiltrationRuns.levels():
		var world: InfiltrationWorld = InfiltrationWorld.make(level, DirectorRuns.rules(), 1)
		assert_int(level.reserve_specs.size()).override_failure_message("%s has no reserve" % level.name).is_greater_equal(2)
		for spec: Dictionary in level.reserve_specs:
			var post: Vector2 = spec["post"]
			var seen: String = "%s: the start sees the reserve post %s" % [level.name, post]
			assert_bool(DirectorOrders.player_sees(world, post)).override_failure_message(seen).is_false()
			var places: Array = [post] + (spec["beat"] as Array)
			assert_array(_unwalkable(level, places)).is_empty()


func test_a_reserve_the_player_sees_is_not_sent() -> void:
	var world: InfiltrationWorld = InfiltrationWorld.make(InfiltrationRuns.levels()[0], DirectorRuns.rules(), 1)
	var reserve: Array[InfiltrationGuard] = world.guards.filter(func(guard: InfiltrationGuard) -> bool: return guard.reserve())
	world.player.position = reserve[0].post + Vector2(-3.0, 0.0)
	assert_bool(DirectorOrders.player_sees(world, reserve[0].position)).is_true()
	assert_object(DirectorOrders.unseen_reserve(world)).is_not_same(reserve[0])
	var planted: InfiltrationGuard = _nearest_reserve(world)
	assert_object(planted).override_failure_message("the planted picker should take the one in view").is_same(reserve[0])


func test_no_guard_believes_anything_new_when_the_director_acts() -> void:
	var orders: int = 0
	for run: Dictionary in _runs():
		assert_array(run["belief"]).is_empty()
		orders += int(run["sent"]) + int(run["recalled"])
	assert_int(orders).override_failure_message("the director never acted: the claim held nothing").is_greater(0)


func test_a_director_that_tells_a_guard_where_you_are_is_caught() -> void:
	var cheat: Callable = func(world: InfiltrationWorld, guard: InfiltrationGuard) -> void:
		DirectorOrders.give_beat(world, guard)
		guard.collapse_belief(world.level.index_of.get(world.level.cell_of(world.player.position), 0))
	var findings: Array[String] = []
	for level: InfiltrationLevel in InfiltrationRuns.levels():
		findings.append_array(DirectorRuns.run(level, "hide", STEPS, cheat)["belief"])
		if not findings.is_empty():
			break
	assert_array(findings).is_not_empty()


func test_no_patrol_is_sent_where_the_player_sees_it_start() -> void:
	var sent: int = 0
	for run: Dictionary in _runs():
		assert_array(run["seen_sent"]).is_empty()
		sent += int(run["sent"])
	assert_int(sent).override_failure_message("no run sent a patrol: the claim held nothing").is_greater(0)


func test_where_the_player_lives_it_goes_the_whole_way_round() -> void:
	var level := InfiltrationLevel.read(LevelGenerator.make(LIVING_LEVEL), "generated %d" % LIVING_LEVEL)
	var run: Dictionary = DirectorRuns.run(level, "distract", LIVING_STEPS)
	print("director: " + DirectorRuns.line(run))
	assert_array(run["belief"] + run["seen_sent"]).is_empty()
	assert_int(int(run["peaks"])).is_greater(0)
	assert_int(int(run["relaxes"])).override_failure_message("it never relaxed").is_greater(0)
	assert_int(int(run["recalled"])).override_failure_message("no patrol was ever called back").is_greater(0)
	assert_int(int(run["sent"])).is_greater(int(run["recalled"]) - 1)


func _runs() -> Array[Dictionary]:
	if not _measured.is_empty():
		return _measured
	for level: InfiltrationLevel in InfiltrationRuns.levels():
		for mode: String in PLAYERS:
			_measured.append(DirectorRuns.run(level, mode, STEPS))
	return _measured


# Those of `places` the start of `level` cannot walk to.
static func _unwalkable(level: InfiltrationLevel, places: Array) -> Array[String]:
	var from_start: PackedInt32Array = level.arena.steps_from([level.cell_of(level.start)])
	var found: Array[String] = []
	for place: Vector2 in places:
		var cell: Vector2i = level.cell_of(place)
		if not level.walkable(cell) or from_start[cell.y * int(level.arena.width) + cell.x] < 0:
			found.append("%s: %s cannot be walked to" % [level.name, place])
	return found


# The planted picker: the waiting reserve guard nearest the player, seen
# or not.
static func _nearest_reserve(world: InfiltrationWorld) -> InfiltrationGuard:
	var best: InfiltrationGuard = null
	for guard: InfiltrationGuard in world.guards:
		var nearer: bool = best == null or guard.position.distance_to(world.player.position) < best.position.distance_to(world.player.position)
		if guard.reserve() and guard.route.is_empty() and nearer:
			best = guard
	return best
