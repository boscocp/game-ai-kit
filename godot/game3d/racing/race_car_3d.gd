## A car on four ray-cast wheels: the physics the driver does not own.
##
## **Not the lesson, and not a driving simulator.** T23's car was a heading
## and a speed; this one is a `RigidBody3D` with the three things T23 left
## out, each a few lines a reader can follow (T54):
##
##   * **suspension**: each wheel casts a ray down from its mount, and the
##     spring and damper push the body up by how far the ray is short;
##   * **tyres that slip**: a tyre's sideways force grows with its slip
##     angle up to `peak_slip`, then it slides and keeps less. Forward and
##     sideways together are held inside the tyre's grip -- the friction
##     circle -- which is the load on it times its grip and the road's;
##   * **weight transfer**: nobody writes it. The tyres push at the road and
##     the centre of mass is above it, so braking pitches the body forward,
##     the front springs compress, and the front tyres carry more load.
##
## Not `VehicleBody3D`: its own reference says it "isn't designed to
## provide realistic 3D vehicle physics" (ADR 0018), and here a reader sees
## the four forces each wheel adds. The driver sets `steer_wanted`,
## `throttle` and `brake`; the car does the rest in `_integrate_forces`, once
## a physics frame. Constant time a frame: four rays.
##
## When not to use it: a car that must jump, flip or drive on walls. The rays
## look straight down the body; on a kerb the size of a wheel they lie.
class_name RaceCar3D
extends RigidBody3D

## The physics layer the ground is on, and the one cars are on.
const GROUND_LAYER: int = 1
const CAR_LAYER: int = 2
## Below this forward speed, in metres a second, the slip angle is measured
## against this speed instead: a car at rest has no direction to slip from.
const CRAWL: float = 2.0
## The body's box, in metres, and how far its centre is above the centre of
## mass: high enough that it never touches a flat road.
const BODY_SIZE: Vector3 = Vector3(1.8, 0.5, 4.2)
const BODY_LIFT: float = 0.15
## The four wheels, in this order everywhere.
const WHEEL_NAMES: Array[String] = ["front left", "front right", "rear left", "rear right"]

var physics: CarPhysics3D
## What the driver asks: the front wheels' angle, in radians (positive is
## left), and the two pedals, each from 0 to 1.
var steer_wanted: float = 0.0
var throttle: float = 0.0
var brake: float = 0.0
## The angle the front wheels have actually turned to: they turn at
## `steer_speed`, not at once.
var steer: float = 0.0

## What each wheel measured on the last physics frame, in WHEEL_NAMES order:
## the load on it in newtons, its slip angle in radians, the force its tyre
## gave and the most it could have given, both in newtons, and the grip of
## what it stood on (0 when it touched nothing).
var wheel_load := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
var wheel_slip := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
var wheel_force := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
var wheel_limit := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
var wheel_surface := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
# Each spring's compression on the last frame, for the damper.
var _compression := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
# The car's forward speed at the start of this physics frame.
var _speed: float = 0.0


## A car of `car_physics`. A `ghost` drives through other cars, as a car
## driving alone on the ladder does; otherwise cars collide.
func _init(car_physics: CarPhysics3D, ghost: bool = false) -> void:
	physics = car_physics
	mass = physics.mass
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3.ZERO
	can_sleep = false
	# The project's default damping would slow every car by a tenth of its
	# speed a second, a force nobody wrote: the car's only losses are its own.
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp = 0.0
	collision_layer = CAR_LAYER
	collision_mask = GROUND_LAYER if ghost else GROUND_LAYER | CAR_LAYER
	contact_monitor = true
	max_contacts_reported = 4
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = BODY_SIZE
	shape.shape = box
	shape.position = Vector3(0, BODY_LIFT, 0)
	add_child(shape)


## Where wheel `wheel`'s spring is mounted, in the body's own frame. The car
## points along -z, as Godot's cameras and models do.
func mount(wheel: int) -> Vector3:
	var side: float = -0.5 if wheel % 2 == 0 else 0.5
	var along: float = -0.5 if wheel < 2 else 0.5
	return Vector3(side * physics.track_width, -physics.mount_drop, along * physics.wheelbase)


## How far below the centre of mass the road is when the car stands still:
## each spring carries a quarter of the weight. A scene puts the car this
## high above the road to drop it gently.
func ride_height() -> float:
	var settled: float = physics.rest_length - physics.mass * 9.8 / 4.0 / physics.spring
	return physics.mount_drop + settled + physics.wheel_radius


## Metres a second along the way the car points (negative: rolling back).
func forward_speed() -> float:
	return linear_velocity.dot(-global_transform.basis.z)


## The car's heading on the map, in radians: 0 is along -z, and it grows
## turning left, seen from above.
func heading() -> float:
	var forward: Vector3 = -global_transform.basis.z
	return atan2(-forward.x, -forward.z)


