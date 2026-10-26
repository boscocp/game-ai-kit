## Where steering forces are made honest and added together.
##
## Every behaviour in this addon -- seek, arrive, pursue, avoid -- is a
## function from "where I am, and where that is" to a force. Two rules hold
## for all of them, and they live here so no behaviour can forget one:
##
##   * a force is never larger than the vehicle can apply (`clamped`). A
##     behaviour that returns more is a behaviour that lies about what will
##     happen next;
##   * a direction towards a point very far away is still a direction
##     (`direction_to`). Godot's `normalized()` answers an infinite vector
##     with zero (and a warning), and a merely huge one -- 1e20, whose length
##     overflows a 32-bit float -- with zero and no warning at all; a vehicle
##     told to seek the horizon would stop.
##
## `combined` is Reynolds' weighted sum: each behaviour's force times its
## weight, added, then clamped once. Constant time per behaviour.
##
## When not to use it: when two behaviours fight to a standstill -- two
## avoids pushing opposite ways as hard as each other. A weighted sum cannot
## break that tie; a priority order (the first behaviour with something to
## say wins) can.
class_name Steering
extends RefCounted

## The shortest `time_to_target` taken. It only keeps a time of zero (or
## less) from dividing by zero; it does not make so short a time sensible.
## Below half a frame, each step overshoots the velocity wanted and the next
## swings back -- it chatters, bounded only by `max_force`.
const SHORTEST_TIME: float = 0.001


## `force`, shortened to `limit` if it is longer. An infinite force is as
## long as it can be, in its own direction.
static func clamped(force: Vector2, limit: float) -> Vector2:
	if not force.is_finite():
		return direction_to(Vector2.ZERO, force) * limit
	return force.limit_length(limit)


## The unit direction from `from` to `to`; zero when they are the same point.
## A finite offset is first divided by its larger part, so its length cannot
## overflow on the way to being normalised. An infinite offset keeps its
## direction: each infinite part becomes one step that way and the finite
## parts drop out, as they would at infinity.
static func direction_to(from: Vector2, to: Vector2) -> Vector2:
	var offset: Vector2 = to - from
	if not offset.is_finite():
		return Vector2(_towards_infinity(offset.x), _towards_infinity(offset.y)).normalized()
	var larger: float = maxf(absf(offset.x), absf(offset.y))
	if larger == 0.0:
		return Vector2.ZERO
	return (offset / larger).normalized()


## The force that turns `vehicle`'s velocity towards `desired`: Reynolds'
## "steering = desired velocity - velocity", divided by `time_to_target`
## (Millington's form), clamped. The time is a time constant, not a
## deadline: unclamped, about two-thirds of the gap closes in that time, and
## the rest ever more slowly (Millington's "reach it in this time" is loose
## the same way). It is the knob that says how sharply a behaviour answers.
## Its default, a second, is what the gap alone always meant here, because
## `SteeringVehicle.step` adds force times seconds: seek's old answer, kept.
## The answer is the same at any frame rate while the time is several frames
## long; under half a frame it chatters (see `SHORTEST_TIME`, the floor).
static func towards_velocity(vehicle: SteeringVehicle, desired: Vector2, time_to_target: float = 1.0) -> Vector2:
	return clamped((desired - vehicle.velocity) / maxf(time_to_target, SHORTEST_TIME), vehicle.max_force)


## Each force times its weight, added, and clamped once to `vehicle`'s limit.
## Weights are finite; an infinite one makes a force with no direction.
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
