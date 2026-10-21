# The vector checker's refusals, and the driver's pieces that a vector names
# only through the decision they make.
extends GdUnitTestSuite


func _a_vector() -> Dictionary:
	var path: String = ProjectSettings.globalize_path("res://") + "../spec/vectors/racing3d/a-straight-at-speed.json"
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func test_a_vector_from_the_directory_passes() -> void:
	var vector: Dictionary = _a_vector()
	assert_str(Racing3DVector.why_not_a_vector(vector)).is_empty()
	assert_array(Racing3DVector.check("straight", vector)).is_empty()


func test_a_decision_moved_by_ten_tolerances_is_caught() -> void:
	var vector: Dictionary = _a_vector()
	vector["frames"][0]["expect"]["throttle"] = float(vector["frames"][0]["expect"]["throttle"]) - 10.0 * Racing3DVector.TOLERANCE
	assert_array(Racing3DVector.check("moved", vector)).has_size(1)


func test_a_vector_that_shows_nothing_is_refused() -> void:
	var vector: Dictionary = _a_vector()
	vector["frames"] = []
	assert_str(Racing3DVector.why_not_a_vector(vector)).contains("nothing")
	vector.erase("driver")
	assert_str(Racing3DVector.why_not_a_vector(vector)).contains("no driver")


func test_a_vector_missing_a_decision_or_a_view_field_is_refused() -> void:
	var vector: Dictionary = _a_vector()
	vector["frames"][0]["expect"].erase("wanted_left")
	assert_str(Racing3DVector.why_not_a_vector(vector)).contains("no wanted_left")
	vector = _a_vector()
	vector["frames"][0]["view"].erase("room_left")
	assert_str(Racing3DVector.why_not_a_vector(vector)).contains("no room_left")


func test_a_view_too_short_or_ragged_is_refused() -> void:
	var vector: Dictionary = _a_vector()
	vector["frames"][0]["view"]["room_right"] = [1.0]
	assert_str(Racing3DVector.why_not_a_vector(vector)).contains("not as long")
	for key: String in Racing3DVector.POINT_FIELDS:
		vector["frames"][0]["view"][key] = [0.0, 3.0, 6.0]
	assert_str(Racing3DVector.why_not_a_vector(vector)).contains("under")


func test_the_knobs_a_driver_used_are_its_levels() -> void:
	var level := RaceLevel3D.new("probe", 0.7, 0.9, 1.5)
	var driver := RaceDriver3D.new(level, Race3D.sheet_of(CarPhysics3D.new()))
	driver.decide(RaceView3D.from_dictionary(_a_vector()["frames"][0]["view"]))
	assert_dict(driver.used).is_equal({"lookahead": 0.7, "grip_margin": 0.9, "wander": 1.5})


func test_the_wheels_are_worth_turning_less_the_faster_the_car_goes() -> void:
	var driver := RaceDriver3D.new(RaceLevel3D.new("probe", 0.7, 0.9, 0.0), Race3D.sheet_of(CarPhysics3D.new()))
	assert_float(driver.steer_limit(40.0)).is_less(driver.steer_limit(20.0))
	assert_float(driver.steer_limit(1.0)).is_equal(driver.max_steer)
