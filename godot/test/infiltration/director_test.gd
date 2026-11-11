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
## others, where the guards find it first. Five minutes of it. Its
## intensity comes from the player's own distractions: the guards hear
## them and search, and never find who threw them.
const LIVING_LEVEL: int = 10
const LIVING_STEPS: int = 3000

## What `LevelGenerator.make(seed)` wrote for seeds 1 to 11 before the
## reserve existed (main at b6b86d1): the sha-256 of its data as sorted
## JSON. With "reserve" erased, the generator must still write the same.
const BEFORE_THE_RESERVE: Array[String] = [
	"c028d358aae849a4b7d7f2282c911c750bc41154ac1128da2a6a1a4ad0f78e4a",
	"1eb752bd6f2dfd7847e9ffddb7cd5b7df026505da76eb823c5af5ec55f33bb4e",
	"53c98c5eea891b3a3fcc717d9a8ebfda8836d2d3fad74ba9d278adaa0a512f75",
	"9f17bfcc49ead13ef8bfa01da25aabce4eef5c2f414cd521140ed288271abcee",
	"b9e8ff2ccb8c22c5803f5278800a863c5b68e07a808db48431058f395263b84c",
	"89df6e7d5b93d0e5ef5bb8832c4cc18a6a091e9aa890d270777b2a45083d30a7",
	"e82a561414516e88d08d377a4a562b3f3d07f5af3540dafba72a4960d263d888",
	"9b71c01b193492cd2f972589aa0ef451283bd2dc0eda2edda82c3487f8553078",
	"6124e80bd87860058ee814d5b0343bb8f85f1d4bdc98152aa134b44bdb110536",
	"4549984e5f0027c7e9522a4065f4bae27f27a7b0db0b077dfc60fc98947a4187",
	"b8ebe7af609d338457a32b999f36aafcfa841e6cc5d186b365494845773a23c9",
]

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


func test_the_reserve_leaves_every_generated_level_as_it_was() -> void:
	for index: int in range(BEFORE_THE_RESERVE.size()):
		var data: Dictionary = LevelGenerator.make(index + 1)
		data.erase("reserve")
		var fingerprint: String = JSON.stringify(data, "", true).sha256_text()
		assert_str(fingerprint).override_failure_message("generated %d changed" % (index + 1)).is_equal(BEFORE_THE_RESERVE[index])


func test_a_generated_reserve_takes_no_one_elses_place() -> void:
	for index: int in range(BEFORE_THE_RESERVE.size()):
		var level := InfiltrationLevel.read(LevelGenerator.make(index + 1), "generated %d" % (index + 1))
		var places: Array[Vector2i] = [level.cell_of(level.exit_place)]
		for spec: Dictionary in level.guard_specs:
			places.append(level.cell_of(spec["post"]))
			places.append_array((spec["route"] as Array).map(func(place: Vector2) -> Vector2i: return level.cell_of(place)))
		assert_array(_reserve_clashes(level, places)).is_empty()


# The reserve's cells of `level` that are already among `places`, or each other's.
static func _reserve_clashes(level: InfiltrationLevel, places: Array[Vector2i]) -> Array[String]:
	var reserve: Array[Vector2] = []
	for spec: Dictionary in level.reserve_specs:
		reserve.append(spec["post"])
		reserve.append_array(spec["beat"])
	var clashes: Array[String] = []
	for place: Vector2 in reserve:
		var cell: Vector2i = level.cell_of(place)
		if places.has(cell):
			clashes.append("%s: the reserve's %s is taken" % [level.name, cell])
		places.append(cell)
	return clashes


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
	assert_array(_planted_findings({"send": cheat}, "belief")).is_not_empty()


func test_every_route_the_director_gives_is_the_guards_beat_or_none() -> void:
	for run: Dictionary in _runs():
		assert_array(run["route"]).is_empty()


func test_a_director_that_sends_a_guard_to_you_is_caught() -> void:
	var cheat: Callable = func(world: InfiltrationWorld, guard: InfiltrationGuard) -> void:
		guard.route = [world.player.position] as Array[Vector2]
		guard.route_index = 0
	assert_array(_planted_findings({"send": cheat}, "route")).is_not_empty()


func test_no_patrol_is_sent_where_the_player_sees_it_start() -> void:
	var sent: int = 0
	for run: Dictionary in _runs():
		assert_array(run["seen_sent"]).is_empty()
		sent += int(run["sent"])
	assert_int(sent).override_failure_message("no run sent a patrol: the claim held nothing").is_greater(0)


func test_a_director_that_sends_the_nearest_reserve_seen_or_not_is_caught() -> void:
	assert_array(_planted_findings({"pick": _nearest_reserve}, "seen_sent")).is_not_empty()


func test_where_the_player_lives_it_goes_the_whole_way_round() -> void:
	var level := InfiltrationLevel.read(LevelGenerator.make(LIVING_LEVEL), "generated %d" % LIVING_LEVEL)
	var run: Dictionary = DirectorRuns.run(level, "distract", LIVING_STEPS)
	print("director: " + DirectorRuns.line(run))
	assert_int(DirectorRuns.findings(run)).is_equal(0)
	assert_int(int(run["peaks"])).is_greater(0)
	assert_int(int(run["relaxes"])).override_failure_message(
		"it never relaxed on generated %d: pick another level where `make measure-director` shows a relax" % LIVING_LEVEL).is_greater(0)
	assert_int(int(run["recalled"])).override_failure_message("no patrol was ever called back").is_greater(0)
	assert_int(int(run["sent"])).is_greater(int(run["recalled"]) - 1)


# The findings of `kind` in runs of the hiding player with `planted` seams,
# level by level until one finds something.
func _planted_findings(planted: Dictionary, kind: String) -> Array[String]:
	var findings: Array[String] = []
	var tries: Array = []
	for level: InfiltrationLevel in InfiltrationRuns.levels():
		tries.append_array(PLAYERS.map(func(mode: String) -> Array: return [level, mode]))
	for tried: Array in tries:
		findings.append_array(DirectorRuns.run(tried[0], tried[1], STEPS, planted)[kind])
		if not findings.is_empty():
			return findings
	return findings


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


# T121: the director vectors runner refuses a file of the wrong types before
# it reads one. Events, intensities or changes given as text, in a copy of a
# real file, were a SCRIPT ERROR that skipped the check and let it exit 0.
func test_a_director_vector_of_the_wrong_types_is_refused() -> void:
	var runner: GDScript = preload("res://test/infiltration/director_vectors_runner.gd")
	var vector: Dictionary = VectorShape.read_spec("vectors/director/a-peak-is-sustained-then-fades-then-relaxes.json")
	assert_str(VectorShape.why_not(vector, runner.SHAPE)).is_empty()
	var paths: Array = [["events"], ["intensity"], ["changes"], ["events", 0, "step"]]
	for path: Array in paths:
		var why: String = VectorShape.why_not(VectorShape.planted(vector, path, "x"), runner.SHAPE)
		assert_str(why).override_failure_message(str(path)).is_not_empty()