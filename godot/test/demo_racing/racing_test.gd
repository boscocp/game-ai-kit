# The racing demo's pieces, one at a time. The race-wide claims -- the
# ladder, and that nobody cheats -- are racing_ladder.gd's and
# racing_does_not_cheat.gd's; these name the part when one breaks.
extends GdUnitTestSuite


func test_the_line_is_cut_into_equal_pieces_all_the_way_round() -> void:
	var track := RacingTrack.new(RacingPhysics.new())
	for index: int in range(track.line.size()):
		var piece: float = track.line[index].distance_to(track.line[track.wrapped(index + 1)])
		assert_float(piece).is_between(RacingTrack.SPACING * 0.95, RacingTrack.SPACING * 1.05)


func test_the_speed_limit_never_asks_for_more_braking_or_grip_than_there_is() -> void:
	var physics := RacingPhysics.new()
	var track := RacingTrack.new(physics)
	for index: int in range(track.line.size()):
		var limit: float = track.full_grip_limit[index]
		var next_limit: float = track.full_grip_limit[track.wrapped(index + 1)]
		# Braking fully over one piece reaches the next sample's limit...
		assert_float(limit * limit).is_less_equal(
			next_limit * next_limit + 2.0 * physics.braking * RacingTrack.SPACING + 1e-6)
		# ...and the bend here is taken inside the grip.
		assert_float(limit * limit * absf(track.curvature[index])).is_less_equal(physics.grip + 1e-6)


func test_a_driver_who_dares_less_grip_is_slower_by_its_square_root() -> void:
	var physics := RacingPhysics.new()
	var track := RacingTrack.new(physics)
	var slowest: int = 0
	for index: int in range(track.line.size()):
		if track.full_grip_limit[index] < track.full_grip_limit[slowest]:
			slowest = index
	var all: float = RacingDriver.speed_limit(track, slowest, physics, 1.0)
	assert_float(RacingDriver.speed_limit(track, slowest, physics, 0.81)).is_equal_approx(all * 0.9, 1e-9)


func test_a_car_asked_to_turn_past_its_grip_turns_only_as_tight_as_the_grip() -> void:
	var physics := RacingPhysics.new()
	var car := RacingCar.new(physics, Vector2.ZERO, 0.0)
	car.speed = 30.0
	car.step(30.0, 10.0, true, 1.0 / 60.0)
	assert_float(car.sideways_acceleration()).is_equal_approx(physics.grip, 1e-6)


func test_no_car_passes_its_top_speed_and_grass_holds_it_slower() -> void:
	var physics := RacingPhysics.new()
	var car := RacingCar.new(physics, Vector2.ZERO, 0.0)
	for _step: int in range(60 * 30):
		car.step(1000.0, 0.0, true, 1.0 / 60.0)
	assert_float(car.speed).is_equal_approx(physics.top_speed, 1e-6)
	for _step: int in range(60 * 10):
		car.step(1000.0, 0.0, false, 1.0 / 60.0)
	assert_float(car.speed).is_equal_approx(physics.off_track_speed, 1e-6)


func test_a_car_right_of_the_line_turns_left_towards_it() -> void:
	var race := RacingRace.new(RacingPhysics.new())
	var number: int = race.enter(RacingDriver.new(RacingLevel.new("plain", 12.0, 0.9, 0.0), 1))
	var right: Vector2 = race.track.direction_at(0).rotated(PI / 2.0)
	race.cars[number].position += right * 3.0
	race.cars[number].speed = 20.0
	race.drivers[number].decide(race.cars[number], race.track, 0, 0.0)
	# A heading that grows turns towards +y, which is to the car's right.
	assert_float(race.drivers[number].wanted_turn).is_less(0.0)


func test_the_braking_point_is_the_first_place_ahead_slower_than_the_car() -> void:
	var race := RacingRace.new(RacingPhysics.new())
	var level := RacingLevel.new("plain", 12.0, 0.9, 0.0)
	var number: int = race.enter(RacingDriver.new(level, 1))
	var driver: RacingDriver = race.drivers[number]
	# The start line is just out of a corner; look from the first sample where
	# only the top speed limits this driver.
	var straight: int = 0
	while RacingDriver.speed_limit(race.track, straight, race.physics, 0.9) < race.physics.top_speed:
		straight += 1
	driver.decide(race.cars[number], race.track, straight, 0.0)
	assert_int(driver.braking_point).is_equal(-1)
	race.cars[number].speed = race.physics.top_speed
	driver.decide(race.cars[number], race.track, straight, 0.0)
	var found: int = driver.braking_point
	assert_int(found).is_greater(straight)
	assert_float(RacingDriver.speed_limit(race.track, found, race.physics, 0.9)).is_less(race.physics.top_speed)
	assert_float(RacingDriver.speed_limit(race.track, found - 1, race.physics, 0.9)).is_equal(race.physics.top_speed)
