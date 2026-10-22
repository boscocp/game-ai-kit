# Awareness, one claim per test: it rises only while perceived, falls
# through every phase, and keeps its caution floor after an alert.
extends GdUnitTestSuite


func _row() -> Dictionary:
	return {
		"peak": 1.0, "decay": 0.1,
		"phases": [{"name": "unaware", "at": 0.0}, {"name": "suspicious", "at": 0.25},
			{"name": "searching", "at": 0.625}, {"name": "alert", "at": 1.0}],
		"caution": {"floor": 0.25, "seconds": 30.0},
	}


func test_it_rises_by_the_rate_while_perceived_and_stops_at_the_peak() -> void:
	var awareness := Awareness.new()
	awareness.step(_row(), true, 0.5, 1.0, 1.0)
	assert_float(awareness.value).is_equal_approx(0.5, 1e-9)
	awareness.step(_row(), true, 0.5, 4.0, 5.0)
	assert_float(awareness.value).is_equal(1.0)


func test_nothing_rises_on_a_step_with_no_percept() -> void:
	var awareness := Awareness.new()
	awareness.step(_row(), false, 9.0, 1.0, 1.0)
	assert_float(awareness.value).is_equal(0.0)


func test_the_phase_is_read_from_the_number_and_the_row() -> void:
	assert_str(Awareness.phase_name(0.0, _row())).is_equal("unaware")
	assert_str(Awareness.phase_name(0.25, _row())).is_equal("suspicious")
	assert_str(Awareness.phase_name(0.9, _row())).is_equal("searching")
	assert_str(Awareness.phase_name(1.0, _row())).is_equal("alert")


func test_a_long_fall_stops_at_the_floor_of_the_phase_below() -> void:
	var awareness := Awareness.new()
	awareness.value = 0.7
	awareness.step(_row(), false, 0.0, 100.0, 1.0)
	assert_float(awareness.value).is_equal_approx(0.25, 1e-9)
	awareness.step(_row(), false, 0.0, 100.0, 2.0)
	assert_float(awareness.value).is_equal(0.0)


func test_after_an_alert_it_holds_the_caution_floor_for_its_seconds() -> void:
	var awareness := Awareness.new()
	awareness.step(_row(), true, 2.0, 1.0, 10.0)
	for second: int in range(11, 39):
		awareness.step(_row(), false, 0.0, 1.0, float(second))
	assert_float(awareness.value).is_greater_equal(0.25)
	for second: int in range(41, 60):
		awareness.step(_row(), false, 0.0, 1.0, float(second))
	assert_float(awareness.value).is_equal(0.0)
