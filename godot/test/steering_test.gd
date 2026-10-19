# ai_steering's pieces, one at a time, and the vector checker's refusals.
# The properties over many starts are steering_properties.gd's; these name
# the part when one breaks.
extends GdUnitTestSuite


func test_a_force_longer_than_the_limit_is_shortened_and_keeps_its_direction() -> void:
	var force: Vector2 = Steering.clamped(Vector2(30, 40), 10.0)
	assert_float(force.length()).is_equal_approx(10.0, 1e-5)
	assert_vector(force.normalized()).is_equal_approx(Vector2(0.6, 0.8), Vector2(1e-5, 1e-5))


func test_a_direction_to_infinity_is_still_a_direction() -> void:
	# Godot's own normalized() answers this with zero.
	assert_vector(Steering.direction_to(Vector2(5, 5), Vector2(INF, 7))).is_equal(Vector2(1, 0))
	assert_vector(Steering.direction_to(Vector2(5, 5), Vector2(-INF, INF))).is_equal_approx(
		Vector2(-0.70710677, 0.70710677), Vector2(1e-6, 1e-6))
	assert_vector(Steering.direction_to(Vector2(5, 5), Vector2(5, 5))).is_equal(Vector2.ZERO)


func test_a_vehicle_never_goes_faster_than_its_top_speed() -> void:
	var car := SteeringVehicle.new(Vector2.ZERO, Vector2(9, 0), 10.0, 1000.0)
	car.step(Vector2(1000, 0), 1.0)
	assert_float(car.speed()).is_equal_approx(10.0, 1e-5)


func test_a_vehicle_applies_no_more_than_its_force_whatever_it_is_asked() -> void:
	var car := SteeringVehicle.new(Vector2.ZERO, Vector2.ZERO, 10.0, 2.0)
	car.step(Vector2(1000, 0), 1.0)
	assert_float(car.speed()).is_equal_approx(2.0, 1e-5)


func test_arrive_asks_to_stop_at_the_target_and_seek_does_not() -> void:
	var car := SteeringVehicle.new(Vector2.ZERO, Vector2.ZERO, 10.0, 20.0)
	assert_vector(ArriveBehaviour.new(Vector2.ZERO, 5.0).force(car)).is_equal(Vector2.ZERO)
	car.velocity = Vector2(4, 0)
	# On the target and still moving: arrive brakes, seek has nothing to aim at
	# and only cancels the velocity.
	assert_float(ArriveBehaviour.new(Vector2.ZERO, 5.0).force(car).x).is_less(0.0)


func test_pursue_aims_ahead_of_its_quarry_but_never_more_than_its_limit() -> void:
	var car := SteeringVehicle.new(Vector2.ZERO, Vector2.ZERO, 10.0, 20.0)
	var near := PursueBehaviour.new(Vector2(10, 0), Vector2(0, 5), 3.0)
	assert_vector(near.predicted(car)).is_equal_approx(Vector2(10, 5), Vector2(1e-5, 1e-5))
	var far := PursueBehaviour.new(Vector2(100, 0), Vector2(0, 5), 3.0)
	assert_vector(far.predicted(car)).is_equal_approx(Vector2(100, 15), Vector2(1e-5, 1e-5))


func test_avoid_turns_left_from_an_obstacle_dead_ahead_and_ignores_one_behind() -> void:
	var car := SteeringVehicle.new(Vector2.ZERO, Vector2(10, 0), 10.0, 20.0)
	var ahead := AvoidBehaviour.new([Vector2(3, 0)] as Array[Vector2], PackedFloat64Array([1.0]), 5.0)
	assert_vector(ahead.force(car)).is_equal_approx(Vector2(0, -20), Vector2(1e-4, 1e-4))
	var behind := AvoidBehaviour.new([Vector2(-3, 0)] as Array[Vector2], PackedFloat64Array([1.0]), 5.0)
	assert_vector(behind.force(car)).is_equal(Vector2.ZERO)


func test_avoid_pushes_back_from_an_obstacle_just_past_the_end_of_its_look() -> void:
	# The stretch ends at (5, 0); the obstacle's edge reaches it. The nearest
	# point is the stretch's end, and away from the centre from there is back.
	var car := SteeringVehicle.new(Vector2.ZERO, Vector2(10, 0), 10.0, 20.0)
	var past := AvoidBehaviour.new([Vector2(6, 0)] as Array[Vector2], PackedFloat64Array([1.5]), 5.0)
	assert_vector(past.force(car)).is_equal_approx(Vector2(-20, 0), Vector2(1e-4, 1e-4))


func test_the_weighted_sum_is_clamped_once_after_adding() -> void:
	var car := SteeringVehicle.new(Vector2.ZERO, Vector2.ZERO, 10.0, 20.0)
	var forces: Array[Vector2] = [Vector2(15, 0), Vector2(-15, 0)]
	assert_vector(Steering.combined(car, forces, PackedFloat64Array([1.0, 1.0]))).is_equal(Vector2.ZERO)
	assert_float(Steering.combined(car, forces, PackedFloat64Array([3.0, 0.0])).length()).is_equal_approx(20.0, 1e-4)


func test_a_vector_with_a_misspelt_field_or_an_unknown_behaviour_is_refused() -> void:
	var good: Dictionary = {"name": "x", "steps_per_second": 60, "vehicle": {}, "samples": [{}],
		"behaviours": [{"kind": "arrive", "target": [0, 0], "braking_radius": 1.0}]}
	assert_str(SteeringVector.why_not_a_vector(good)).is_empty()
	var misspelt: Dictionary = good.duplicate(true)
	misspelt["behaviours"][0]["braking_raduis"] = 1.0
	assert_str(SteeringVector.why_not_a_vector(misspelt)).contains("braking_raduis")
	var unknown: Dictionary = good.duplicate(true)
	unknown["behaviours"][0]["kind"] = "wander"
	assert_str(SteeringVector.why_not_a_vector(unknown)).contains("wander")


func test_a_sample_moved_past_the_tolerance_fails_the_check() -> void:
	var vector: Dictionary = {"name": "x", "steps_per_second": 60,
		"vehicle": {"position": [0, 0], "velocity": [0, 0], "max_speed": 10.0, "max_force": 20.0},
		"behaviours": [{"kind": "seek", "target": [10, 0]}],
		"samples": [{"step": 0, "position": [0, 0], "velocity": [0, 0], "force": [10, 0]}]}
	assert_array(SteeringVector.check("x", vector)).is_empty()
	vector["samples"][0]["position"] = [SteeringVector.TOLERANCE * 10.0, 0]
	assert_array(SteeringVector.check("x", vector)).has_size(1)
