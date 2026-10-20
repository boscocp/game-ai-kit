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
	race.cars[number].position = race.track.line[0] + right * 3.0
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


func test_your_car_is_a_plain_car_on_the_race_s_physics() -> void:
	var race := RacingRace.new(RacingPhysics.new())
	var you := RacingHumanDriver.new()
	var number: int = race.enter(you)
	assert_object(race.cars[number].get_script()).is_same(RacingCar)
	assert_object(race.cars[number].physics).is_same(race.physics)


func test_held_throttle_reaches_the_top_speed_and_no_more() -> void:
	# A car on its own, always on tarmac: the race's track would bend away
	# under a car driving straight, onto the grass.
	var physics := RacingPhysics.new()
	var track := RacingTrack.new(physics)
	var car := RacingCar.new(physics, Vector2.ZERO, 0.0)
	var you := RacingHumanDriver.new()
	you.throttle = true
	var fastest: float = 0.0
	for _step: int in range(60 * 12):
		you.decide(car, track, 0, 0.0)
		car.step(you.target_speed, you.wanted_turn, true, RacingRace.DT)
		fastest = maxf(fastest, car.speed)
	assert_float(fastest).is_equal_approx(physics.top_speed, 1e-6)


func test_a_full_turn_at_speed_is_held_to_the_grip_for_you_too() -> void:
	var race := RacingRace.new(RacingPhysics.new())
	var you := RacingHumanDriver.new()
	race.enter(you)
	race.cars[0].speed = 40.0
	you.throttle = true
	you.steer = 1.0
	race.step()
	assert_float(race.cars[0].sideways_acceleration()).is_less_equal(race.physics.grip + 1e-6)
	assert_float(race.cars[0].turn).is_less(race.physics.turn_rate)


func test_two_cars_never_end_a_step_on_top_of_each_other() -> void:
	var race := RacingRace.new(RacingPhysics.new())
	race.enter(RacingHumanDriver.new())
	race.enter(RacingHumanDriver.new())
	race.cars[1].position = race.cars[0].position + Vector2(1.0, 0.5)
	race.step()
	assert_float(race.cars[0].position.distance_to(race.cars[1].position)).is_greater_equal(
		2.0 * RacingRace.CAR_RADIUS - 1e-4)


func test_the_car_that_runs_into_another_drops_to_its_speed() -> void:
	var race := RacingRace.new(RacingPhysics.new())
	race.enter(RacingHumanDriver.new())
	race.enter(RacingHumanDriver.new())
	var ahead: Vector2 = Vector2.from_angle(race.cars[0].heading)
	race.cars[1].position = race.cars[0].position + ahead * 3.0
	race.cars[1].heading = race.cars[0].heading
	race.cars[0].speed = 30.0
	race.cars[1].speed = 10.0
	race.step()
	assert_float(race.cars[0].speed).is_less_equal(race.cars[1].speed + 1e-6)


func test_an_ai_driver_does_not_ask_to_go_faster_than_the_car_close_ahead() -> void:
	var race := RacingRace.new(RacingPhysics.new())
	race.enter(RacingDriver.new(RacingLevel.ladder()[2], 1))
	race.enter(RacingHumanDriver.new())
	var ahead: Vector2 = Vector2.from_angle(race.cars[0].heading)
	race.cars[1].position = race.cars[0].position + ahead * 10.0
	race.cars[1].heading = race.cars[0].heading
	race.cars[1].speed = 5.0
	race.step()
	assert_float(race.drivers[0].target_speed).is_less_equal(5.0 + 1e-6)

