# VisionShape, one claim per test: the zones, the body points and what
# light, movement and hiding do. The claims over many shapes are in
# test/infiltration/awareness_properties.gd.
extends GdUnitTestSuite


# Wide and sure near, narrow and doubtful far: the coffin, in three bands.
func _coffin() -> VisionShape:
	return VisionShape.from_row({
		"zones": [
			{"name": "close", "near": 0.0, "far": 4.0, "half_angle": 80.0, "certainty": 1.0},
			{"name": "middle", "near": 4.0, "far": 12.0, "half_angle": 45.0, "certainty": 0.6},
			{"name": "far", "near": 12.0, "far": 20.0, "half_angle": 15.0, "certainty": 0.3},
		],
		"dark_share": 0.25,
		"motion_bonus": 0.2,
	})


func _all_clear() -> Array[bool]:
	return [true, true, true]


func test_beside_the_eye_is_seen_wide_and_far_off_only_narrow() -> void:
	var shape: VisionShape = _coffin()
	assert_int(shape.zone_at(2.0, 70.0)).is_equal(0)
	assert_int(shape.zone_at(15.0, 70.0)).is_equal(-1)
	assert_int(shape.zone_at(15.0, 10.0)).is_equal(2)


func test_the_far_edge_of_a_band_belongs_to_the_next() -> void:
	assert_int(_coffin().zone_at(4.0, 0.0)).is_equal(1)
	assert_int(_coffin().zone_at(20.0, 0.0)).is_equal(-1)


func test_where_zones_overlap_the_most_certain_counts() -> void:
	var shape := VisionShape.new([
		{"name": "doubtful", "near": 0.0, "far": 10.0, "half_angle": 60.0, "certainty": 0.3},
		{"name": "sure", "near": 0.0, "far": 5.0, "half_angle": 30.0, "certainty": 0.9},
	], 1.0, 0.0)
	assert_int(shape.zone_at(3.0, 10.0)).is_equal(1)
	assert_int(shape.zone_at(3.0, 50.0)).is_equal(0)


func test_too_few_clear_points_see_nothing_and_say_why() -> void:
	var seen: VisionPercept = _coffin().percept(2.0, 0.0, [true, false, false], 2, 1.0, false, 0.0)
	assert_float(seen.certainty).is_equal(0.0)
	assert_str(seen.why).is_equal("1 of 3 points clear; the stance needs 2")
	assert_array(seen.points).is_equal([true, false, false])


func test_outside_every_zone_sees_nothing() -> void:
	var seen: VisionPercept = _coffin().percept(30.0, 0.0, _all_clear(), 1, 1.0, true, 0.0)
	assert_bool(seen.perceived()).is_false()
	assert_str(seen.why).is_equal("outside every zone")


func test_darkness_leaves_the_dark_share_and_light_all_of_it() -> void:
	assert_float(_coffin().percept(6.0, 0.0, _all_clear(), 1, 1.0, false, 0.0).certainty).is_equal_approx(0.6, 1e-9)
	assert_float(_coffin().percept(6.0, 0.0, _all_clear(), 1, 0.0, false, 0.0).certainty).is_equal_approx(0.15, 1e-9)


func test_movement_adds_and_a_hiding_spot_takes_away() -> void:
	assert_float(_coffin().percept(6.0, 0.0, _all_clear(), 1, 1.0, true, 0.0).certainty).is_equal_approx(0.8, 1e-9)
	assert_float(_coffin().percept(6.0, 0.0, _all_clear(), 1, 1.0, true, 0.5).certainty).is_equal_approx(0.4, 1e-9)


func test_certainty_never_passes_one() -> void:
	assert_float(_coffin().percept(1.0, 0.0, _all_clear(), 1, 1.0, true, 0.0).certainty).is_equal(1.0)


func test_light_is_read_at_the_feet_and_unset_cells_are_ambient() -> void:
	var light := LightMap.new(0.1)
	light.set_light(Vector2i(2, 3), 0.9)
	assert_float(light.at_feet(Vector2(5.5, 7.9), 2.0)).is_equal_approx(0.9, 1e-9)
	assert_float(light.at_feet(Vector2(-0.5, 7.9), 2.0)).is_equal_approx(0.1, 1e-9)


func test_a_lamp_put_out_leaves_the_ambient_light() -> void:
	var light := LightMap.new(0.2)
	light.set_light(Vector2i(0, 0), 3.0)
	assert_float(light.at(Vector2i(0, 0))).is_equal(1.0)
	light.clear_light(Vector2i(0, 0))
	assert_float(light.at(Vector2i(0, 0))).is_equal_approx(0.2, 1e-9)
