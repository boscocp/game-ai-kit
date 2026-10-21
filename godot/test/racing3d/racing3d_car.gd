# T54's car, measured on a flat test pad: the three things it adds to T23's
# car must be there, because the driver's whole lesson is that they are.
#
#   1. **Suspension**: dropped onto the pad, the car comes to rest at its
#      stated ride height, within REST_TOLERANCE, every spring carrying a
#      quarter of the weight;
#   2. **weight transfer**: braking hard from BRAKE_FROM, the front tyres
#      carry at least FRONT_SHARE times what the rear ones do -- and at rest
#      they carried the same;
#   3. **tyres that slide**: at a steady speed with the wheels turned slowly
#      to full lock, the sideways acceleration climbs to a peak no higher
#      than the tyres' grip allows and then falls back by at least
#      SLIDE_DROP, because past their peak slip the front tyres slide;
#      on no physics frame does a tyre give more than its grip.
#
# And no engine error while any of it runs (`Racing3DErrors`).
#
# Each is first asked of a planted car it must refuse: springs too soft to
# hold the car up, a centre of mass on the road (no lever, so no transfer),
# and tyres that keep all their grip however far past the peak they slip.
#
# Run it with `--fixed-fps 60`, as `make test-racing3d-car` does: without
# it Godot paces the physics in real time and the same run takes minutes.
#
#     ./scripts/godot --headless --fixed-fps 60 --path godot -s res://test/racing3d/racing3d_car.gd
#
# Exit codes: 0 the car is the car; 1 a check failed, or a planted car passed.
extends SceneTree

const REST_FRAMES: int = 120
const REST_TOLERANCE: float = 0.01
const BRAKE_FROM: float = 25.0
const FRONT_SHARE: float = 1.5
## Measured on 4.7.2 (2026-10-21): the peak is 9.6 m/s^2 and the car ends the
## ramp at 7.1, a quarter down. A tenth is the least that is still a slide.
const SLIDE_DROP: float = 0.1
const HOLD_SPEED: float = 13.0
const RAMP_FRAMES: int = 900
const FULL_LOCK: float = 0.4
## Room for float rounding when a tyre's force is held to its grip.
const GRIP_TOLERANCE: float = 1e-3
const GRAVITY: float = 9.8
## Physics frames a launch or a stop may take before the car is given up on.
const GIVE_UP: int = 1200

var _errors := Racing3DErrors.new()


func _initialize() -> void:
	OS.add_logger(_errors)
	_run()


func _run() -> void:
	var failures: Array[String] = []
	failures += await _planted()
	failures += await _check(CarPhysics3D.new(), false, "the car")
	var engine: String = _errors.finding("the checks")
	if engine != "":
		failures.append(engine)
	for failure: String in failures:
		print(failure)
	print("racing3d car: %d failure(s)" % failures.size())
	quit(1 if not failures.is_empty() else 0)


# Every check on one car; `mass_on_road` puts its centre of mass on the road.
func _check(physics: CarPhysics3D, mass_on_road: bool, label: String) -> Array[String]:
	var findings: Array[String] = []
	var world: Node3D = _world()
	var car := RaceCar3D.new(physics, true)
	# Dropped from where its springs just touch, whatever their stiffness.
	car.position = Vector3(0, physics.mount_drop + physics.rest_length + physics.wheel_radius, 150)
	world.add_child(car)
	if mass_on_road:
		car.center_of_mass = Vector3(0, -car.ride_height(), 0)
	findings.append_array(await _check_rest(car, label))
	findings.append_array(await _check_braking(car, label))
	findings.append_array(await _check_slide(car, label))
	world.queue_free()
	await process_frame
	return findings


func _check_rest(car: RaceCar3D, label: String) -> Array[String]:
	await _frames(REST_FRAMES)
	var findings: Array[String] = []
	var height: float = car.position.y
	if absf(height - car.ride_height()) > REST_TOLERANCE:
		findings.append("%s rests at %.3f m, not its ride height %.3f m" % [label, height, car.ride_height()])
	var quarter: float = car.physics.mass * GRAVITY / 4.0
	var worst: int = 0
	for wheel: int in range(4):
		if absf(car.wheel_load[wheel] - quarter) > absf(car.wheel_load[worst] - quarter):
			worst = wheel
	if absf(car.wheel_load[worst] - quarter) > quarter * 0.02:
		findings.append("%s: the %s spring carries %.0f N at rest, not a quarter of the weight (%.0f N)"
			% [label, RaceCar3D.WHEEL_NAMES[worst], car.wheel_load[worst], quarter])
	return findings


