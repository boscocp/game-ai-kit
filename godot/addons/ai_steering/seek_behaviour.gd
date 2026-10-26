## Seek: full speed at a point.
##
## The desired velocity points at the target at the vehicle's top speed, and
## the force is what turns the current velocity into it. That is all, and it
## is the defect worth seeing: nothing in it ever asks for less than full
## speed, so a vehicle seeking a point that does not move drives through it,
## turns, drives through it again, and never stops.
## `test/ai_steering/steering_properties.gd` measures exactly that. Constant time.
##
## `time_to_target` is how sharply it answers: a time constant, in which
## about two-thirds of the gap to the velocity wanted closes (Millington's
## form, the same knob as arrive's). The default, a second, is what seek
## always was here; a car on a line wants about a tenth, or it runs wide of
## every corner (`docs/concepts/steering.md` has the measurement). Keep it
## several frames long: under half a frame it chatters.
##
## When not to use it: a target to stop at. That is `ArriveBehaviour`, which
## differs by the few lines that slow down.
class_name SeekBehaviour
extends SteeringBehaviour

var target: Vector2
## The time constant, in seconds, of the change to the velocity it wants;
## never under `Steering.SHORTEST_TIME`.
var time_to_target: float


func _init(where: Vector2, within: float = 1.0) -> void:
	target = where
	time_to_target = maxf(within, Steering.SHORTEST_TIME)


## Full speed towards the target, from wherever the vehicle is.
func force(vehicle: SteeringVehicle) -> Vector2:
	var desired: Vector2 = Steering.direction_to(vehicle.position, target) * vehicle.max_speed
	return Steering.towards_velocity(vehicle, desired, time_to_target)
