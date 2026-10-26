# The racing-driver page's minimal example. Its speed profile must never
# ask for more braking than the car has, and must give a circle the speed
# its grip allows; and the car, placed off the line and away from the
# origin, must find the line, lap it, and stay within its limits. The page
# shows the file's text, held equal by check_translations_docs.py.
extends GdUnitTestSuite

const EXAMPLE: Script = preload("res://test/demo_racing/racing_line_example.gd")
const FRAME: float = 1.0 / 60.0
const CENTRE: Vector2 = Vector2(700, -300)
const RADIUS: float = 200.0


# A circle of `points` points round CENTRE.
func _circle(points: int) -> PackedVector2Array:
	var circle := PackedVector2Array()
	for index: int in range(points):
		circle.append(CENTRE + Vector2.from_angle(TAU * index / points) * RADIUS)
	return circle


# A long rectangle with sharp corners: straights to brake on.
func _rectangle() -> PackedVector2Array:
	var corners: Array[Vector2] = [Vector2(0, 0), Vector2(800, 0), Vector2(800, 200), Vector2(0, 200)]
	var points := PackedVector2Array()
	for side: int in range(4):
		for tenth: int in range(40):
			points.append(corners[side].lerp(corners[(side + 1) % 4], tenth / 40.0))
	return points


func test_the_profile_never_asks_for_more_braking_than_there_is() -> void:
	var points: PackedVector2Array = _rectangle()
	var limits: PackedFloat64Array = EXAMPLE.speed_profile(points, 300.0, 400.0, 400.0)
	assert_float(limits[20]).is_greater(limits[39])
	for index: int in range(points.size()):
		var next: int = (index + 1) % points.size()
		var room: float = points[index].distance_to(points[next])
		var reachable: float = limits[next] * limits[next] + 2.0 * 400.0 * room
		assert_float(limits[index] * limits[index]).is_less_equal(reachable + 0.001)


func test_the_profile_gives_a_circle_what_its_grip_allows() -> void:
	var limits: PackedFloat64Array = EXAMPLE.speed_profile(_circle(120), 300.0, 400.0, 400.0)
	for limit: float in limits:
		assert_float(limit).is_equal_approx(sqrt(300.0 * RADIUS), 1.0)


func test_the_car_finds_the_line_and_laps_it_within_its_limits() -> void:
	var scene: Node = auto_free(Node.new())
	add_child(scene)
	var car: Node2D = EXAMPLE.new()
	car.line = _circle(120)
	car.position = CENTRE + Vector2(0, 60)
	scene.add_child(car)
	car.set_physics_process(false)
	var vehicle: SteeringVehicle = car.vehicle
	var turned: float = 0.0
	var heading: Vector2 = car.position - CENTRE
	for frame: int in range(60 * 20):
		car._physics_process(FRAME)
		turned += heading.angle_to(car.position - CENTRE)
		heading = car.position - CENTRE
		assert_float(vehicle.speed()).is_less_equal(sqrt(300.0 * RADIUS) + 1.0)
		if frame > 60 * 3:
			assert_float(car.position.distance_to(CENTRE)).is_between(RADIUS - 30.0, RADIUS + 30.0)
	assert_float(absf(turned)).is_greater(2.0 * TAU)


func test_a_lower_grip_margin_is_a_slower_car() -> void:
	var scene: Node = auto_free(Node.new())
	add_child(scene)
	var car: Node2D = EXAMPLE.new()
	car.line = _circle(120)
	car.grip_margin = 0.5
	scene.add_child(car)
	for limit: float in car.speed_limits:
		assert_float(limit).is_equal_approx(sqrt(0.5 * 300.0 * RADIUS), 1.0)