# Up to speed, then the brakes on: the front's load over the rear's, at its
# largest while braking.
func _check_braking(car: RaceCar3D, label: String) -> Array[String]:
	car.throttle = 1.0
	var frames: int = 0
	while car.forward_speed() < BRAKE_FROM and frames < GIVE_UP:
		await physics_frame
		frames += 1
	car.throttle = 0.0
	car.brake = 1.0
	var most: float = 0.0
	while car.forward_speed() > 5.0 and frames < 2 * GIVE_UP:
		await physics_frame
		frames += 1
		var rear: float = car.wheel_load[2] + car.wheel_load[3]
		most = maxf(most, (car.wheel_load[0] + car.wheel_load[1]) / maxf(rear, 1.0))
	car.brake = 0.0
	if most < FRONT_SHARE:
		return ["%s: braking, the front carried at most %.2f times the rear, under %.1f" % [label, most, FRONT_SHARE]]
	return []


# A steady speed and the wheels turned slowly to full lock: the sideways
# acceleration (speed times yaw rate, smoothed over a third of a second)
# must peak inside the grip and fall back after it.
func _check_slide(car: RaceCar3D, label: String) -> Array[String]:
	var findings: Array[String] = []
	var smoothed: float = 0.0
	var peak: float = 0.0
	for frame: int in range(RAMP_FRAMES):
		var speed: float = car.forward_speed()
		car.throttle = clampf((HOLD_SPEED - speed) * 0.5, 0.0, 1.0)
		car.brake = clampf((speed - HOLD_SPEED) * 0.5, 0.0, 1.0)
		car.steer_wanted = FULL_LOCK * frame / RAMP_FRAMES
		await physics_frame
		smoothed += (speed * car.angular_velocity.y - smoothed) * 0.05
		peak = maxf(peak, smoothed)
		var past: String = _past_grip(car, label)
		if past != "":
			return [past]
	var most: float = car.physics.tyre_grip * GRAVITY
	if peak > most:
		findings.append("%s: cornered at %.2f m/s^2, past the tyres' %.2f" % [label, peak, most])
	if smoothed > peak * (1.0 - SLIDE_DROP):
		findings.append("%s never slid: %.2f m/s^2 at full lock against a peak of %.2f" % [label, smoothed, peak])
	return findings


# A tyre that gave more than its grip on the last frame, said; or "".
func _past_grip(car: RaceCar3D, label: String) -> String:
	for wheel: int in range(4):
		if car.wheel_force[wheel] > car.wheel_limit[wheel] + GRIP_TOLERANCE:
			return "%s: a tyre gave %.0f N past its grip of %.0f N" % [label, car.wheel_force[wheel], car.wheel_limit[wheel]]
	return ""


# A pad of tarmac with grass round it, in the tree.
func _world() -> Node3D:
	var world := Node3D.new()
	world.add_child(RaceGround3D.grass(false))
	world.add_child(RaceGround3D.pad(400.0, Vector2.ZERO, false))
	root.add_child(world)
	return world


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await physics_frame


# The three planted cars, each refused by the check it breaks.
func _planted() -> Array[String]:
	var failures: Array[String] = []
	var soft := CarPhysics3D.new()
	soft.spring = 3000.0
	var never_slides := CarPhysics3D.new()
	never_slides.slide_grip = 1.0
	var cases: Array[Array] = [
		["springs too soft to hold it up", soft, false, "not its ride height"],
		["its centre of mass on the road", CarPhysics3D.new(), true, "the front carried at most"],
		["tyres that keep all their grip past the peak", never_slides, false, "never slid"],
	]
	for planted: Array in cases:
		var said: String = "\n".join(await _check(planted[1], planted[2], "planted"))
		if not (planted[3] in said):
			failures.append("planted, %s: %s" % [planted[0], said if said != "" else "passed"])
	return failures
