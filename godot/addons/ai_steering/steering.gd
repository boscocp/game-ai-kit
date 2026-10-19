## Where steering forces are made honest and added together.
##
## Every behaviour in this addon -- seek, arrive, pursue, avoid -- is a
## function from "where I am, and where that is" to a force. Two rules hold
## for all of them, and they live here so no behaviour can forget one:
##
##   * a force is never larger than the vehicle can apply (`clamped`). A
##     behaviour that returns more is a behaviour that lies about what will
##     happen next;
##   * a direction towards a point at infinity is still a direction
##     (`direction_to`). Godot's `normalized()` answers an infinite vector
##     with zero, silently, and a vehicle told to seek the horizon would stop.
##
## `combined` is Reynolds' weighted sum: each behaviour's force times its
## weight, added, then clamped once. Constant time per behaviour.
##
## When not to use it: when two behaviours fight to a standstill -- avoid
## pushing left exactly as hard as seek pulls right. A weighted sum cannot
## break that tie; a priority order (the first behaviour with something to
## say wins) can.
class_name Steering
extends RefCounted


## `force`, shortened to `limit` if it is longer.
static func clamped(force: Vector2, limit: float) -> Vector2:
	return force.limit_length(limit)


## The unit direction from `from` to `to`; zero when they are the same point.
## An infinite offset keeps its direction: each infinite part becomes one
## step that way and the finite parts drop out, as they would at infinity.
static func direction_to(from: Vector2, to: Vector2) -> Vector2:
	var offset: Vector2 = to - from
	if offset.is_finite():
		return offset.normalized()
	return Vector2(_towards_infinity(offset.x), _towards_infinity(offset.y)).normalized()


## The force that turns `vehicle`'s velocity into `desired`, as fast as it
## can: Reynolds' "steering = desired velocity - velocity", clamped.
static func towards_velocity(vehicle: SteeringVehicle, desired: Vector2) -> Vector2:
	return clamped(desired - vehicle.velocity, vehicle.max_force)


## Each force times its weight, added, and clamped once to `vehicle`'s limit.
static func combined(vehicle: SteeringVehicle, forces: Array[Vector2], weights: PackedFloat64Array) -> Vector2:
	var total := Vector2.ZERO
	for index: int in range(forces.size()):
		total += forces[index] * weights[index]
	return clamped(total, vehicle.max_force)


# One step towards an infinite part, none for a finite one. A NaN part --
# infinity minus infinity -- has no direction and counts as none.
static func _towards_infinity(part: float) -> float:
	if is_inf(part):
		return signf(part)
	return 0.0
