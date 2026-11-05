# T55: the clock's two knobs and its two measures, on hand-made snapshots
# and command lists -- what the league's whole matches cannot pin down.
extends GdUnitTestSuite


# A controller that gives `per_decision` moves of unit 1 and writes down,
# for every view it was handed, the ids of the enemy in it and its funds.
class Busy:
	extends GakRtsController
	var per_decision: int
	var enemies_seen: Array[Array] = []
	var ore_seen: Array[int] = []

	func _init(count: int) -> void:
		per_decision = count

	func decide(view: RtsSnapshot) -> Array[RtsCommand]:
		enemies_seen.append(view.enemies().map(func(unit: Dictionary) -> int: return unit["id"]))
		ore_seen.append(view.resources.get(RtsKinds.ORE, 0))
		var given: Array[RtsCommand] = []
		for index: int in range(per_decision):
			given.append(RtsCommand.move([1] as Array[int], Vector2i(index, 0)))
		return given


# Side 0's view at `tick`: its worker, and from tick 30 on an enemy
# barracks (id 2) on cell (2, 2), which blocks that cell; ore = the tick.
static func _view_at(tick: int) -> RtsSnapshot:
	var view := RtsSnapshot.new()
	view.side = 0
	view.tick = tick
	view.resources = {RtsKinds.ORE: tick}
	view.graph = GakGridGraph.new(4, 4)
	view.units.append({"id": 1, "side": 0, "kind": RtsKinds.WORKER, "position": Vector2(0.5, 0.5)})
	if tick >= 30:
		view.units.append({"id": 2, "side": 1, "kind": RtsKinds.BARRACKS, "position": Vector2(2.5, 2.5)})
		view.graph.block(Vector2i(2, 2))
	return view


func test_a_delay_holds_back_the_enemy_and_nothing_of_the_sides_own() -> void:
	var inner := Busy.new(1)
	var clock := RtsHumanClock.new(inner, 350.0, 0)

	for tick: int in [0, 30, 60]:
		clock.decide(_view_at(tick))

	# The barracks came into sight at 30 and reaches the side at 60.
	assert_array(inner.enemies_seen).is_equal([[], [], [2]])
	assert_array(inner.ore_seen).is_equal([0, 30, 60])
	assert_int(clock.stale).is_equal(3)


func test_a_building_not_yet_seen_does_not_block_its_cell_early() -> void:
	var late: RtsSnapshot = RtsHumanClock._late(_view_at(30), _view_at(0))

	assert_bool(late.graph.is_blocked(Vector2i(2, 2))).is_false()
	assert_bool(_view_at(30).graph.is_blocked(Vector2i(2, 2))).is_true()


func test_no_delay_hands_on_the_present() -> void:
	var inner := Busy.new(1)
	var clock := RtsHumanClock.new(inner, 0.0, 0)

	for tick: int in [0, 30]:
		clock.decide(_view_at(tick))

	assert_array(inner.enemies_seen).is_equal([[], [2]])
	assert_int(clock.stale).is_equal(0)


func test_the_cap_holds_in_every_window() -> void:
	var clock := RtsHumanClock.new(Busy.new(5), 0.0, 3, 1.0)
	var given_at: Array[Dictionary] = []

	for tick: int in range(0, 600, 30):
		for command: RtsCommand in clock.decide(_view_at(tick)):
			given_at.append({"side": 0, "tick": tick})

	assert_int(RtsClockMeasure.busiest(given_at, 0, 1.0)).is_less_equal(3)
	assert_int(clock.delayed).is_greater(0)
	assert_int(clock.dropped).is_greater(0)


func test_no_cap_gives_everything_at_once() -> void:
	var clock := RtsHumanClock.new(Busy.new(5), 0.0, 0)

	assert_int(clock.decide(_view_at(0)).size()).is_equal(5)
	assert_int(clock.delayed + clock.dropped).is_equal(0)


func test_a_reaction_runs_from_a_sighting_to_the_first_command_about_it() -> void:
	var far: Dictionary = RtsCommand.move([1] as Array[int], Vector2i(40, 40)).to_dict()
	var near: Dictionary = RtsCommand.move([1] as Array[int], Vector2i(12, 10)).to_dict()
	var strike: Dictionary = RtsCommand.attack([1] as Array[int], 7).to_dict()
	var accepted: Array[Dictionary] = [{"side": 0, "tick": 10, "command": near}, {"side": 0, "tick": 20, "command": far},
		{"side": 1, "tick": 30, "command": strike}, {"side": 0, "tick": 40, "command": near},
		{"side": 0, "tick": 50, "command": strike}, {"side": 0, "tick": 2000, "command": near}]
	var sightings: Array[Dictionary] = [{"tick": 12, "id": 3, "position": Vector2(10, 10)},
		{"tick": 15, "id": 7, "position": Vector2(60, 60)}, {"tick": 1000, "id": 9, "position": Vector2(10, 10)}]

	# Unit 3: the far walk is not about it, the near one at 40 is. Unit 7:
	# side 1's strike is not side 0's, its own at 50 is. Unit 9: the walk at
	# 2000 is past the horizon, so it is not counted.
	assert_array(RtsClockMeasure.reactions(sightings, accepted, 0)).is_equal([28, 35])


