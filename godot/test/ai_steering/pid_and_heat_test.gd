# The PID controller and the heat line, each alone. The 3D driver's vectors
# (spec/vectors/racing3d/) hold both inside a decision; these say which
# piece broke.
extends GdUnitTestSuite

const STEP: float = 1.0 / 60.0


# A cart pushed by `controller` towards zero, against a steady pull: the
# offset a proportional term alone leaves, and the integral removes.
func _settle(controller: PidController, seconds: float) -> float:
	var where: float = 1.0
	var speed: float = 0.0
	for _frame: int in range(roundi(seconds / STEP)):
		var push: float = controller.update(-where, STEP)
		speed += (push - 0.5 - 2.0 * speed) * STEP
		where += speed * STEP
	return where


func test_a_proportional_term_alone_settles_off_and_the_integral_takes_the_offset_away() -> void:
	var proportional := PidController.new(2.0, 1.0, 1.0, 10.0)
	proportional.proportional_only = true
	var full := PidController.new(2.0, 1.0, 1.0, 10.0)
	# The pull is 0.5 and the push 2 a metre: P alone rests a quarter off.
	assert_float(_settle(proportional, 30.0)).is_equal_approx(-0.25, 1e-3)
	assert_float(absf(_settle(full, 30.0))).is_less(1e-3)


func test_the_integral_is_held_to_its_limit() -> void:
	var controller := PidController.new(0.0, 1.0, 0.0, 0.3)
	for _frame: int in range(600):
		controller.update(1.0, STEP)
	assert_float(controller.integral_term).is_equal_approx(0.3, 1e-9)


func test_the_first_update_has_no_derivative_and_a_reset_forgets() -> void:
	var controller := PidController.new(0.0, 0.0, 1.0, 1.0)
	assert_float(controller.update(5.0, STEP)).is_equal(0.0)
	assert_float(controller.update(6.0, STEP)).is_equal_approx(60.0, 1e-9)
	controller.reset()
	assert_float(controller.update(6.0, STEP)).is_equal(0.0)


func test_the_ball_rests_on_the_line_when_the_road_is_empty() -> void:
	var line := HeatLine.new()
	for _frame: int in range(300):
		line.build(6.0, 6.0)
		line.roll(STEP)
	assert_float(absf(line.ball)).is_less(1e-9)


func test_the_ball_rolls_away_from_a_car_and_back_when_it_is_gone() -> void:
	var line := HeatLine.new()
	for _frame: int in range(240):
		line.build(6.0, 6.0)
		line.heat_up(0.5, 3.0, 2.2)
		line.roll(STEP)
	assert_float(line.ball).is_less(-1.5)
	for _frame: int in range(600):
		line.build(6.0, 6.0)
		line.roll(STEP)
	assert_float(absf(line.ball)).is_less(0.05)


func test_the_ball_never_leaves_the_road() -> void:
	var line := HeatLine.new()
	line.ball_speed = 100.0
	line.build(3.0, 3.0)
	line.roll(0.1)
	assert_float(line.ball).is_equal(3.0)
	assert_float(line.ball_speed).is_equal(0.0)