## Once a physics frame: turn the wheels towards what is asked, then each
## wheel's spring and tyre, then the air.
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var most: float = physics.max_steer
	steer = move_toward(steer, clampf(steer_wanted, -most, most), physics.steer_speed * state.step)
	_speed = state.linear_velocity.dot(-state.transform.basis.z)
	for wheel: int in range(WHEEL_NAMES.size()):
		_wheel(state, wheel)
	var air: Vector3 = state.linear_velocity * Vector3(1, 0, 1)
	state.apply_central_force(-air * air.length() * physics.drag)


# One wheel: a ray from its mount down to the road, the spring and damper
# from how far the ray is short, and the tyre's force where it touches.
func _wheel(state: PhysicsDirectBodyState3D, wheel: int) -> void:
	var start: Vector3 = state.transform * mount(wheel)
	var down: Vector3 = -state.transform.basis.y
	var reach: float = physics.rest_length + physics.wheel_radius
	var query := PhysicsRayQueryParameters3D.create(start, start + down * reach, GROUND_LAYER)
	var hit: Dictionary = state.get_space_state().intersect_ray(query)
	if hit.is_empty():
		_compression[wheel] = 0.0
		_measured(wheel, 0.0, 0.0, 0.0, 0.0, 0.0)
		return
	var compression: float = reach - start.distance_to(hit["position"])
	var squeeze: float = (compression - _compression[wheel]) / state.step
	_compression[wheel] = compression
	var load: float = maxf(0.0, physics.spring * compression + physics.damper * squeeze)
	var at: Vector3 = hit["position"] - state.transform.origin
	state.apply_force(hit["normal"] * load, at)
	_tyre(state, wheel, hit, load, at)


# The tyre's force at the contact patch: sideways from the slip angle,
# forwards from the engine, the brake and the road's rolling drag, the two
# together held inside the friction circle.
func _tyre(state: PhysicsDirectBodyState3D, wheel: int, hit: Dictionary, load: float, at: Vector3) -> void:
	var normal: Vector3 = hit["normal"]
	var pointing: Vector3 = -state.transform.basis.z
	if wheel < 2:
		pointing = pointing.rotated(state.transform.basis.y, steer)
	var forward: Vector3 = (pointing - normal * pointing.dot(normal)).normalized()
	var left: Vector3 = normal.cross(forward)
	var velocity: Vector3 = state.get_velocity_at_local_position(at)
	var along: float = velocity.dot(forward)
	var slip: float = atan2(velocity.dot(left), maxf(absf(along), CRAWL))
	var surface: Node = hit["collider"] as Node
	var grip: float = float(surface.get_meta("grip", 1.0))
	var rear: bool = wheel >= 2
	var limit: float = physics.tyre_grip * (physics.rear_grip if rear else 1.0) * grip * load
	var peak: float = physics.peak_slip * (physics.rear_peak if rear else 1.0)
	var sideways: float = -limit * tyre_curve(slip / peak, physics.slide_grip)
	var rolling: float = float(surface.get_meta("rolling", 0.0)) * load
	var pushing: float = _drive(wheel, along) - rolling * clampf(along / CRAWL, -1.0, 1.0)
	var total: float = Vector2(pushing, sideways).length()
	if total > limit and total > 0.0:
		pushing *= limit / total
		sideways *= limit / total
	state.apply_force(forward * pushing + left * sideways, at)
	_measured(wheel, load, slip, minf(total, limit), limit, grip)


## How much of its grip a tyre gives at `ratio` -- its slip angle over the
## peak slip -- signed like the slip. Up to the peak it grows in proportion;
## past it the tyre slides, falling to `sliding` of its grip at twice the
## peak and staying there.
static func tyre_curve(ratio: float, sliding: float) -> float:
	var size: float = absf(ratio)
	if size <= 1.0:
		return ratio
	return signf(ratio) * maxf(sliding, 1.0 - (1.0 - sliding) * (size - 1.0))


# The engine at the two rear wheels, its push held to its power and cut at
# the top speed, and the brake at
# all four, shared front and rear, faded out as the wheel stops so it holds
# the car still rather than pushing it backwards.
func _drive(wheel: int, along: float) -> float:
	var engine: float = 0.0
	if wheel >= 2 and _speed < physics.top_speed:
		var most: float = minf(physics.engine_force, physics.engine_power / maxf(_speed, 1.0))
		engine = throttle * most / 2.0
	var share: float = physics.brake_front if wheel < 2 else 1.0 - physics.brake_front
	var braking: float = brake * physics.brake_force * share / 2.0
	return engine - braking * clampf(along / CRAWL * 4.0, -1.0, 1.0)


func _measured(wheel: int, load: float, slip: float, force: float, limit: float, grip: float) -> void:
	wheel_load[wheel] = load
	wheel_slip[wheel] = slip
	wheel_force[wheel] = force
	wheel_limit[wheel] = limit
	wheel_surface[wheel] = grip