func test_the_busiest_window_counts_one_side() -> void:
	var accepted: Array[Dictionary] = []
	for tick: int in [0, 1, 2, 400, 401]:
		accepted.append({"side": 0, "tick": tick})
	accepted.append({"side": 1, "tick": 3})

	assert_int(RtsClockMeasure.busiest(accepted, 0, 5.0)).is_equal(3)


func test_no_recording_gives_no_reference() -> void:
	assert_dict(RtsClockMeasure.measured_from("res://no/such/folder")).is_empty()
	assert_str(RtsHumanClock.stand_in()["source"]).contains("stand-in")


func test_a_recording_not_of_a_person_is_not_measured() -> void:
	assert_dict(RtsClockMeasure.of_recording({"who": "stand-in", "seed": 1, "ticks": 10, "commands": []})).is_empty()


func test_a_recording_replays_into_the_same_measures_the_match_had() -> void:
	# A stand-in plays west for a minute and its recording is labelled as a
	# person's: the replay must see what the match saw.
	var world: RtsWorld = RtsScenario.start(3)
	var played := RtsMatch.new(world, 3, {RtsScenario.WEST: QueueSide.new(RtsScenario.WEST, RtsLevels.named("normal"), 5)})
	var sightings: Array[Dictionary] = []
	var seen: Dictionary = {}
	for _sample: int in range(RtsWorld.TICKS_PER_SECOND * 60 / RtsClockMeasure.SAMPLE_TICKS):
		RtsClockMeasure.look(world, RtsScenario.WEST, seen, sightings)
		played.play(RtsClockMeasure.SAMPLE_TICKS)
	var kept: Dictionary = played.recording()
	kept.merge({"who": RtsClockMeasure.PERSON, "side": RtsScenario.WEST})

	var measured: Dictionary = RtsClockMeasure.of_recording(kept)

	assert_int(measured["commands"]).is_equal(played.accepted.size())
	assert_array(measured["reactions"]).is_equal(RtsClockMeasure.reactions(sightings, played.accepted, RtsScenario.WEST))
	assert_int(measured["busiest"]).is_equal(RtsClockMeasure.busiest(played.accepted, RtsScenario.WEST))


func test_k_puts_the_clock_on_the_computer_and_the_meter_reads_its_thinking() -> void:
	var game: RtsGame = _mounted_game()

	game._on_key(KEY_K)

	assert_object(game.played.controllers[RtsScenario.EAST]).is_instanceof(RtsHumanClock)
	assert_object((game.played.controllers[RtsScenario.EAST] as RtsHumanClock).inner).is_same(game.computer)
	assert_object(game._meter.sides[RtsScenario.EAST]).is_same(game.computer)
	game._on_key(KEY_K)
	assert_object(game.played.controllers[RtsScenario.EAST]).is_same(game.computer)


func test_the_meter_shows_what_the_sides_timings_say() -> void:
	var game: RtsGame = _mounted_game()
	for _decision: int in range(3):
		game.step_decision()

	var recent: Array[float] = RtsMeter.recent_ms(game.computer)
	var strategy: PackedInt64Array = game.computer.timings[FrameBudget.STRATEGY]
	var tactics: PackedInt64Array = game.computer.timings[FrameBudget.TACTICS]

	assert_int(recent.size()).is_equal(strategy.size())
	assert_float(recent[-1]).is_equal_approx((strategy[-1] + tactics[-1]) / 1000.0, 0.0001)


func test_a_match_played_to_its_end_is_kept_once_when_recording() -> void:
	var game: RtsGame = _mounted_game()
	var folder: String = create_temp_dir("rts_recordings")
	game.recordings_folder = folder
	game.recording = true
	game.world.tick = RtsScenario.TIME_LIMIT_SECONDS * RtsWorld.TICKS_PER_SECOND

	game._keep_if_over()
	game._keep_if_over()

	assert_int(game.matches_kept).is_equal(1)
	assert_int(DirAccess.get_files_at(folder).size()).is_equal(1)


func _mounted_game() -> RtsGame:
	var game: RtsGame = auto_free((load("res://game/rts/rts.tscn") as PackedScene).instantiate())
	add_child(game)
	return game
